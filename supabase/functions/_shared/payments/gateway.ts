import type {
  Checkout,
  CheckoutRequest,
  NormalizedPayment,
  WebhookCall,
} from "./types.ts";

/**
 * What every payment provider adapter does for Salahly. The payment
 * functions only use this interface, so a provider is added by writing one
 * adapter and registering it (registry.ts) plus its webhook route/secrets;
 * the screens, the orders and the job rules do not change.
 */
export interface PaymentGateway {
  /** Stored on each order, lower case ("paymob"). */
  readonly id: string;

  /** Opens a checkout for an order and says where to send the person. */
  createCheckout(request: CheckoutRequest): Promise<Checkout>;

  /**
   * Checks a webhook call's signature and reads it. Throws
   * InvalidSignatureError when it is not signed by the provider; returns null
   * for a call that is genuine but not about a payment.
   */
  verifyWebhook(call: WebhookCall): Promise<NormalizedPayment | null>;

  /**
   * Asks the provider how an order stands, for the checks that must not rely
   * on a webhook (reconciliation, double-checking a success). Null when the
   * provider has no payment for it. Throws GatewayError when it cannot be
   * asked.
   */
  fetchPayment(providerOrderId: string): Promise<NormalizedPayment | null>;

  /** True when fetchPayment can work with the current configuration. */
  readonly canInquire: boolean;

  /**
   * Refunds a whole payment. Returns the provider's reference. Throws
   * UnsupportedError when the provider (or this merchant account) cannot do
   * it through the API; the money is then returned from the provider's
   * dashboard and the refund webhook closes the order.
   */
  refund(
    request: { providerTxnId: string; amountPiastres: number },
  ): Promise<{ reference: string }>;
}
