import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  hmacFields,
  normalizeTransaction,
  type PaymobConfig,
  paymobConfigFromEnv,
  PaymobGateway,
  transactionHmac,
} from "./paymob.ts";
import {
  GatewayError,
  InvalidSignatureError,
  UnsupportedError,
} from "./types.ts";

const config: PaymobConfig = {
  secretKey: "sk_test_secret",
  publicKey: "pk_test_public",
  hmacSecret: "hmac-secret",
  integrationIds: [111, 222],
  apiKey: "api-key",
  apiBase: "https://accept.paymob.com",
  checkoutBase: "https://eg.checkout.paymob.com/",
};

function transaction(overrides: Record<string, unknown> = {}) {
  return {
    id: 7001,
    pending: false,
    success: true,
    amount_cents: 2000,
    created_at: "2026-10-15T10:00:00.000000",
    currency: "EGP",
    error_occured: false,
    has_parent_transaction: false,
    integration_id: 111,
    is_3d_secure: true,
    is_auth: false,
    is_capture: false,
    is_refunded: false,
    is_standalone_payment: true,
    is_voided: false,
    owner: 9,
    order: { id: 9001, merchant_order_id: "ord-1" },
    source_data: { pan: "2346", sub_type: "MasterCard", type: "card" },
    ...overrides,
  };
}

async function signedCall(
  obj: Record<string, unknown>,
  secret = "hmac-secret",
) {
  const hmac = await transactionHmac(secret, obj);
  return {
    query: new URLSearchParams({ hmac }),
    headers: new Headers(),
    body: { type: "TRANSACTION", obj },
  };
}

Deno.test("the signature covers the documented fields in order", () => {
  assertEquals(hmacFields.length, 20);
  assertEquals(hmacFields[0], "amount_cents");
  assertEquals(hmacFields[5], "id");
  assertEquals(hmacFields[13], "order.id");
  assertEquals(hmacFields[19], "success");
});

Deno.test("a signed successful payment is read as succeeded", async () => {
  const gateway = new PaymobGateway(config);
  const payment = await gateway.verifyWebhook(await signedCall(transaction()));
  assertEquals(payment?.status, "succeeded");
  assertEquals(payment?.providerOrderId, "9001");
  assertEquals(payment?.merchantRef, "ord-1");
  assertEquals(payment?.amountPiastres, 2000);
  assertEquals(payment?.paymentMethod, "card");
  assertEquals(payment?.providerTxnId, "7001");
});

Deno.test("a call signed with another secret is refused", async () => {
  const gateway = new PaymobGateway(config);
  await assertRejects(
    async () =>
      await gateway.verifyWebhook(
        await signedCall(transaction(), "someone-elses-secret"),
      ),
    InvalidSignatureError,
  );
});

Deno.test("changing the amount after signing is refused", async () => {
  const gateway = new PaymobGateway(config);
  const call = await signedCall(transaction());
  (call.body.obj as Record<string, unknown>).amount_cents = 1;
  await assertRejects(() => gateway.verifyWebhook(call), InvalidSignatureError);
});

Deno.test("a call without a signature is refused", async () => {
  const gateway = new PaymobGateway(config);
  await assertRejects(
    () =>
      gateway.verifyWebhook({
        query: new URLSearchParams(),
        headers: new Headers(),
        body: { type: "TRANSACTION", obj: transaction() },
      }),
    InvalidSignatureError,
  );
});

Deno.test("a callback that is not a transaction is ignored", async () => {
  const gateway = new PaymobGateway(config);
  const payment = await gateway.verifyWebhook({
    query: new URLSearchParams(),
    headers: new Headers(),
    body: { type: "TOKEN", obj: { token: "x" } },
  });
  assertEquals(payment, null);
});

Deno.test("transaction states map to payment states", () => {
  const status = (o: Record<string, unknown>) =>
    normalizeTransaction(transaction(o))?.status;
  assertEquals(status({}), "succeeded");
  assertEquals(status({ success: false, pending: true }), "pending");
  assertEquals(status({ success: false, pending: false }), "failed");
  assertEquals(status({ is_refunded: true }), "refunded");
  assertEquals(status({ is_voided: true }), "refunded");
  assertEquals(status({ success: false, error_occured: true }), "failed");
});

Deno.test("the same state has the same key, another state another", () => {
  const key = (o: Record<string, unknown>) =>
    normalizeTransaction(transaction(o))?.eventKey;
  assertEquals(key({}), key({}));
  assert(key({}) !== key({ is_refunded: true }));
  assert(key({}) !== key({ id: 7002 }));
});

Deno.test("a transaction with no order is unusable", () => {
  assertEquals(normalizeTransaction({ id: 1, success: true }), null);
});

