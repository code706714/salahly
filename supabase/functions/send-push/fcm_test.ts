import {
  assertEquals,
  assertNotEquals,
  assertStringIncludes,
} from "jsr:@std/assert@1";
import { FcmClient, parseServiceAccount } from "./fcm.ts";
import type { PushMessage } from "./message.ts";

const message: PushMessage = {
  title: "عنوان",
  body: "نص",
  data: { kind: "job_started", role: "consumer" },
};

/** A throwaway key, so the signing is exercised for real. */
async function serviceAccountJson(): Promise<string> {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const der = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", pair.privateKey),
  );
  const pem = btoa(String.fromCharCode(...der)).match(/.{1,64}/g)!.join("\n");
  return JSON.stringify({
    project_id: "salahly-test",
    client_email: "push@salahly-test.iam.gserviceaccount.com",
    private_key:
      `-----BEGIN PRIVATE KEY-----\n${pem}\n-----END PRIVATE KEY-----\n`,
  });
}

interface Call {
  url: string;
  init: RequestInit;
}

/** A fetch that answers the token request, then the sends one by one. */
function fakeFetch(sendAnswers: Response[]) {
  const calls: Call[] = [];
  const fetchFn = (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    calls.push({ url, init: init ?? {} });
    if (url === "https://oauth2.googleapis.com/token") {
      return Promise.resolve(
        Response.json({ access_token: "access-1", expires_in: 3600 }),
      );
    }
    return Promise.resolve(sendAnswers.shift() ?? new Response("{}"));
  };
  return { fetchFn: fetchFn as typeof fetch, calls };
}

Deno.test("a missing or broken service account is not accepted", () => {
  assertEquals(parseServiceAccount(undefined), null);
  assertEquals(parseServiceAccount(""), null);
  assertEquals(parseServiceAccount("not json"), null);
  assertEquals(parseServiceAccount('{"project_id":"x"}'), null);
});

Deno.test("a service account is read with the default token address", async () => {
  const account = parseServiceAccount(await serviceAccountJson())!;
  assertEquals(account.project_id, "salahly-test");
  assertEquals(account.token_uri, "https://oauth2.googleapis.com/token");
});

Deno.test("a message is sent to the project with a signed-in token", async () => {
  const account = parseServiceAccount(await serviceAccountJson())!;
  const { fetchFn, calls } = fakeFetch([Response.json({ name: "ok" })]);
  const outcome = await new FcmClient(account, fetchFn, () => 1000).send(
    "device-token",
    message,
  );
  assertEquals(outcome, "sent");

  const [auth, send] = calls;
  assertStringIncludes(String(auth.init.body), "grant_type=");
  assertStringIncludes(String(auth.init.body), "assertion=");
  assertEquals(
    send.url,
    "https://fcm.googleapis.com/v1/projects/salahly-test/messages:send",
  );
  assertEquals(
    (send.init.headers as Record<string, string>)["Authorization"],
    "Bearer access-1",
  );
  const body = JSON.parse(String(send.init.body)).message;
  assertEquals(body.token, "device-token");
  assertEquals(body.notification, { title: "عنوان", body: "نص" });
  assertEquals(body.data, message.data);
});

Deno.test("the access token is reused until it nearly expires", async () => {
  const account = parseServiceAccount(await serviceAccountJson())!;
  const { fetchFn, calls } = fakeFetch([]);
  let now = 1000;
  const client = new FcmClient(account, fetchFn, () => now);
  await client.send("a", message);
  await client.send("b", message);
  assertEquals(
    calls.filter((call) => call.url.includes("oauth2")).length,
    1,
  );
  now += 3600;
  await client.send("c", message);
  assertEquals(
    calls.filter((call) => call.url.includes("oauth2")).length,
    2,
  );
});

Deno.test("Firebase's answers are sorted by what to do next", async () => {
  const account = parseServiceAccount(await serviceAccountJson())!;
  const errorBody = (status: number, errorCode?: string) =>
    new Response(
      JSON.stringify({
        error: { details: errorCode ? [{ errorCode }] : [] },
      }),
      { status },
    );
  const { fetchFn } = fakeFetch([
    errorBody(404, "UNREGISTERED"),
    errorBody(404),
    errorBody(400, "INVALID_ARGUMENT"),
    errorBody(429, "QUOTA_EXCEEDED"),
    errorBody(503),
    new Response("not json", { status: 500 }),
  ]);
  const client = new FcmClient(account, fetchFn, () => 1000);
  const outcomes = [];
  for (let i = 0; i < 6; i++) {
    outcomes.push(await client.send("t", message));
  }
  assertEquals(outcomes, [
    "unregistered",
    "unregistered",
    "rejected",
    "retry",
    "retry",
    "retry",
  ]);
});

Deno.test("a network failure or a refused sign-in is a retry", async () => {
  const account = parseServiceAccount(await serviceAccountJson())!;
  const down = (() => Promise.reject(new Error("offline"))) as typeof fetch;
  assertEquals(
    await new FcmClient(account, down, () => 1000).send("t", message),
    "retry",
  );
  const refused =
    (() =>
      Promise.resolve(new Response("no", { status: 401 }))) as typeof fetch;
  assertEquals(
    await new FcmClient(account, refused, () => 1000).send("t", message),
    "retry",
  );
});

Deno.test("the signed token is a three part JWT for the messaging scope", async () => {
  const account = parseServiceAccount(await serviceAccountJson())!;
  const { fetchFn, calls } = fakeFetch([]);
  await new FcmClient(account, fetchFn, () => 1000).send("t", message);
  const assertion = new URLSearchParams(String(calls[0].init.body)).get(
    "assertion",
  )!;
  const parts = assertion.split(".");
  assertEquals(parts.length, 3);
  assertNotEquals(parts[2], "");
  const claims = JSON.parse(
    atob(parts[1].replaceAll("-", "+").replaceAll("_", "/")),
  );
  assertEquals(
    claims.scope,
    "https://www.googleapis.com/auth/firebase.messaging",
  );
  assertEquals(claims.iss, account.client_email);
  assertEquals(claims.exp - claims.iat, 3600);
});
