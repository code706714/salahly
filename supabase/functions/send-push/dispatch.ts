// Sends a claimed batch and works out what to report back to the database.
import type { SendOutcome } from "./fcm.ts";
import { buildMessage, type PushItem, type PushMessage } from "./message.ts";

export interface Sender {
  send(token: string, message: PushMessage): Promise<SendOutcome>;
}

export interface BatchResult {
  /** Messages that are finished, sent or hopeless. */
  doneIds: number[];
  /** Tokens Firebase no longer knows. */
  deadTokens: string[];
  /** Messages at least one phone took. */
  sent: number;
  /** Messages left in the queue to be tried again. */
  retry: number;
}

/**
 * Sends each message to every phone of its recipient. A message is finished
 * when at least one phone took it or none can (so a phone that already got
 * it is not sent it twice), and is left for later only when every phone
 * failed for now.
 */
export async function sendBatch(
  items: PushItem[],
  sender: Sender,
): Promise<BatchResult> {
  const result: BatchResult = {
    doneIds: [],
    deadTokens: [],
    sent: 0,
    retry: 0,
  };
  for (const item of items) {
    const message = buildMessage(item);
    if (message === null) {
      result.doneIds.push(item.id);
      continue;
    }
    const outcomes = await Promise.all(
      item.tokens.map(async (token) => ({
        token,
        outcome: await sender.send(token, message),
      })),
    );
    for (const { token, outcome } of outcomes) {
      if (outcome === "unregistered") {
        result.deadTokens.push(token);
      }
    }
    const anySent = outcomes.some(({ outcome }) => outcome === "sent");
    const anyRetry = outcomes.some(({ outcome }) => outcome === "retry");
    if (anySent) {
      result.sent++;
    }
    if (anySent || !anyRetry) {
      result.doneIds.push(item.id);
    } else {
      result.retry++;
    }
  }
  return result;
}
