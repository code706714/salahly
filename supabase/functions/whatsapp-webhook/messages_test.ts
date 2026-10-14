import { assertEquals } from "jsr:@std/assert@1";
import { extractLoginMessages, findCode } from "./messages.ts";

function call(...messages: Record<string, unknown>[]) {
  return { entry: [{ changes: [{ value: { messages } }] }] };
}

Deno.test("the code is found in a message, in any case", () => {
  assertEquals(findCode("صلحلي - كود الدخول: ab3d5fgh"), "AB3D5FGH");
  assertEquals(findCode("كود الدخول AB3D5FGH شكرا"), "AB3D5FGH");
});

Deno.test("a message without a code carries none", () => {
  assertEquals(findCode("السلام عليكم"), null);
  assertEquals(findCode("AB3D5FG"), null);
  assertEquals(findCode("AB3D5FGH2"), null);
  // 0, 1, I and O are never in a code.
  assertEquals(findCode("AB3D5FG1"), null);
});

Deno.test("a text message with a code gives its sender and code", () => {
  const messages = extractLoginMessages(
    call({
      type: "text",
      from: "201002345678",
      text: { body: "كود الدخول: AB3D5FGH" },
    }),
  );
  assertEquals(messages, [{ phone: "+201002345678", code: "AB3D5FGH" }]);
});

Deno.test("only text messages with a code count", () => {
  const messages = extractLoginMessages(
    call(
      { type: "image", from: "201002345678", text: { body: "AB3D5FGH" } },
      { type: "text", from: "201002345678", text: { body: "أهلا" } },
      { type: "text", from: "not a number", text: { body: "AB3D5FGH" } },
      { type: "text", from: "201002345678" },
    ),
  );
  assertEquals(messages, []);
});

Deno.test("a payload of another shape gives nothing", () => {
  assertEquals(extractLoginMessages(null), []);
  assertEquals(extractLoginMessages("x"), []);
  assertEquals(extractLoginMessages({ entry: "x" }), []);
  assertEquals(extractLoginMessages({ entry: [{ changes: [null] }] }), []);
  // A delivery status has no messages.
  assertEquals(
    extractLoginMessages({
      entry: [{ changes: [{ value: { statuses: [{ id: "1" }] } }] }],
    }),
    [],
  );
});
