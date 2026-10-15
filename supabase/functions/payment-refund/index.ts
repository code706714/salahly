// An admin returns an escrow's money to the consumer through the provider.
// The database checks the caller is an admin who signed in recently and that
// the escrow is due back; a provider that cannot refund by API (or a merchant
// account without that right) answers 501 and the refund is made from the
// provider's dashboard, where its webhook then closes the escrow.
import { createClient } from "npm:@supabase/supabase-js@2";
import { gatewayFor } from "../_shared/payments/registry.ts";
import { refundEscrow } from "../_shared/payments/service.ts";
import {
  SupabasePaymentsDb,
  SupabaseRefundSession,
} from "../_shared/payments/supabase_db.ts";

const env = (name: string) => Deno.env.get(name);

// The admin console runs in a browser, which asks permission (OPTIONS) first.
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(error: string, status: number): Response {
  return new Response(JSON.stringify({ error }), {
    status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

function withCors(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(cors)) headers.set(name, value);
  return new Response(response.body, { status: response.status, headers });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors });
  }
  if (request.method !== "POST") return reply("method_not_allowed", 405);
  const authorization = request.headers.get("Authorization");
  if (authorization === null) return reply("not_signed_in", 401);

  let escrowId: unknown;
  try {
    escrowId = (await request.json()).escrow_id;
  } catch {
    return reply("bad_request", 400);
  }
  if (typeof escrowId !== "string" || !/^[0-9a-f-]{36}$/i.test(escrowId)) {
    return reply("bad_request", 400);
  }

  const url = env("SUPABASE_URL")!;
  const user = createClient(url, env("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
  });
  const { data } = await user.auth.getUser();
  if (!data.user) return reply("not_signed_in", 401);

  const db = new SupabasePaymentsDb(
    createClient(url, env("SUPABASE_SERVICE_ROLE_KEY")!),
  );
  return withCors(
    await refundEscrow(
      escrowId,
      new SupabaseRefundSession(user, data.user.id),
      (id) => gatewayFor(id, env),
      db,
    ),
  );
});
