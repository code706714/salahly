// Gives a signed-in phone the servers it needs for a voice call. When a TURN
// relay is set up, the answer includes it with its credentials, so a call
// still connects when the two phones can't reach each other directly. Two
// relays are supported, tried in this order: Cloudflare (secrets TURN_KEY_ID
// and TURN_KEY_API_TOKEN, credentials that expire in an hour) and Metered
// (secrets METERED_APP and METERED_API_KEY). The keys never leave this
// function. Without one, or if the relay fails, the answer is the public
// STUN server: the call just may not connect on some networks.
//
// Signed-in callers only (the platform checks the JWT).
import { cleanServers, fallbackServers, type IceServer } from "./ice.ts";

const ttlSeconds = 3600;

/// Servers from Cloudflare when its TURN key is set.
async function fromCloudflare(): Promise<IceServer[] | null> {
  const keyId = Deno.env.get("TURN_KEY_ID");
  const token = Deno.env.get("TURN_KEY_API_TOKEN");
  if (!keyId || !token) return null;
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
  return response.ok ? cleanServers(await response.json()) : null;
}

/// Servers from Metered when its app name and key are set.
async function fromMetered(): Promise<IceServer[] | null> {
  const app = Deno.env.get("METERED_APP");
  const key = Deno.env.get("METERED_API_KEY");
  if (!app || !key || !/^[a-z0-9-]+$/i.test(app)) return null;
  const response = await fetch(
    `https://${app}.metered.live/api/v1/turn/credentials?apiKey=${
      encodeURIComponent(key)
    }`,
    { signal: AbortSignal.timeout(5000) },
  );
  return response.ok
    ? cleanServers({ iceServers: await response.json() })
    : null;
}

Deno.serve(async () => {
  let servers = fallbackServers;
  for (const provider of [fromCloudflare, fromMetered]) {
    try {
      const found = await provider();
      if (found !== null) {
        servers = found;
        break;
      }
    } catch {
      // Try the next one, then the public STUN server.
    }
  }
  return new Response(JSON.stringify({ iceServers: servers }), {
    headers: { "Content-Type": "application/json" },
  });
});
