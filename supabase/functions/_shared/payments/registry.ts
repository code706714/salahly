import type { PaymentGateway } from "./gateway.ts";
import { paymobConfigFromEnv, PaymobGateway } from "./paymob.ts";

type Env = (name: string) => string | undefined;

/**
 * The adapters that can be built from the function's secrets. A new provider
 * is one entry here (plus its adapter file); nothing else in the payment
 * functions names a provider.
 */
const builders: Record<string, (env: Env) => PaymentGateway | null> = {
  paymob: (env) => {
    const config = paymobConfigFromEnv(env);
    return config === null ? null : new PaymobGateway(config);
  },
};

/** The provider new payments use (PAYMENT_PROVIDER, default paymob). */
export function activeProviderId(env: Env): string {
  return (env("PAYMENT_PROVIDER") ?? "paymob").toLowerCase();
}

/** The adapter for [id], or null when unknown or not configured. */
export function gatewayFor(id: string, env: Env): PaymentGateway | null {
  return builders[id]?.(env) ?? null;
}
