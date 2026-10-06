// The shared secret that wakes the purge function.

/** The shortest secret the function accepts; shorter ones are guessable. */
export const minSecretLength = 32;

/** Compares two strings without stopping at the first difference. */
export function safeEqual(a: string, b: string): boolean {
  const encoder = new TextEncoder();
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  let diff = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let i = 0; i < length; i++) {
    diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  }
  return diff === 0;
}

/** True when the request carries the configured, long enough secret. */
export function isAuthorized(
  configured: string | undefined,
  presented: string | null,
): boolean {
  if (!configured || configured.length < minSecretLength) {
    return false;
  }
  if (presented === null) {
    return false;
  }
  return safeEqual(presented, configured);
}
