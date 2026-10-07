// Sends the pushes waiting in the database. Notifications worth a push are
// queued by a trigger; this function (service role, woken by the database
// through pg_net with a shared secret, and by pg_cron as a retry) claims the
// queue, sends each message through Firebase Cloud Messaging, removes the
// phones Firebase no longer knows and reports the messages done. A failed
// message simply stays queued and is tried again (up to 5 times).
//
// Nothing is logged but counts: no token, no name, no message text.
import { createClient } from "npm:@supabase/supabase-js@2";
import { isAuthorized } from "../_shared/shared_secret.ts";
import { sendBatch } from "./dispatch.ts";
import { FcmClient, parseServiceAccount } from "./fcm.ts";
import type { PushItem } from "./message.ts";

const batchSize = 50;
const maxBatches = 5;

Deno.serve(async (request) => {
  if (
    !isAuthorized(
      Deno.env.get("PUSH_SECRET"),
      request.headers.get("x-push-secret"),
    )
  ) {
    return new Response("forbidden", { status: 403 });
  }

  const account = parseServiceAccount(Deno.env.get("FCM_SERVICE_ACCOUNT_JSON"));
  if (account === null) {
    // Firebase is not set up yet: leave the queue as it is.
    return new Response("not configured", { status: 503 });
  }
  const fcm = new FcmClient(account);
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let sent = 0;
  let retry = 0;
  for (let batch = 0; batch < maxBatches; batch++) {
    const { data, error } = await admin.rpc("push_claim", {
      p_limit: batchSize,
    });
    if (error) {
      return new Response("claim failed", { status: 500 });
    }
    const items = (data ?? []) as PushItem[];
    if (items.length === 0) {
      break;
    }
    const result = await sendBatch(items, fcm);
    const { error: doneError } = await admin.rpc("push_done", {
      p_ids: result.doneIds,
      p_dead_tokens: result.deadTokens,
    });
    if (doneError) {
      return new Response("report failed", { status: 500 });
    }
    sent += result.sent;
    retry += result.retry;
    if (items.length < batchSize) {
      break;
    }
  }
  return Response.json({ sent, retry });
});
