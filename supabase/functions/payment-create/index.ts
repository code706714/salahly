// Starts an online payment for the signed-in person: buying uses, or paying a
// request's price. The database creates the order and decides the amount (from
// the packs or the chosen offer); this function opens the checkout at the
// provider and returns the page to open. The app is never trusted for money,
// and no secret key ever leaves this function.
import { createClient } from "npm:@supabase/supabase-js@2";
import { activeProviderId, gatewayFor } from "../_shared/payments/registry.ts";
import {
  parseCreateRequest,
  startPayment,
} from "../_shared/payments/service.ts";
import {
  SupabaseCustomerSession,
  SupabasePaymentsDb,
} from "../_shared/payments/supabase_db.ts";

const env = (name: string) => Deno.env.get(name);

function reply(error: string, status: number): Response {
  return new Response(JSON.stringify({ error }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return reply("method_not_allowed", 405);
  const authorization = request.headers.get("Authorization");
  if (authorization === null) return reply("not_signed_in", 401);

  const gateway = gatewayFor(activeProviderId(env), env);
  if (gateway === null) return reply("payments_not_configured", 503);

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return reply("bad_request", 400);
  }
  const parsed = parseCreateRequest(body);
  if (parsed === null) return reply("bad_request", 400);

  const url = env("SUPABASE_URL")!;
  const user = createClient(url, env("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
  });
  const db = new SupabasePaymentsDb(
    createClient(url, env("SUPABASE_SERVICE_ROLE_KEY")!),
  );
  return startPayment(parsed, new SupabaseCustomerSession(user), gateway, db, {
    webhookUrl: `${url}/functions/v1/payment-webhook?provider=${gateway.id}`,
    returnUrl: env("PAYMENT_RETURN_URL") || null,
  });
});
