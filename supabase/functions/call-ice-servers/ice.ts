// The servers two phones use to find each other for a voice call.

export type IceServer = {
  urls: string | string[];
  username?: string;
  credential?: string;
};

/// Google's free STUN server: enough when the phones can reach each other
/// directly, and what a call falls back to when no relay is set up.
export const fallbackServers: IceServer[] = [
  { urls: "stun:stun.l.google.com:19302" },
];

/// The servers named in the relay's answer, or null when the answer holds
/// none that look right. Nothing else of the answer is passed on.
export function cleanServers(body: unknown): IceServer[] | null {
  if (typeof body !== "object" || body === null) return null;
  const list = (body as { iceServers?: unknown }).iceServers;
  const raw = Array.isArray(list) ? list : [];
  const servers: IceServer[] = [];
  for (const item of raw) {
    if (typeof item !== "object" || item === null) continue;
    const { urls, username, credential } = item as Record<string, unknown>;
    const urlList = typeof urls === "string" ? [urls] : urls;
    if (
      !Array.isArray(urlList) || urlList.length === 0 ||
      !urlList.every((url) => typeof url === "string")
    ) continue;
    const server: IceServer = { urls: urlList as string[] };
    if (typeof username === "string") server.username = username;
    if (typeof credential === "string") server.credential = credential;
    servers.push(server);
  }
  return servers.length > 0 ? servers : null;
}
