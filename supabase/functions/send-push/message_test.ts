import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { buildMessage, type PushItem } from "./message.ts";

const requestId = "11111111-2222-4333-8444-555555555555";

function item(overrides: Partial<PushItem> = {}): PushItem {
  return {
    id: 1,
    kind: "technician_arriving",
    role: "consumer",
    request_id: requestId,
    technician_name: "محمود",
    honorific: "ms",
    tokens: ["t"],
    ...overrides,
  };
}

Deno.test("the arriving push names the technician and opens the request", () => {
  const message = buildMessage(item())!;
  assertEquals(message.title, "محمود قرّب يوصلك");
  assertEquals(message.data, {
    kind: "technician_arriving",
    role: "consumer",
    request_id: requestId,
  });
});

Deno.test("without a name the technician is just 'الفني'", () => {
  assertEquals(
    buildMessage(item({ technician_name: null }))!.title,
    "الفني قرّب يوصلك",
  );
  assertEquals(
    buildMessage(item({ technician_name: "  " }))!.title,
    "الفني قرّب يوصلك",
  );
});

Deno.test("the copy follows the consumer's gender", () => {
  const price = (honorific: "ms" | "mr") =>
    buildMessage(item({ kind: "price_change", honorific }))!.body;
  assertEquals(price("ms"), "مش هيكمّل غير لما توافقي.");
  assertEquals(price("mr"), "مش هيكمّل غير لما توافق.");
});

Deno.test("a technician's push is masculine and has no names", () => {
  const message = buildMessage(
    item({
      kind: "offer_picked",
      role: "technician",
      technician_name: null,
      honorific: null,
    }),
  )!;
  assertEquals(message.title, "عرضك اتختار");
  assertEquals(message.data.role, "technician");
});

Deno.test("a request id that is not a uuid is not passed on", () => {
  const message = buildMessage(item({ request_id: "../../etc" }))!;
  assertEquals("request_id" in message.data, false);
  assertEquals(
    "request_id" in buildMessage(item({ request_id: null }))!.data,
    false,
  );
});

Deno.test("every kind that is pushed has a text, an unknown one has none", () => {
  const kinds = [
    "offer_received",
    "technician_arriving",
    "job_confirmed",
    "job_started",
    "job_finished",
    "price_change",
    "request_cancelled_by_technician",
    "request_expired",
    "new_request",
    "offer_picked",
    "request_cancelled_by_consumer",
    "verification_approved",
    "verification_rejected",
    "topup_approved",
    "topup_rejected",
  ];
  for (const kind of kinds) {
    assertEquals(buildMessage(item({ kind }))!.title.length > 0, true, kind);
  }
  assertEquals(buildMessage(item({ kind: "offer_not_picked" })), null);
  assertEquals(buildMessage(item({ kind: "something_new" })), null);
});

Deno.test("no push carries a phone number or an address", () => {
  const message = buildMessage(item())!;
  const { request_id: _requestId, ...rest } = message.data;
  const text = JSON.stringify({ ...message, data: rest });
  assertEquals(/\d{6,}/.test(text), false);
  assertStringIncludes(text, "قرّب");
});
