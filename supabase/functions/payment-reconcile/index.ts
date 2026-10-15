// Settles payments whose webhook never came (or came out of order): asks the
// provider about every order still undecided and applies the answer exactly as
// a webhook would. Woken by pg_cron through pg_net with a shared secret.
import { createClient } from "npm:@supabase/supabase-js@2";
import { gatewayFor } from "../_shared/payments/registry.ts";
import { reconcile } from "../_shared/payments/service.ts";
import { SupabasePaymentsDb } from "../_shared/payments/supabase_db.ts";
import { isAuthorized } from "../_shared/shared_secret.ts";

const env = (name: string) => Deno.env.get(name);

Deno.serve(async (request) => {
  if (
    !isAuthorized(
      env("PAYMENT_RECONCILE_SECRET"),
      request.headers.get("x-payment-secret"),
    )
  ) {
    return new Response("forbidden", { status: 403 });
  }
  const db = new SupabasePaymentsDb(
    createClient(env("SUPABASE_URL")!, env("SUPABASE_SERVICE_ROLE_KEY")!),
  );
  try {
    const result = await reconcile(db, (id) => gatewayFor(id, env));
    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch {
    return new Response("error", { status: 500 });
  }
});
