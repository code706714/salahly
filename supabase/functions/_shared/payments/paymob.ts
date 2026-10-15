// Paymob (Egypt). Written from Paymob's documentation:
//   create intention   POST {api}/v1/intention/  (Authorization: Token <secret key>)
//   checkout page      {checkout}/?publicKey=<public key>&clientSecret=<client secret>
//   processed callback POST JSON {type:"TRANSACTION", obj:{...}}, ?hmac=<sha512 hex>
//   auth token         POST {api}/api/auth/tokens {api_key} -> {token}
//   inquiry by order   POST {api}/api/ecommerce/orders/transaction_inquiry {order_id}
//   refund             POST {api}/api/acceptance/void_refund/refund
//                      {auth_token, transaction_id, amount_cents}
// Amounts are in cents; a piastre is a cent of the pound, so they are equal.
import { safeEqual } from "../shared_secret.ts";
import type { PaymentGateway } from "./gateway.ts";
import {
  type Checkout,
  type CheckoutRequest,
  GatewayError,
  InvalidSignatureError,
  type NormalizedPayment,
  type PaymentStatus,
  UnsupportedError,
  type WebhookCall,
} from "./types.ts";

export interface PaymobConfig {
  /** Secret key (Authorization: Token ...): creates intentions. */
  secretKey: string;
  publicKey: string;
  /** Verifies webhooks. */
  hmacSecret: string;
  /** Integration ids to offer, e.g. card and wallet. */
  integrationIds: number[];
  /** Enables inquiry and refund through the API; optional. */
  apiKey: string | null;
  apiBase: string;
  checkoutBase: string;
}

/** The fields the signature covers, in Paymob's order. */
export const hmacFields = [
  "amount_cents",
  "created_at",
  "currency",
  "error_occured",
  "has_parent_transaction",
  "id",
  "integration_id",
  "is_3d_secure",
  "is_auth",
  "is_capture",
  "is_refunded",
  "is_standalone_payment",
  "is_voided",
  "order.id",
  "owner",
  "pending",
  "source_data.pan",
  "source_data.sub_type",
  "source_data.type",
  "success",
] as const;

type Json = Record<string, unknown>;

