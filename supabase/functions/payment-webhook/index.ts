// The payment provider's server-to-server call: "this payment succeeded /
// failed / is pending / was refunded". The URL is
//   .../functions/v1/payment-webhook?provider=paymob
// and the provider signs every call; nothing unsigned is believed. Set the
// same URL as the "Transaction processed callback" of each integration in the
// provider's dashboard (wallet payments report only there).
//
// Nothing is logged: no name, no phone, no payload.
import { createClient } from "npm:@supabase/supabase-js@2";
import { gatewayFor } from "../_shared/payments/registry.ts";
import { handleWebhook } from "../_shared/payments/service.ts";
import { SupabasePaymentsDb } from "../_shared/payments/supabase_db.ts";

const env = (name: string) => Deno.env.get(name);

Deno.serve((request) => {
  const provider = (new URL(request.url).searchParams.get("provider") ??
    "paymob").toLowerCase();
  const db = new SupabasePaymentsDb(
    createClient(env("SUPABASE_URL")!, env("SUPABASE_SERVICE_ROLE_KEY")!),
  );
  return handleWebhook(request, provider, db, (id) => gatewayFor(id, env));
});
