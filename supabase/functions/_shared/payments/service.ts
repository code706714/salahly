// The payment functions' logic, apart from Deno.serve and the environment, so
// it can be tested with a fake database and a fake provider. No function here
// names a provider: they get a PaymentGateway.
import type { PaymentGateway } from "./gateway.ts";
import {
  GatewayError,
  InvalidSignatureError,
  type NormalizedPayment,
  UnsupportedError,
} from "./types.ts";

export interface ApplyResult {
  outcome:
    | "applied"
    | "duplicate"
    | "stale"
    | "amount_mismatch"
    | "unknown_order";
  order_id?: string | null;
  status?: string | null;
}

export interface UnsettledOrder {
  id: string;
  provider: string;
  provider_order_id: string;
}

/** The database calls only the service role may make. */
export interface PaymentsDb {
  applyEvent(
    payment: NormalizedPayment,
    source: "webhook" | "inquiry",
  ): Promise<ApplyResult>;
  unsettled(limit: number): Promise<UnsettledOrder[]>;
  attachProvider(
    orderId: string,
    provider: string,
    providerOrderId: string,
  ): Promise<void>;
  recordRefund(
    orderId: string,
    reference: string,
    adminId: string,
  ): Promise<void>;
}

export type GatewayLookup = (provider: string) => PaymentGateway | null;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/**
 * The provider's server-to-server call. Replies 401 to anything not signed by
 * the provider, 200 once it was applied, repeated or is not about a payment,
 * and 503 when it could not be applied (the provider, or the reconciler,
 * delivers it again).
 */
export async function handleWebhook(
  request: Request,
  provider: string,
  db: PaymentsDb,
  gateways: GatewayLookup,
): Promise<Response> {
  if (request.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }
  const gateway = gateways(provider);
  if (gateway === null) return new Response("not configured", { status: 503 });

  let body: unknown;
  try {
    body = JSON.parse(await request.text());
  } catch {
    return new Response("bad request", { status: 400 });
  }

  let payment: NormalizedPayment | null;
  try {
    payment = await gateway.verifyWebhook({
      query: new URL(request.url).searchParams,
      headers: request.headers,
      body,
    });
  } catch (error) {
    if (error instanceof InvalidSignatureError) {
      return new Response("forbidden", { status: 401 });
    }
    return new Response("error", { status: 503 });
  }
  if (payment === null) return json({ outcome: "ignored" });

  try {
    // A signed message is genuine, but a success is also checked with the
    // provider when we can ask it: money is never given on one message alone.
    if (payment.status === "succeeded" && gateway.canInquire) {
      const confirmed = await gateway.fetchPayment(payment.providerOrderId);
      if (
        confirmed === null || confirmed.status !== "succeeded" ||
        confirmed.amountPiastres !== payment.amountPiastres
      ) {
        return json({ outcome: "unconfirmed" }, 503);
      }
    }
    const result = await db.applyEvent(payment, "webhook");
    return json({ outcome: result.outcome });
  } catch {
    return new Response("error", { status: 503 });
  }
}

/**
 * Asks the provider about orders still undecided and applies what it says.
 * Safe to run any number of times.
 */
export async function reconcile(
  db: PaymentsDb,
  gateways: GatewayLookup,
  limit = 50,
): Promise<{ checked: number; applied: number; failed: number }> {
  const orders = await db.unsettled(limit);
  let applied = 0;
  let failed = 0;
  for (const order of orders) {
    const gateway = gateways(order.provider);
    if (gateway === null || !gateway.canInquire) continue;
    try {
      const payment = await gateway.fetchPayment(order.provider_order_id);
      if (payment === null) continue;
      const result = await db.applyEvent(payment, "inquiry");
      if (result.outcome === "applied") applied++;
    } catch {
      failed++;
    }
  }
  return { checked: orders.length, applied, failed };
}

/** What the app asks for. */
export type CreateRequest =
  | { purpose: "credit_pack"; packId: string; expectedPricePiastres: number }
  | { purpose: "escrow"; requestId: string };

