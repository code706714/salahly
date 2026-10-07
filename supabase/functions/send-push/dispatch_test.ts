import { assertEquals } from "jsr:@std/assert@1";
import { sendBatch, type Sender } from "./dispatch.ts";
import type { SendOutcome } from "./fcm.ts";
import type { PushItem } from "./message.ts";

function item(id: number, tokens: string[], kind = "job_started"): PushItem {
  return {
    id,
    kind,
    role: "consumer",
    request_id: null,
    technician_name: "محمود",
    honorific: "mr",
    tokens,
  };
}

/** Answers per token and records what it was asked to send. */
function sender(outcomes: Record<string, SendOutcome>) {
  const sent: string[] = [];
  const fake: Sender = {
    send(token) {
      sent.push(token);
      return Promise.resolve(outcomes[token] ?? "sent");
    },
  };
  return { fake, sent };
}

Deno.test("a message goes to every phone of its recipient", async () => {
  const { fake, sent } = sender({});
  const result = await sendBatch([item(1, ["a", "b", "c"])], fake);
  assertEquals(sent.sort(), ["a", "b", "c"]);
  assertEquals(result, { doneIds: [1], deadTokens: [], sent: 1, retry: 0 });
});

Deno.test("a token Firebase doesn't know is reported for removal", async () => {
  const { fake } = sender({ b: "unregistered" });
  const result = await sendBatch([item(1, ["a", "b"])], fake);
  assertEquals(result.deadTokens, ["b"]);
  assertEquals(result.doneIds, [1]);
});

Deno.test("a message that only failed for now stays queued", async () => {
  const { fake } = sender({ a: "retry", b: "retry" });
  const result = await sendBatch([item(1, ["a", "b"])], fake);
  assertEquals(result, { doneIds: [], deadTokens: [], sent: 0, retry: 1 });
});

Deno.test("one phone taking it is enough, so the others aren't sent it twice", async () => {
  const { fake } = sender({ a: "retry", b: "sent" });
  const result = await sendBatch([item(1, ["a", "b"])], fake);
  assertEquals(result.doneIds, [1]);
  assertEquals(result.retry, 0);
});

Deno.test("a message nobody can take is finished, not retried forever", async () => {
  const { fake } = sender({ a: "rejected", b: "unregistered" });
  const result = await sendBatch([item(1, ["a", "b"])], fake);
  assertEquals(result.doneIds, [1]);
  assertEquals(result.sent, 0);
  assertEquals(result.deadTokens, ["b"]);
});

Deno.test("a kind this version doesn't know is dropped without sending", async () => {
  const { fake, sent } = sender({});
  const result = await sendBatch([item(1, ["a"], "from_the_future")], fake);
  assertEquals(sent, []);
  assertEquals(result.doneIds, [1]);
});

Deno.test("each message is judged on its own", async () => {
  const { fake } = sender({ x: "retry" });
  const result = await sendBatch(
    [item(1, ["a"]), item(2, ["x"]), item(3, ["c"])],
    fake,
  );
  assertEquals(result.doneIds, [1, 3]);
  assertEquals(result.retry, 1);
  assertEquals(result.sent, 2);
});