function isObject(value: unknown): value is Json {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function pick(obj: Json, path: string): unknown {
  let current: unknown = obj;
  for (const part of path.split(".")) {
    if (!isObject(current)) return undefined;
    current = current[part];
  }
  return current;
}

function toHex(bytes: ArrayBuffer): string {
  return [...new Uint8Array(bytes)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/** HMAC-SHA512 of the transaction's fields joined without separators. */
export async function transactionHmac(
  secret: string,
  obj: Json,
): Promise<string> {
  const text = hmacFields
    .map((field) => {
      const value = pick(obj, field);
      return value === undefined || value === null ? "" : String(value);
    })
    .join("");
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  return toHex(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(text)),
  );
}

function flag(value: unknown): boolean {
  return value === true || value === "true";
}

/** A Paymob transaction object as a normalized payment, or null if unusable. */
export function normalizeTransaction(obj: Json): NormalizedPayment | null {
  const orderId = pick(obj, "order.id");
  const amount = Number(obj.amount_cents);
  if (
    orderId === undefined || orderId === null || !Number.isFinite(amount) ||
    typeof obj.currency !== "string"
  ) {
    return null;
  }
  const success = flag(obj.success);
  const pending = flag(obj.pending);
  const refunded = flag(obj.is_refunded) || flag(obj.is_refund);
  const voided = flag(obj.is_voided) || flag(obj.is_void);
  let status: PaymentStatus;
  if (success && !pending && (refunded || voided)) {
    status = "refunded";
  } else if (success && !pending) {
    status = "succeeded";
  } else if (pending) {
    status = "pending";
  } else {
    status = "failed";
  }
  const id = obj.id === undefined || obj.id === null ? null : String(obj.id);
  const merchantRef = pick(obj, "order.merchant_order_id");
  const method = pick(obj, "source_data.type");
  return {
    provider: "paymob",
    eventKey: `txn:${id}:s${+success}:p${+pending}:r${+refunded}:v${+voided}`,
    providerOrderId: String(orderId),
    merchantRef: typeof merchantRef === "string" && merchantRef !== ""
      ? merchantRef
      : null,
    providerTxnId: id,
    status,
    amountPiastres: amount,
    currency: obj.currency.toUpperCase(),
    paymentMethod: typeof method === "string" && method !== ""
      ? method.toLowerCase()
      : null,
  };
}

export class PaymobGateway implements PaymentGateway {
  readonly id = "paymob";

  constructor(
    private readonly config: PaymobConfig,
    private readonly http: typeof fetch = fetch,
  ) {}

  get canInquire(): boolean {
    return this.config.apiKey !== null;
  }

  async createCheckout(request: CheckoutRequest): Promise<Checkout> {
    const [first, ...rest] = (request.customer.name ?? "").trim().split(/\s+/);
    const body = {
      amount: request.amountPiastres,
      currency: request.currency,
      payment_methods: this.config.integrationIds,
      items: [{
        name: request.description,
        amount: request.amountPiastres,
        description: request.description,
        quantity: 1,
      }],
      billing_data: {
        first_name: first || "NA",
        last_name: rest.join(" ") || "NA",
        email: "NA",
        phone_number: request.customer.phone ?? "NA",
      },
      special_reference: request.orderId,
      notification_url: request.webhookUrl,
      ...(request.returnUrl ? { redirection_url: request.returnUrl } : {}),
      expiration: request.expiresInSeconds,
      extras: { order_id: request.orderId },
    };
    const response = await this.send("/v1/intention/", {
      Authorization: `Token ${this.config.secretKey}`,
    }, body);
    const clientSecret = response.client_secret;
    const orderId = response.intention_order_id;
    if (
      typeof clientSecret !== "string" ||
      (typeof orderId !== "number" && typeof orderId !== "string")
    ) {
      throw new GatewayError("paymob_bad_intention");
    }
    const url = new URL(this.config.checkoutBase);
    url.searchParams.set("publicKey", this.config.publicKey);
    url.searchParams.set("clientSecret", clientSecret);
    return { providerOrderId: String(orderId), checkoutUrl: url.toString() };
  }

  async verifyWebhook(call: WebhookCall): Promise<NormalizedPayment | null> {
    const hmac = call.query.get("hmac");
    const body = call.body;
    // Saved-card callbacks are signed differently and change nothing here.
    if (isObject(body) && body.type !== "TRANSACTION") return null;
    if (!isObject(body) || !isObject(body.obj) || hmac === null) {
      throw new InvalidSignatureError();
    }
    const expected = await transactionHmac(this.config.hmacSecret, body.obj);
    if (!safeEqual(hmac.toLowerCase(), expected)) {
      throw new InvalidSignatureError();
    }
    return normalizeTransaction(body.obj);
  }

  async fetchPayment(
    providerOrderId: string,
  ): Promise<NormalizedPayment | null> {
    const token = await this.authToken();
    const orderId = Number(providerOrderId);
    if (!Number.isSafeInteger(orderId)) {
      throw new GatewayError("paymob_bad_order_id");
    }
    const response = await this.send(
      "/api/ecommerce/orders/transaction_inquiry",
      { Authorization: `Bearer ${token}` },
      { order_id: orderId },
      true,
    );
    return response === null ? null : normalizeTransaction(response);
  }

  async refund(
    request: { providerTxnId: string; amountPiastres: number },
  ): Promise<{ reference: string }> {
    const token = await this.authToken();
    const transactionId = Number(request.providerTxnId);
    if (!Number.isSafeInteger(transactionId)) {
      throw new GatewayError("paymob_bad_transaction_id");
    }
    const response = await this.send("/api/acceptance/void_refund/refund", {}, {
      auth_token: token,
      transaction_id: transactionId,
      amount_cents: request.amountPiastres,
    });
    if (!flag(response.success) || response.id === undefined) {
      throw new GatewayError("paymob_refund_refused");
    }
    return { reference: String(response.id) };
  }

  /** The short-lived token the older endpoints ask for (needs the API key). */
  private async authToken(): Promise<string> {
    if (this.config.apiKey === null) {
      throw new UnsupportedError("paymob_api_key_missing");
    }
    const response = await this.send("/api/auth/tokens", {}, {
      api_key: this.config.apiKey,
    });
    if (typeof response.token !== "string") {
      throw new GatewayError("paymob_auth_failed");
    }
    return response.token;
  }

  /** POST JSON; the body of a 2xx, or null for a 404 when [nullOn404]. */
  private async send(
    path: string,
    headers: Record<string, string>,
    body: unknown,
    nullOn404: true,
  ): Promise<Json | null>;
  private async send(
    path: string,
    headers: Record<string, string>,
    body: unknown,
  ): Promise<Json>;
  private async send(
    path: string,
    headers: Record<string, string>,
    body: unknown,
    nullOn404 = false,
  ): Promise<Json | null> {
    let response: Response;
    try {
      response = await this.http(new URL(path, this.config.apiBase), {
        method: "POST",
        headers: { "Content-Type": "application/json", ...headers },
        body: JSON.stringify(body),
      });
    } catch {
      throw new GatewayError("paymob_unreachable");
    }
    if (nullOn404 && response.status === 404) {
      await response.body?.cancel();
      return null;
    }
    if (!response.ok) {
      await response.body?.cancel();
      throw new GatewayError(`paymob_http_${response.status}`);
    }
    const json = await response.json().catch(() => null);
    if (!isObject(json)) throw new GatewayError("paymob_bad_response");
    return json;
  }
}

/** Reads the Paymob settings from the function's secrets, or null if unset. */
export function paymobConfigFromEnv(
  env: (name: string) => string | undefined,
): PaymobConfig | null {
  const secretKey = env("PAYMOB_SECRET_KEY");
  const publicKey = env("PAYMOB_PUBLIC_KEY");
  const hmacSecret = env("PAYMOB_HMAC_SECRET");
  const integrationIds = (env("PAYMOB_INTEGRATION_IDS") ?? "")
    .split(",")
    .map((id) => Number(id.trim()))
    .filter((id) => Number.isSafeInteger(id) && id > 0);
  if (!secretKey || !publicKey || !hmacSecret || integrationIds.length === 0) {
    return null;
  }
  return {
    secretKey,
    publicKey,
    hmacSecret,
    integrationIds,
    apiKey: env("PAYMOB_API_KEY") || null,
    apiBase: env("PAYMOB_API_BASE") || "https://accept.paymob.com",
    checkoutBase: env("PAYMOB_CHECKOUT_BASE") ||
      "https://eg.checkout.paymob.com/",
  };
}
