// The payment functions' rules, checked against a fake provider and a fake
// database: nothing here knows Paymob, so a second provider's adapter runs
// through exactly the same code.
import { assertEquals } from "jsr:@std/assert@1";
import type { PaymentGateway } from "./gateway.ts";
import { activeProviderId, gatewayFor } from "./registry.ts";
import {
  type ApplyResult,
  type CreateRequest,
  handleWebhook,
  OrderRefusedError,
  parseCreateRequest,
  type PaymentsDb,
  reconcile,
  refundEscrow,
  startPayment,
  type UnsettledOrder,
} from "./service.ts";
import {
  GatewayError,
  InvalidSignatureError,
  type NormalizedPayment,
  UnsupportedError,
} from "./types.ts";

function payment(
  overrides: Partial<NormalizedPayment> = {},
): NormalizedPayment {
  return {
    provider: "fake",
    eventKey: "k1",
    providerOrderId: "o1",
    merchantRef: "ord-1",
    providerTxnId: "t1",
    status: "succeeded",
    amountPiastres: 2000,
    currency: "EGP",
    paymentMethod: "card",
    ...overrides,
  };
}

class FakeDb implements PaymentsDb {
  applied: NormalizedPayment[] = [];
  attached: string[][] = [];
  refunds: string[][] = [];
  waiting: UnsettledOrder[] = [];
  outcome: ApplyResult = { outcome: "applied" };
  failApply = false;

  applyEvent(p: NormalizedPayment): Promise<ApplyResult> {
    if (this.failApply) return Promise.reject(new Error("down"));
    this.applied.push(p);
    return Promise.resolve(this.outcome);
  }
  unsettled(): Promise<UnsettledOrder[]> {
    return Promise.resolve(this.waiting);
  }
  attachProvider(a: string, b: string, c: string): Promise<void> {
    this.attached.push([a, b, c]);
    return Promise.resolve();
  }
  recordRefund(a: string, b: string, c: string): Promise<void> {
    this.refunds.push([a, b, c]);
    return Promise.resolve();
  }
}

class FakeGateway implements PaymentGateway {
  readonly id = "fake";
  canInquire = true;
  webhook: NormalizedPayment | null | "invalid" = payment();
  inquiry: NormalizedPayment | null = payment();
  inquiryFails = false;
  refundError: Error | null = null;
  checkoutFails = false;

  createCheckout() {
    if (this.checkoutFails) return Promise.reject(new GatewayError("down"));
    return Promise.resolve({
      providerOrderId: "o1",
      checkoutUrl: "https://pay/x",
    });
  }
  verifyWebhook() {
    if (this.webhook === "invalid") {
      return Promise.reject(new InvalidSignatureError());
    }
    return Promise.resolve(this.webhook);
  }
  fetchPayment() {
    if (this.inquiryFails) return Promise.reject(new GatewayError("down"));
    return Promise.resolve(this.inquiry);
  }
  refund() {
    return this.refundError
      ? Promise.reject(this.refundError)
      : Promise.resolve({ reference: "RF1" });
  }
}

const post = () =>
  new Request("https://x/payment-webhook?provider=fake", {
    method: "POST",
    body: "{}",
  });

Deno.test("an unsigned webhook is refused and changes nothing", async () => {
  const gateway = new FakeGateway();
  gateway.webhook = "invalid";
  const db = new FakeDb();
  const response = await handleWebhook(post(), "fake", db, () => gateway);
  assertEquals(response.status, 401);
  assertEquals(db.applied.length, 0);
});

Deno.test("a signed success is applied", async () => {
  const db = new FakeDb();
  const response = await handleWebhook(
    post(),
    "fake",
    db,
    () => new FakeGateway(),
  );
  assertEquals(response.status, 200);
  assertEquals(db.applied.length, 1);
});

Deno.test("a success the provider does not confirm is not applied", async () => {
  const gateway = new FakeGateway();
  gateway.inquiry = payment({ status: "failed" });
  const db = new FakeDb();
  const response = await handleWebhook(post(), "fake", db, () => gateway);
  assertEquals(response.status, 503);
  assertEquals(db.applied.length, 0);
});

Deno.test("a success whose amount differs at the provider is not applied", async () => {
  const gateway = new FakeGateway();
  gateway.inquiry = payment({ amountPiastres: 1 });
  const db = new FakeDb();
  assertEquals(
    (await handleWebhook(post(), "fake", db, () => gateway)).status,
    503,
  );
  assertEquals(db.applied.length, 0);
});

