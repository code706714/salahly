// Meta signs every webhook call with the app secret: the header holds
// "sha256=" and the hex HMAC-SHA256 of the raw body.
import { safeEqual } from "../_shared/shared_secret.ts";

const prefix = "sha256=";

function toHex(bytes: ArrayBuffer): string {
  return [...new Uint8Array(bytes)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/** True when [header] is the signature of [body] made with [secret]. */
export async function isValidSignature(
  secret: string | undefined,
  body: string,
  header: string | null,
): Promise<boolean> {
  if (!secret || header === null || !header.startsWith(prefix)) {
    return false;
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const expected = toHex(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body)),
  );
  return safeEqual(header.slice(prefix.length).toLowerCase(), expected);
}
