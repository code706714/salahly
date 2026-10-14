// Receives WhatsApp messages from Meta and signs people in with them: a
// message that carries a live sign-in code ties the code to the number that
// sent it (the phone is polling for exactly that). It never answers the
// sender, so no message of ours is ever billed.
//
// Meta checks the address once with a GET (the verify token), then calls it
// with a POST for every message, signed with the app secret. Anything we do
// not understand still gets a 200, or Meta keeps retrying it.
//
// Nothing is logged but counts: no number, no code, no message text.
import { createClient } from "npm:@supabase/supabase-js@2";
import { safeEqual } from "../_shared/shared_secret.ts";
import { extractLoginMessages } from "./messages.ts";
import { isValidSignature } from "./signature.ts";

Deno.serve(async (request) => {
  const verifyToken = Deno.env.get("WHATSAPP_VERIFY_TOKEN");
  const appSecret = Deno.env.get("WHATSAPP_APP_SECRET");
  if (!verifyToken || !appSecret) {
    // WhatsApp is not set up yet.
    return new Response("not configured", { status: 503 });
  }

  if (request.method === "GET") {
    const url = new URL(request.url);
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");
    if (
      url.searchParams.get("hub.mode") === "subscribe" &&
      token !== null && challenge !== null && safeEqual(token, verifyToken)
    ) {
      return new Response(challenge);
    }
    return new Response("forbidden", { status: 403 });
  }
  if (request.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  const body = await request.text();
  if (
    !await isValidSignature(
      appSecret,
      body,
      request.headers.get("x-hub-signature-256"),
    )
  ) {
    return new Response("forbidden", { status: 403 });
  }

  let payload: unknown;
  try {
    payload = JSON.parse(body);
  } catch {
    return new Response("ok");
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  let tied = 0;
  for (const message of extractLoginMessages(payload)) {
    const { data, error } = await admin.rpc("login_bind", {
      p_code: message.code,
      p_phone: message.phone,
    });
    if (error) {
      // Ask Meta to deliver it again.
      return new Response("bind failed", { status: 500 });
    }
    if (data === true) tied++;
  }
  return Response.json({ tied });
});