Deno.test("when the provider cannot be asked the success waits", async () => {
  const gateway = new FakeGateway();
  gateway.inquiryFails = true;
  const db = new FakeDb();
  assertEquals(
    (await handleWebhook(post(), "fake", db, () => gateway)).status,
    503,
  );
  assertEquals(db.applied.length, 0);
});

Deno.test("without inquiry the signed message is enough", async () => {
  const gateway = new FakeGateway();
  gateway.canInquire = false;
  const db = new FakeDb();
  assertEquals(
    (await handleWebhook(post(), "fake", db, () => gateway)).status,
    200,
  );
  assertEquals(db.applied.length, 1);
});

Deno.test("a failure is applied without asking the provider", async () => {
  const gateway = new FakeGateway();
  gateway.webhook = payment({ status: "failed" });
  gateway.inquiryFails = true;
  const db = new FakeDb();
  assertEquals(
    (await handleWebhook(post(), "fake", db, () => gateway)).status,
    200,
  );
  assertEquals(db.applied[0].status, "failed");
});

Deno.test("a repeated webhook is answered 200 and applied once by the database", async () => {
  const db = new FakeDb();
  db.outcome = { outcome: "duplicate" };
  const response = await handleWebhook(
    post(),
    "fake",
    db,
    () => new FakeGateway(),
  );
  assertEquals(response.status, 200);
  assertEquals((await response.json()).outcome, "duplicate");
});

Deno.test("a webhook that is not about a payment is acknowledged", async () => {
  const gateway = new FakeGateway();
  gateway.webhook = null;
  const db = new FakeDb();
  assertEquals(
    (await handleWebhook(post(), "fake", db, () => gateway)).status,
    200,
  );
  assertEquals(db.applied.length, 0);
});

Deno.test("a database outage asks the provider to try again", async () => {
  const db = new FakeDb();
  db.failApply = true;
  assertEquals(
    (await handleWebhook(post(), "fake", db, () => new FakeGateway())).status,
    503,
  );
});

Deno.test("an unknown provider or a bad body is refused", async () => {
  const db = new FakeDb();
  assertEquals(
    (await handleWebhook(post(), "nope", db, () => null)).status,
    503,
  );
  const bad = new Request("https://x/payment-webhook", {
    method: "POST",
    body: "not json",
  });
  assertEquals(
    (await handleWebhook(bad, "fake", db, () => new FakeGateway())).status,
    400,
  );
  const get = new Request("https://x/payment-webhook");
  assertEquals(
    (await handleWebhook(get, "fake", db, () => new FakeGateway())).status,
    405,
  );
});

Deno.test("reconciling applies what the provider says about waiting orders", async () => {
  const db = new FakeDb();
  db.waiting = [
    { id: "a", provider: "fake", provider_order_id: "o1" },
    { id: "b", provider: "fake", provider_order_id: "o2" },
  ];
  const gateway = new FakeGateway();
  const result = await reconcile(db, () => gateway);
  assertEquals(result, { checked: 2, applied: 2, failed: 0 });
  assertEquals(db.applied.length, 2);
});

Deno.test("reconciling skips what the provider has nothing for and counts failures", async () => {
  const db = new FakeDb();
  db.waiting = [
    { id: "a", provider: "fake", provider_order_id: "o1" },
    { id: "b", provider: "fake", provider_order_id: "o2" },
  ];
  const gateway = new FakeGateway();
  gateway.inquiry = null;
  assertEquals(await reconcile(db, () => gateway), {
    checked: 2,
    applied: 0,
    failed: 0,
  });
  gateway.inquiryFails = true;
  assertEquals((await reconcile(db, () => gateway)).failed, 2);
});

Deno.test("create requests are validated", () => {
  const id = "0b8f6c8e-2a54-4a06-9b9e-0f6f2a4e5b11";
  assertEquals(
    parseCreateRequest({
      purpose: "credit_pack",
      pack_id: id,
      expected_price_piastres: 2000,
    }),
    { purpose: "credit_pack", packId: id, expectedPricePiastres: 2000 },
  );
  assertEquals(parseCreateRequest({ purpose: "escrow", request_id: id }), {
    purpose: "escrow",
    requestId: id,
  });
  assertEquals(
    parseCreateRequest({ purpose: "escrow", request_id: "x" }),
    null,
  );
  assertEquals(
    parseCreateRequest({
      purpose: "credit_pack",
      pack_id: id,
      expected_price_piastres: -5,
    }),
    null,
  );
  assertEquals(parseCreateRequest({ purpose: "free_money" }), null);
  assertEquals(parseCreateRequest(null), null);
  // An amount sent by the app is not part of the request at all.
  assertEquals(
    parseCreateRequest({
      purpose: "escrow",
      request_id: id,
      amount_piastres: 1,
    }),
    { purpose: "escrow", requestId: id },
  );
});

