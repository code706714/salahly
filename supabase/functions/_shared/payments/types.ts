// The payment provider's world, reduced to what Salahly needs. Everything
// outside an adapter (the Edge Functions, the database, the app) speaks only
// these types; a provider's own response shapes stop at its adapter.

/** Where a payment stands, as the database stores it. */
export type PaymentStatus =
  | "pending"
  | "succeeded"
  | "failed"
  | "cancelled"
  | "expired"
  | "refunded";

/** One fact about a payment, from a webhook or from asking the provider. */
export interface NormalizedPayment {
  provider: string;
  /** Same state of the same transaction always gives the same key. */
  eventKey: string;
  /** The provider's id for our order (what we stored at checkout). */
  providerOrderId: string;
  /** Our order id, when the provider echoes it back. */
  merchantRef: string | null;
  providerTxnId: string | null;
  status: PaymentStatus;
  /** Piastres: what the provider says it took. */
  amountPiastres: number;
  currency: string;
  /** "card", "wallet", ... as the provider reports it. */
  paymentMethod: string | null;
}

export interface CheckoutRequest {
  /** Our order id; the provider returns it as the merchant reference. */
  orderId: string;
  amountPiastres: number;
  currency: string;
  /** Short text for the receipt line. */
  description: string;
  customer: { name: string | null; phone: string | null };
  /** Where the provider reports the result (server to server). */
  webhookUrl: string;
  /** Where the person's browser lands afterwards; optional. */
  returnUrl: string | null;
  expiresInSeconds: number;
}

export interface Checkout {
  providerOrderId: string;
  /** The page the person pays on. */
  checkoutUrl: string;
}

/** The webhook call as received, before anything is trusted. */
export interface WebhookCall {
  query: URLSearchParams;
  headers: Headers;
  body: unknown;
}

/** The signature did not match: the call is not from the provider. */
export class InvalidSignatureError extends Error {
  constructor() {
    super("invalid_signature");
  }
}

/** The provider is set up wrongly or unreachable. */
export class GatewayError extends Error {}

/** The provider cannot do this (for example refund through the API). */
export class UnsupportedError extends GatewayError {}
