// Signs a phone in with a WhatsApp message instead of a code sent to it; see
// login.ts for the three steps and the migration for the tables. This
// function sits between the phone (no session yet) and the database, and is
// the only place that can create the account and set its one-time password.
//
// Nothing is logged: no number, no code, no password.
import { createClient } from "npm:@supabase/supabase-js@2";
import { type Challenge, handleLogin, type LoginDeps } from "./login.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function newPassword(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

async function existingUserId(phone: string): Promise<string | null> {
  const { data, error } = await admin.rpc("login_user_id", { p_phone: phone });
  if (error) throw error;
  return (data as string | null) ?? null;
}

const deps: LoginDeps = {
  whatsappNumber: (Deno.env.get("WHATSAPP_LOGIN_NUMBER") ?? "").replace(
    /\D/g,
    "",
  ),

  async start() {
    const { data, error } = await admin.rpc("login_start");
    if (error) throw error;
    return data as Challenge;
  },

  async status(id, secret) {
    const { data, error } = await admin.rpc("login_status", {
      p_id: id,
      p_poll_secret: secret,
    });
    if (error) throw error;
    return data as string;
  },

  async claim(id, secret) {
    const { data, error } = await admin.rpc("login_claim", {
      p_id: id,
      p_poll_secret: secret,
    });
    if (error) throw error;
    return (data as string | null) ?? null;
  },

  async preparePassword(phone) {
    const password = newPassword();
    const userId = await existingUserId(phone);
    if (userId !== null) {
      const { error } = await admin.auth.admin.updateUserById(userId, {
        password,
        phone_confirm: true,
      });
      if (error) throw error;
      return password;
    }
    const { error } = await admin.auth.admin.createUser({
      phone,
      phone_confirm: true,
      password,
    });
    if (error) {
      // Two sign-ins of the same new number at once: the other one won.
      const racedId = await existingUserId(phone);
      if (racedId === null) throw error;
      const { error: updateError } = await admin.auth.admin.updateUserById(
        racedId,
        { password },
      );
      if (updateError) throw updateError;
    }
    return password;
  },
};

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }
  let input: unknown;
  try {
    input = await request.json();
  } catch {
    return Response.json({ error: "invalid_request" }, { status: 400 });
  }
  try {
    const result = await handleLogin(input, deps);
    return Response.json(result.body, { status: result.status });
  } catch {
    return Response.json({ error: "failed" }, { status: 500 });
  }
});
