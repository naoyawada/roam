// Shared APNs JWT signing and push delivery

const APNS_HOST_PROD = "https://api.push.apple.com";
const APNS_HOST_SANDBOX = "https://api.sandbox.push.apple.com";

interface APNsConfig {
  keyBase64: string;
  keyId: string;
  teamId: string;
  bundleId: string;
  sandbox?: boolean;
}

/** Import a PEM-encoded P8 (ECDSA P-256) key for signing. */
async function importP8Key(pemBase64: string): Promise<CryptoKey> {
  const pem = atob(pemBase64);
  // Strip PEM headers
  const stripped = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(stripped), (c) => c.charCodeAt(0));

  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
}

/** Base64url encode (no padding). */
function b64url(input: Uint8Array | string): string {
  const str =
    typeof input === "string"
      ? btoa(input)
      : btoa(String.fromCharCode(...input));
  return str.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Create a signed JWT for APNs. Valid for 1 hour. */
async function createAPNsJWT(config: APNsConfig): Promise<string> {
  const key = await importP8Key(config.keyBase64);

  const header = b64url(JSON.stringify({ alg: "ES256", kid: config.keyId }));
  const now = Math.floor(Date.now() / 1000);
  const claims = b64url(JSON.stringify({ iss: config.teamId, iat: now }));
  const signingInput = `${header}.${claims}`;

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput)
  );

  // Web Crypto returns raw r||s (IEEE P1363) — use directly
  return `${signingInput}.${b64url(new Uint8Array(signature))}`;
}

export interface PushResult {
  deviceId: string;
  status: number;
  apnsId?: string;
  reason?: string;
}

/** Send a silent push notification to a single device. */
export async function sendSilentPush(
  token: string,
  deviceId: string,
  config: APNsConfig,
  extraPayload?: Record<string, unknown>
): Promise<PushResult> {
  const jwt = await createAPNsJWT(config);
  const host = config.sandbox ? APNS_HOST_SANDBOX : APNS_HOST_PROD;

  const payload = JSON.stringify({
    aps: { "content-available": 1 },
    ...extraPayload,
  });

  const response = await fetch(`${host}/3/device/${token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": config.bundleId,
      "apns-push-type": "background",
      "apns-priority": "5",
    },
    body: payload,
  });

  const result: PushResult = {
    deviceId,
    status: response.status,
  };

  const apnsId = response.headers.get("apns-id");
  if (apnsId) result.apnsId = apnsId;

  if (!response.ok) {
    try {
      const body = await response.json();
      result.reason = body.reason;
    } catch {
      result.reason = await response.text();
    }
  }

  return result;
}

/** Load APNs config from environment. */
export function loadAPNsConfig(): APNsConfig {
  const keyBase64 = Deno.env.get("APNS_KEY_BASE64");
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const bundleId = Deno.env.get("APNS_BUNDLE_ID");

  if (!keyBase64 || !keyId || !teamId || !bundleId) {
    throw new Error("Missing APNs environment variables");
  }

  return { keyBase64, keyId, teamId, bundleId, sandbox: true };
}
