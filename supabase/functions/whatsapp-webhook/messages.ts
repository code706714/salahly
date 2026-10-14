// Reads the sign-in messages out of a WhatsApp webhook call.

/** A person's message that carries a sign-in code. */
export interface LoginMessage {
  /** The sender's number in E.164 form, e.g. +201002345678. */
  phone: string;
  code: string;
}

const codePattern = /(?<![A-Z0-9])[A-HJ-NP-Z2-9]{8}(?![A-Z0-9])/;

/** The sign-in code in [text], or null when it carries none. */
export function findCode(text: string): string | null {
  return text.toUpperCase().match(codePattern)?.[0] ?? null;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function asList(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

/** Every text message in [payload] that carries a code, with its sender. */
export function extractLoginMessages(payload: unknown): LoginMessage[] {
  const found: LoginMessage[] = [];
  for (const entry of asList(asRecord(payload)?.entry)) {
    for (const change of asList(asRecord(entry)?.changes)) {
      const value = asRecord(asRecord(change)?.value);
      for (const raw of asList(value?.messages)) {
        const message = asRecord(raw);
        if (message?.type !== "text") continue;
        const from = message.from;
        const text = asRecord(message.text)?.body;
        if (typeof from !== "string" || typeof text !== "string") continue;
        const code = findCode(text);
        if (code === null || !/^[0-9]{8,15}$/.test(from)) continue;
        found.push({ phone: `+${from}`, code });
      }
    }
  }
  return found;
}
