// Removes the files of deleted accounts. delete_my_account() queues their
// paths; this function (service role, woken by pg_cron through pg_net with
// a shared secret) deletes them through the Storage API and then reports
// them done, so a failed batch is simply tried again later.
import { createClient } from "npm:@supabase/supabase-js@2";

const batchSize = 100;
const maxBatches = 10;

Deno.serve(async (request) => {
  const secret = Deno.env.get("PURGE_STORAGE_SECRET");
  if (!secret || request.headers.get("x-purge-secret") !== secret) {
    return new Response("forbidden", { status: 403 });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let removed = 0;
  for (let batch = 0; batch < maxBatches; batch++) {
    const { data: claimed, error } = await admin.rpc("storage_purge_claim", {
      p_limit: batchSize,
    });
    if (error) {
      return new Response("claim failed", { status: 500 });
    }
    if (!claimed || claimed.length === 0) {
      break;
    }

    const byBucket = new Map<string, { id: number; name: string }[]>();
    for (const file of claimed) {
      const files = byBucket.get(file.bucket_id) ?? [];
      files.push({ id: file.id, name: file.name });
      byBucket.set(file.bucket_id, files);
    }

    const done: number[] = [];
    for (const [bucket, files] of byBucket) {
      const { error: removeError } = await admin.storage
        .from(bucket)
        .remove(files.map((file) => file.name));
      if (!removeError) {
        done.push(...files.map((file) => file.id));
      }
    }
    if (done.length > 0) {
      await admin.rpc("storage_purge_done", { p_ids: done });
      removed += done.length;
    }
    if (done.length === 0) {
      break;
    }
  }
  return Response.json({ removed });
});
