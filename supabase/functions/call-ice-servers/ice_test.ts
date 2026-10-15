import { assertEquals } from "jsr:@std/assert@1";
import { cleanServers, fallbackServers, meteredServers } from "./ice.ts";

Deno.test("keeps the STUN and TURN servers of the relay's answer", () => {
  const servers = cleanServers({
    iceServers: [
      { urls: ["stun:stun.cloudflare.com:3478"] },
      {
        urls: ["turn:turn.cloudflare.com:3478?transport=udp"],
        username: "user",
        credential: "secret",
      },
    ],
  });

  assertEquals(servers, [
    { urls: ["stun:stun.cloudflare.com:3478"] },
    {
      urls: ["turn:turn.cloudflare.com:3478?transport=udp"],
      username: "user",
      credential: "secret",
    },
  ]);
});

Deno.test("passes on nothing but the three fields", () => {
  const servers = cleanServers({
    iceServers: [{ urls: "stun:a", extra: "x" }],
    apiToken: "never",
  });

  assertEquals(servers, [{ urls: ["stun:a"] }]);
});

Deno.test("skips entries that are not servers", () => {
  const servers = cleanServers({
    iceServers: [null, 4, { urls: [] }, { urls: [1] }, { urls: ["turn:b"] }],
  });

  assertEquals(servers, [{ urls: ["turn:b"] }]);
});

Deno.test("answers null when there is nothing usable", () => {
  assertEquals(cleanServers(null), null);
  assertEquals(cleanServers({}), null);
  assertEquals(cleanServers({ iceServers: [] }), null);
});

Deno.test("falls back to a public STUN server", () => {
  assertEquals(fallbackServers.length, 1);
});

Deno.test("builds Metered's servers around the fixed login", () => {
  const servers = meteredServers("user", "secret");

  assertEquals(servers.length, 5);
  assertEquals(servers[0], { urls: "stun:stun.relay.metered.ca:80" });
  assertEquals(
    servers.slice(1).every((s) =>
      s.username === "user" && s.credential === "secret"
    ),
    true,
  );
  assertEquals(
    servers[4].urls,
    "turns:global.relay.metered.ca:443?transport=tcp",
  );
});
