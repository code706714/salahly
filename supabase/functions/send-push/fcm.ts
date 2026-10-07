// Sends messages through Firebase Cloud Messaging (HTTP v1), signing in with
// a service account. Nothing here logs a token, a message or a response.
import type { PushMessage } from "./message.ts";

export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri: string;
}

/** What happened to one message sent to one phone. */
export type SendOutcome =
  /** Accepted by Firebase. */
  | "sent"
  /** Firebase says the phone no longer has the app: forget the token. */
  | "unregistered"
  /** Refused for good (a bad request); trying again would not help. */
  | "rejected"
  /** Failed for now (network, quota, Firebase down); try again later. */
  | "retry";

const scope = "https://www.googleapis.com/auth/firebase.messaging";

/** The service account in [json], or null when it is missing or unusable. */
export function parseServiceAccount(
  json: string | undefined,
): ServiceAccount | null {
  if (!json) {
    return null;
  }
  try {
    const parsed = JSON.parse(json);
    if (
      typeof parsed.project_id !== "string" ||
      typeof parsed.client_email !== "string" ||
      typeof parsed.private_key !== "string"
    ) {
      return null;
    }
    return {
      project_id: parsed.project_id,
      client_email: parsed.client_email,
      private_key: parsed.private_key,
      token_uri: typeof parsed.token_uri === "string"
        ? parsed.token_uri
        : "https://oauth2.googleapis.com/token",
    };
  } catch {
    return null;
  }
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function textBase64Url(text: string): string {
  return base64Url(new TextEncoder().encode(text));
}

async function signJwt(
  account: ServiceAccount,
  issuedAt: number,
): Promise<string> {
  const pem = account.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (char) => char.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const header = textBase64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = textBase64Url(
    JSON.stringify({
      iss: account.client_email,
      scope,
      aud: account.token_uri,
      iat: issuedAt,
      exp: issuedAt + 3600,
    }),
  );
  const unsigned = `${header}.${claims}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64Url(new Uint8Array(signature))}`;
}

export class FcmClient {
  #token: { value: string; expiresAt: number } | null = null;
  readonly #account: ServiceAccount;
  readonly #fetch: typeof fetch;
  readonly #nowSeconds: () => number;

  constructor(
    account: ServiceAccount,
    fetchFn: typeof fetch = fetch,
    nowSeconds: () => number = () => Math.floor(Date.now() / 1000),
  ) {
    this.#account = account;
    this.#fetch = fetchFn;
    this.#nowSeconds = nowSeconds;
  }

  /** An OAuth access token, reused until a minute before it expires. */
  async #accessToken(): Promise<string | null> {
    const now = this.#nowSeconds();
    if (this.#token && this.#token.expiresAt - 60 > now) {
      return this.#token.value;
    }
    const response = await this.#fetch(this.#account.token_uri, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: await signJwt(this.#account, now),
      }),
    });
    if (!response.ok) {
      await response.body?.cancel();
      return null;
    }
    const body = await response.json();
    if (typeof body.access_token !== "string") {
      return null;
    }
    this.#token = {
      value: body.access_token,
      expiresAt: now + (Number(body.expires_in) || 3600),
    };
    return this.#token.value;
  }

  async send(token: string, message: PushMessage): Promise<SendOutcome> {
    try {
      const accessToken = await this.#accessToken();
      if (accessToken === null) {
        return "retry";
      }
      const response = await this.#fetch(
        `https://fcm.googleapis.com/v1/projects/${this.#account.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title: message.title, body: message.body },
              data: message.data,
              android: { priority: "HIGH" },
              apns: { payload: { aps: { sound: "default" } } },
            },
          }),
        },
      );
      return await outcomeOf(response);
    } catch {
      return "retry";
    }
  }
}

async function outcomeOf(response: Response): Promise<SendOutcome> {
  if (response.ok) {
    await response.body?.cancel();
    return "sent";
  }
  let code = "";
  try {
    const body = await response.json();
    const details: { errorCode?: string }[] = body?.error?.details ?? [];
    code = details.find((detail) => detail.errorCode)?.errorCode ?? "";
  } catch {
    // An error without a body is judged by its status alone.
  }
  if (code === "UNREGISTERED" || response.status === 404) {
    return "unregistered";
  }
  if (response.status === 400) {
    return "rejected";
  }
  return "retry";
}