export function parseCreateRequest(body: unknown): CreateRequest | null {
  if (typeof body !== "object" || body === null) return null;
  const input = body as Record<string, unknown>;
  const uuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (input.purpose === "credit_pack") {
    const price = input.expected_price_piastres;
    if (
      typeof input.pack_id === "string" && uuid.test(input.pack_id) &&
      typeof price === "number" && Number.isSafeInteger(price) && price > 0
    ) {
      return {
        purpose: "credit_pack",
        packId: input.pack_id,
        expectedPricePiastres: price,
      };
    }
  } else if (input.purpose === "escrow") {
    if (typeof input.request_id === "string" && uuid.test(input.request_id)) {
      return { purpose: "escrow", requestId: input.request_id };
    }
  }
  return null;
}

/** An order the signed-in person's own session created (server-priced). */
export interface CreatedOrder {
  orderId: string;
  amountPiastres: number;
  currency: string;
  description: string;
}

/** The person's own calls, made with their session so the database knows who. */
export interface CustomerSession {
  createOrder(request: CreateRequest): Promise<CreatedOrder>;
  /** For the receipt and the wallet payment: name and phone on the account. */
  billing(): Promise<{ name: string | null; phone: string | null }>;
}

/** Maps a database refusal (by its name) to what the app is told. */
export class OrderRefusedError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
  }
}

/**
 * Creates the order (priced by the database), opens the checkout at the
 * provider and remembers the provider's ids. The app gets the page to open.
 */
export async function startPayment(
  request: CreateRequest,
  session: CustomerSession,
  gateway: PaymentGateway,
  db: PaymentsDb,
  urls: { webhookUrl: string; returnUrl: string | null },
): Promise<Response> {
  let order: CreatedOrder;
  try {
    order = await session.createOrder(request);
  } catch (error) {
    if (error instanceof OrderRefusedError) {
      return json({ error: error.code }, error.status);
    }
    return json({ error: "failed" }, 500);
  }
  try {
    const checkout = await gateway.createCheckout({
      orderId: order.orderId,
      amountPiastres: order.amountPiastres,
      currency: order.currency,
      description: order.description,
      customer: await session.billing(),
      webhookUrl: urls.webhookUrl,
      returnUrl: urls.returnUrl,
      expiresInSeconds: 3600,
    });
    await db.attachProvider(
      order.orderId,
      gateway.id,
      checkout.providerOrderId,
    );
    return json({
      order_id: order.orderId,
      checkout_url: checkout.checkoutUrl,
      amount_piastres: order.amountPiastres,
    });
  } catch {
    // The order stays "created" and expires on its own; the person can retry.
    return json(
      { error: "provider_unavailable", order_id: order.orderId },
      502,
    );
  }
}

/** What an admin's refund request needs from the database (their session). */
export interface RefundSession {
  adminId: string;
  target(escrowId: string): Promise<
    {
      orderId: string;
      provider: string;
      providerTxnId: string;
      amountPiastres: number;
    }
  >;
}

/**
 * Refunds a payment through its provider and records it. A provider that
 * cannot refund by API answers 501: the money is returned from the provider's
 * dashboard, and the refund webhook then closes the escrow.
 */
export async function refundEscrow(
  escrowId: string,
  session: RefundSession,
  gateways: GatewayLookup,
  db: PaymentsDb,
): Promise<Response> {
  let target;
  try {
    target = await session.target(escrowId);
  } catch (error) {
    if (error instanceof OrderRefusedError) {
      return json({ error: error.code }, error.status);
    }
    return json({ error: "failed" }, 500);
  }
  const gateway = gateways(target.provider);
  if (gateway === null) return json({ error: "provider_not_configured" }, 503);
  try {
    const { reference } = await gateway.refund({
      providerTxnId: target.providerTxnId,
      amountPiastres: target.amountPiastres,
    });
    await db.recordRefund(target.orderId, reference, session.adminId);
    return json({ status: "refunded" });
  } catch (error) {
    if (error instanceof UnsupportedError) {
      return json({ error: "refund_by_dashboard" }, 501);
    }
    if (error instanceof GatewayError) {
      return json({ error: "provider_refused" }, 502);
    }
    return json({ error: "failed" }, 500);
  }
}