const urls = { webhookUrl: "https://x/hook", returnUrl: null };
const request: CreateRequest = { purpose: "escrow", requestId: "r" };
const session = (fail?: Error) => ({
  createOrder: () =>
    fail ? Promise.reject(fail) : Promise.resolve({
      orderId: "ord-1",
      amountPiastres: 45000,
      currency: "EGP",
      description: "R-1",
    }),
  billing: () => Promise.resolve({ name: null, phone: null }),
});

Deno.test("starting a payment opens the checkout and remembers it", async () => {
  const db = new FakeDb();
  const response = await startPayment(
    request,
    session(),
    new FakeGateway(),
    db,
    urls,
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.checkout_url, "https://pay/x");
  assertEquals(body.order_id, "ord-1");
  assertEquals(db.attached, [["ord-1", "fake", "o1"]]);
});

Deno.test("a refusal by the database reaches the app by name", async () => {
  const response = await startPayment(
    request,
    session(new OrderRefusedError("price_changed", 409)),
    new FakeGateway(),
    new FakeDb(),
    urls,
  );
  assertEquals(response.status, 409);
  assertEquals((await response.json()).error, "price_changed");
});

Deno.test("a provider outage leaves the order for a retry", async () => {
  const gateway = new FakeGateway();
  gateway.checkoutFails = true;
  const db = new FakeDb();
  const response = await startPayment(request, session(), gateway, db, urls);
  assertEquals(response.status, 502);
  assertEquals(db.attached.length, 0);
});

const refundSession = {
  adminId: "admin-1",
  target: () =>
    Promise.resolve({
      orderId: "ord-1",
      provider: "fake",
      providerTxnId: "t1",
      amountPiastres: 45000,
    }),
};

Deno.test("a refund goes to the provider and is recorded", async () => {
  const db = new FakeDb();
  const response = await refundEscrow(
    "e",
    refundSession,
    () => new FakeGateway(),
    db,
  );
  assertEquals(response.status, 200);
  assertEquals(db.refunds, [["ord-1", "RF1", "admin-1"]]);
});

Deno.test("a provider that cannot refund by API asks for the dashboard", async () => {
  const gateway = new FakeGateway();
  gateway.refundError = new UnsupportedError("no");
  const db = new FakeDb();
  const response = await refundEscrow("e", refundSession, () => gateway, db);
  assertEquals(response.status, 501);
  assertEquals(db.refunds.length, 0);
});

Deno.test("a refused refund is not recorded", async () => {
  const gateway = new FakeGateway();
  gateway.refundError = new GatewayError("no");
  const db = new FakeDb();
  const response = await refundEscrow("e", refundSession, () => gateway, db);
  assertEquals(response.status, 502);
  assertEquals(db.refunds.length, 0);
});

Deno.test("only an admin may refund", async () => {
  const response = await refundEscrow(
    "e",
    {
      adminId: "x",
      target: () =>
        Promise.reject(new OrderRefusedError("admin_required", 403)),
    },
    () => new FakeGateway(),
    new FakeDb(),
  );
  assertEquals(response.status, 403);
});

Deno.test("the provider is chosen by configuration, not by code", () => {
  const env = (name: string) =>
    ({
      PAYMOB_SECRET_KEY: "s",
      PAYMOB_PUBLIC_KEY: "p",
      PAYMOB_HMAC_SECRET: "h",
      PAYMOB_INTEGRATION_IDS: "1",
    })[name];
  assertEquals(activeProviderId(env), "paymob");
  assertEquals(gatewayFor("paymob", env)?.id, "paymob");
  assertEquals(gatewayFor("paytabs", env), null);
  assertEquals(gatewayFor("paymob", () => undefined), null);
  assertEquals(
    activeProviderId((n) => (n === "PAYMENT_PROVIDER" ? "PayTabs" : undefined)),
    "paytabs",
  );
});
