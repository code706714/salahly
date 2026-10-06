import { assertEquals } from "jsr:@std/assert@1";
import { isAuthorized, minSecretLength, safeEqual } from "./auth.ts";

const secret = "s".repeat(minSecretLength);

Deno.test("safeEqual accepts equal strings only", () => {
  assertEquals(safeEqual("abc", "abc"), true);
  assertEquals(safeEqual("abc", "abd"), false);
  assertEquals(safeEqual("abc", "abcd"), false);
  assertEquals(safeEqual("", "a"), false);
  assertEquals(safeEqual("é", "é"), true);
});

Deno.test("the right secret is authorized", () => {
  assertEquals(isAuthorized(secret, secret), true);
});

Deno.test("a wrong or missing secret is refused", () => {
  assertEquals(isAuthorized(secret, "x".repeat(minSecretLength)), false);
  assertEquals(isAuthorized(secret, null), false);
  assertEquals(isAuthorized(secret, ""), false);
});

Deno.test("a secret that is not configured never matches", () => {
  assertEquals(isAuthorized(undefined, null), false);
  assertEquals(isAuthorized("", ""), false);
});

Deno.test("a too short secret is refused even when it matches", () => {
  const short = "s".repeat(minSecretLength - 1);
  assertEquals(isAuthorized(short, short), false);
});