Deno.test("creating a checkout sends the secret key and the order", async () => {
  let seen: { url: string; init: RequestInit } | null = null;
  const http: typeof fetch = (input, init) => {
    seen = { url: String(input), init: init! };
    return Promise.resolve(
      new Response(
        JSON.stringify({ client_secret: "cs_1", intention_order_id: 9001 }),
        { status: 201 },
      ),
    );
  };
  const gateway = new PaymobGateway(config, http);
  const checkout = await gateway.createCheckout({
    orderId: "ord-1",
    amountPiastres: 2000,
    currency: "EGP",
    description: "R-1",
    customer: { name: "Nour Ali", phone: "+201000000001" },
    webhookUrl:
      "https://x.supabase.co/functions/v1/payment-webhook?provider=paymob",
    returnUrl: null,
    expiresInSeconds: 3600,
  });
  assertEquals(checkout.providerOrderId, "9001");
  assertEquals(
    checkout.checkoutUrl,
    "https://eg.checkout.paymob.com/?publicKey=pk_test_public&clientSecret=cs_1",
  );
  assertEquals(seen!.url, "https://accept.paymob.com/v1/intention/");
  const headers = seen!.init.headers as Record<string, string>;
  assertEquals(headers["Authorization"], "Token sk_test_secret");
  const body = JSON.parse(seen!.init.body as string);
  assertEquals(body.amount, 2000);
  assertEquals(body.currency, "EGP");
  assertEquals(body.payment_methods, [111, 222]);
  assertEquals(body.special_reference, "ord-1");
  assertEquals(body.billing_data.first_name, "Nour");
  assertEquals(body.billing_data.last_name, "Ali");
  assertEquals(body.redirection_url, undefined);
});

Deno.test("a refused or broken intention is a gateway error", async () => {
  const refused: typeof fetch = () =>
    Promise.resolve(new Response("{}", { status: 401 }));
  await assertRejects(
    () =>
      new PaymobGateway(config, refused).createCheckout({
        orderId: "o",
        amountPiastres: 100,
        currency: "EGP",
        description: "d",
        customer: { name: null, phone: null },
        webhookUrl: "https://x",
        returnUrl: null,
        expiresInSeconds: 60,
      }),
    GatewayError,
  );
  const empty: typeof fetch = () =>
    Promise.resolve(new Response("{}", { status: 201 }));
  await assertRejects(
    () =>
      new PaymobGateway(config, empty).createCheckout({
        orderId: "o",
        amountPiastres: 100,
        currency: "EGP",
        description: "d",
        customer: { name: null, phone: null },
        webhookUrl: "https://x",
        returnUrl: null,
        expiresInSeconds: 60,
      }),
    GatewayError,
  );
});

Deno.test("asking about an order uses a token and reads the transaction", async () => {
  const calls: string[] = [];
  const http: typeof fetch = (input, init) => {
    const url = String(input);
    calls.push(url);
    if (url.endsWith("/api/auth/tokens")) {
      return Promise.resolve(
        new Response(JSON.stringify({ token: "tok" }), { status: 201 }),
      );
    }
    assertEquals(
      (init!.headers as Record<string, string>)["Authorization"],
      "Bearer tok",
    );
    assertEquals(JSON.parse(init!.body as string), { order_id: 9001 });
    return Promise.resolve(
      new Response(JSON.stringify(transaction()), { status: 200 }),
    );
  };
  const payment = await new PaymobGateway(config, http).fetchPayment("9001");
  assertEquals(payment?.status, "succeeded");
  assertEquals(calls.length, 2);
});

Deno.test("an order the provider has no payment for is null", async () => {
  const http: typeof fetch = (input) =>
    Promise.resolve(
      String(input).endsWith("/api/auth/tokens")
        ? new Response(JSON.stringify({ token: "tok" }), { status: 201 })
        : new Response("{}", { status: 404 }),
    );
  assertEquals(await new PaymobGateway(config, http).fetchPayment("1"), null);
});

Deno.test("without the API key nothing can be asked or refunded", async () => {
  const gateway = new PaymobGateway({ ...config, apiKey: null });
  assertEquals(gateway.canInquire, false);
  await assertRejects(() => gateway.fetchPayment("1"), UnsupportedError);
  await assertRejects(
    () => gateway.refund({ providerTxnId: "7001", amountPiastres: 2000 }),
    UnsupportedError,
  );
});

Deno.test("a refund sends the transaction and the whole amount", async () => {
  const http: typeof fetch = (input, init) => {
    if (String(input).endsWith("/api/auth/tokens")) {
      return Promise.resolve(
        new Response(JSON.stringify({ token: "tok" }), { status: 201 }),
      );
    }
    assertEquals(JSON.parse(init!.body as string), {
      auth_token: "tok",
      transaction_id: 7001,
      amount_cents: 2000,
    });
    return Promise.resolve(
      new Response(JSON.stringify({ id: 78, success: true }), { status: 200 }),
    );
  };
  const refund = await new PaymobGateway(config, http).refund({
    providerTxnId: "7001",
    amountPiastres: 2000,
  });
  assertEquals(refund.reference, "78");
});

Deno.test("a refused refund is not recorded as made", async () => {
  const http: typeof fetch = (input) =>
    Promise.resolve(
      String(input).endsWith("/api/auth/tokens")
        ? new Response(JSON.stringify({ token: "tok" }), { status: 201 })
        : new Response(JSON.stringify({ id: 1, success: false }), {
          status: 200,
        }),
    );
  await assertRejects(
    () =>
      new PaymobGateway(config, http).refund({
        providerTxnId: "7001",
        amountPiastres: 2000,
      }),
    GatewayError,
  );
});

Deno.test("settings are read from the secrets, or null when incomplete", () => {
  const env: Record<string, string> = {
    PAYMOB_SECRET_KEY: "s",
    PAYMOB_PUBLIC_KEY: "p",
    PAYMOB_HMAC_SECRET: "h",
    PAYMOB_INTEGRATION_IDS: "1, 2,x",
  };
  const read = (name: string) => env[name];
  assertEquals(paymobConfigFromEnv(read)?.integrationIds, [1, 2]);
  assertEquals(paymobConfigFromEnv(read)?.apiKey, null);
  assertEquals(paymobConfigFromEnv(() => undefined), null);
});
