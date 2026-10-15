import { assertEquals } from "jsr:@std/assert@1";
import { androidOptions } from "./fcm.ts";

Deno.test("a call rings on its own channel and expires within a minute", () => {
  assertEquals(androidOptions("incoming_call"), {
    priority: "HIGH",
    ttl: "45s",
    notification: { channel_id: "salahly_calls" },
  });
});

Deno.test("an urgent request is dropped after the half hour it lives", () => {
  assertEquals(androidOptions("urgent_request").ttl, "1800s");
});

Deno.test("any other push uses the general channel and the default expiry", () => {
  assertEquals(androidOptions("offer_received"), {
    priority: "HIGH",
    notification: { channel_id: "salahly_general" },
  });
  assertEquals(androidOptions(undefined).ttl, undefined);
});
