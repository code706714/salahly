// The three things a phone asks while signing in with a WhatsApp message:
// start (get a code to send), status (has WhatsApp told us yet?) and complete
// (trade the secret for a one-time password and sign in with it).
//
// The database and the auth admin API come in as [LoginDeps] so the rules
// can be tested without either.

export interface Challenge {
  id: string;
  code: string;
  poll_secret: string;
  expires_at: string;
}

export interface LoginDeps {
  /** The WhatsApp number people write to, digits only; empty when not set. */
  whatsappNumber: string;
  start(): Promise<Challenge>;
  status(id: string, secret: string): Promise<string>;
  /** The number that sent the code, once; null when there is none to give. */
  claim(id: string, secret: string): Promise<string | null>;
  /** Makes sure the number has an account and gives it a fresh password. */
  preparePassword(phone: string): Promise<string>;
}

export interface LoginReply {
  status: number;
  body: Record<string, unknown>;
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const secretPattern = /^[0-9a-f]{64}$/;

function reply(status: number, body: Record<string, unknown>): LoginReply {
  return { status, body };
}

export async function handleLogin(
  input: unknown,
  deps: LoginDeps,
): Promise<LoginReply> {
  const request = typeof input === "object" && input !== null
    ? (input as Record<string, unknown>)
    : {};
  const action = request.action;

  if (action === "start") {
    if (deps.whatsappNumber === "") {
      return reply(503, { error: "unavailable" });
    }
    try {
      const challenge = await deps.start();
      return reply(200, {
        id: challenge.id,
        code: challenge.code,
        pollSecret: challenge.poll_secret,
        expiresAt: challenge.expires_at,
        whatsappNumber: deps.whatsappNumber,
      });
    } catch {
      return reply(503, { error: "busy" });
    }
  }

  if (action !== "status" && action !== "complete") {
    return reply(400, { error: "invalid_request" });
  }
  const id = request.id;
  const secret = request.pollSecret;
  if (
    typeof id !== "string" || !uuidPattern.test(id) ||
    typeof secret !== "string" || !secretPattern.test(secret)
  ) {
    return reply(400, { error: "invalid_request" });
  }

  if (action === "status") {
    return reply(200, { status: await deps.status(id, secret) });
  }

  const phone = await deps.claim(id, secret);
  if (phone === null) {
    return reply(409, { error: "not_ready" });
  }
  return reply(200, { phone, password: await deps.preparePassword(phone) });
}
