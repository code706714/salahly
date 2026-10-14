import { assertEquals } from "jsr:@std/assert@1";
import { isValidSignature } from "./signature.ts";

async function sign(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(body),
  );
  const hex = [...new Uint8Array(mac)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return `sha256=${hex}`;
}

const secret = "app-secret";
const body = '{"entry":[]}';

Deno.test("the signature of the body made with the secret is valid", async () => {
  assertEquals(
    await isValidSignature(secret, body, await sign(secret, body)),
    true,
  );
});

Deno.test("another body, another secret or no signature is refused", async () => {
  const signature = await sign(secret, body);
  assertEquals(await isValidSignature(secret, body + " ", signature), false);
  assertEquals(await isValidSignature("other", body, signature), false);
  assertEquals(await isValidSignature(secret, body, null), false);
  assertEquals(await isValidSignature(secret, body, "sha256="), false);
  assertEquals(await isValidSignature(secret, body, signature.slice(7)), false);
});

Deno.test("without a configured secret nothing is valid", async () => {
  const signature = await sign(secret, body);
  assertEquals(await isValidSignature(undefined, body, signature), false);
  assertEquals(await isValidSignature("", body, signature), false);
});
