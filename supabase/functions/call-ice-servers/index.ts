// Gives a signed-in phone the servers it needs for a voice call. When the
// Cloudflare TURN key is set (secrets TURN_KEY_ID and TURN_KEY_API_TOKEN),
// that includes a relay with credentials that expire in an hour, so a call
// still connects when the two phones can't reach each other directly. The
// key itself never leaves this function. Without the key, or if Cloudflare
// fails, the answer is the public STUN server: the call just may not
// connect on some networks.
//
// Signed-in callers only (the platform checks the JWT).
import { cleanServers, fallbackServers } from "./ice.ts";

const ttlSeconds = 3600;

Deno.serve(async () => {
  const keyId = Deno.env.get("TURN_KEY_ID");
  const token = Deno.env.get("TURN_KEY_API_TOKEN");
  let servers = fallbackServers;
  if (keyId && token) {
    try {
      const response = await fetch(
        `https://rtc.live.cloudflare.com/v1/turn/keys/${keyId}/credentials/generate-ice-servers`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ ttl: ttlSeconds }),
          signal: AbortSignal.timeout(5000),
        },
      );
      if (response.ok) {
        servers = cleanServers(await response.json()) ?? fallbackServers;
      }
    } catch {
      // Keep the public STUN server.
    }
  }
  return new Response(JSON.stringify({ iceServers: servers }), {
    headers: { "Content-Type": "application/json" },
  });
});
