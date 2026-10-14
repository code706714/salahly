import { assertEquals } from "jsr:@std/assert@1";
import { handleLogin, type LoginDeps } from "./login.ts";

const id = "11111111-2222-4333-8444-555555555555";
const secret = "a".repeat(64);

function deps(overrides: Partial<LoginDeps> = {}): LoginDeps {
  return {
    whatsappNumber: "201000000000",
    start: () =>
      Promise.resolve({
        id,
        code: "AB3D5FGH",
        poll_secret: secret,
        expires_at: "2026-10-14T12:00:00Z",
      }),
    status: () => Promise.resolve("pending"),
    claim: () => Promise.resolve("+201002345678"),
    preparePassword: () => Promise.resolve("one-time"),
    ...overrides,
  };
}

Deno.test("start gives the phone its code and where to send it", async () => {
  const result = await handleLogin({ action: "start" }, deps());
  assertEquals(result.status, 200);
  assertEquals(result.body, {
    id,
    code: "AB3D5FGH",
    pollSecret: secret,
    expiresAt: "2026-10-14T12:00:00Z",
    whatsappNumber: "201000000000",
  });
});

Deno.test("start says unavailable while no WhatsApp number is set", async () => {
  const result = await handleLogin(
    { action: "start" },
    deps({ whatsappNumber: "" }),
  );
  assertEquals(result.status, 503);
  assertEquals(result.body, { error: "unavailable" });
});

Deno.test("start says busy when the database refuses a new code", async () => {
  const result = await handleLogin(
    { action: "start" },
    deps({ start: () => Promise.reject(new Error("busy")) }),
  );
  assertEquals(result.status, 503);
  assertEquals(result.body, { error: "busy" });
});

Deno.test("status passes the database's answer on", async () => {
  const result = await handleLogin(
    { action: "status", id, pollSecret: secret },
    deps({ status: () => Promise.resolve("ready") }),
  );
  assertEquals(result.status, 200);
  assertEquals(result.body, { status: "ready" });
});

Deno.test("complete gives the number's one-time password", async () => {
  const result = await handleLogin(
    { action: "complete", id, pollSecret: secret },
    deps(),
  );
  assertEquals(result.status, 200);
  assertEquals(result.body, { phone: "+201002345678", password: "one-time" });
});

Deno.test("complete before WhatsApp told us makes no account", async () => {
  let prepared = false;
  const result = await handleLogin(
    { action: "complete", id, pollSecret: secret },
    deps({
      claim: () => Promise.resolve(null),
      preparePassword: () => {
        prepared = true;
        return Promise.resolve("x");
      },
    }),
  );
  assertEquals(result.status, 409);
  assertEquals(prepared, false);
});

Deno.test("a malformed request never reaches the database", async () => {
  let asked = false;
  const spy = deps({
    status: () => {
      asked = true;
      return Promise.resolve("ready");
    },
  });
  for (
    const input of [
      null,
      "start",
      {},
      { action: "other" },
      { action: "status" },
      { action: "status", id: "x", pollSecret: secret },
      { action: "status", id, pollSecret: "short" },
      { action: "complete", id, pollSecret: 5 },
    ]
  ) {
    assertEquals((await handleLogin(input, spy)).status, 400);
  }
  assertEquals(asked, false);
});
