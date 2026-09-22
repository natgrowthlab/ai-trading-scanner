import { createHmac } from "node:crypto";

const TESTNET_BASE_URL = "https://demo-fapi.binance.com";
const TESTNET_FALLBACK_URL = "https://testnet.binancefuture.com";

export type TestnetConnectionStatus = {
  mode: "TESTNET";
  configured: boolean;
  authenticated: boolean;
  checkedAt: string;
  message: string;
};

function credentials() {
  const apiKey = process.env.BINANCE_FUTURES_API_KEY;
  const apiSecret = process.env.BINANCE_FUTURES_API_SECRET;
  const baseUrl = (process.env.BINANCE_FUTURES_BASE_URL ?? TESTNET_BASE_URL).trim().replace(/\/$/, "");
  if (![TESTNET_BASE_URL, TESTNET_FALLBACK_URL].includes(baseUrl)) throw new Error("Only Binance Futures Testnet is allowed");
  return { apiKey, apiSecret, baseUrl };
}

/**
 * Verifies server-only Testnet credentials with a signed USER_DATA request.
 * This module deliberately has no function that creates, cancels, or changes an order.
 */
export async function verifyTestnetCredentials(): Promise<TestnetConnectionStatus> {
  const checkedAt = new Date().toISOString();
  let config: ReturnType<typeof credentials>;
  try {
    config = credentials();
  } catch {
    return { mode: "TESTNET", configured: false, authenticated: false, checkedAt, message: "Testnet base URL is not permitted." };
  }
  if (!config.apiKey || !config.apiSecret) {
    return { mode: "TESTNET", configured: false, authenticated: false, checkedAt, message: "Add the Testnet API key and secret in server environment variables." };
  }

  const endpoints = [config.baseUrl, ...[TESTNET_BASE_URL, TESTNET_FALLBACK_URL].filter((endpoint) => endpoint !== config.baseUrl)];
  let lastFailure: TestnetConnectionStatus | null = null;
  for (const endpoint of endpoints) {
    const result = await verifyAtEndpoint(endpoint, config.apiKey, config.apiSecret, checkedAt);
    if (result.authenticated) return result;
    lastFailure = result;
  }
  return lastFailure ?? { mode: "TESTNET", configured: true, authenticated: false, checkedAt, message: "Unable to reach Binance Futures Testnet." };
}

async function verifyAtEndpoint(baseUrl: string, apiKey: string, apiSecret: string, checkedAt: string): Promise<TestnetConnectionStatus> {
  try {
    const timeResponse = await fetch(`${baseUrl}/fapi/v1/time`, { cache: "no-store", signal: AbortSignal.timeout(8_000) });
    if (!timeResponse.ok) return { mode: "TESTNET", configured: true, authenticated: false, checkedAt, message: "Binance Futures Testnet time service is unavailable." };
    const time = await timeResponse.json() as { serverTime?: unknown };
    if (typeof time.serverTime !== "number") return { mode: "TESTNET", configured: true, authenticated: false, checkedAt, message: "Binance Futures Testnet returned an invalid time response." };
    const parameters = new URLSearchParams({ timestamp: time.serverTime.toString(), recvWindow: "5000" });
    const signature = createHmac("sha256", apiSecret).update(parameters.toString()).digest("hex");
    const response = await fetch(`${baseUrl}/fapi/v2/account?${parameters}&signature=${signature}`, {
      headers: { "X-MBX-APIKEY": apiKey },
      cache: "no-store",
      signal: AbortSignal.timeout(8_000),
    });
    if (!response.ok) {
      const error = await response.json().catch(() => ({})) as { code?: unknown };
      const code = typeof error.code === "number" ? error.code : null;
      const message = code === -2015 || code === -2014
        ? "API Key is invalid for Futures Testnet, restricted by IP, or missing Futures permission."
        : code === -1022
          ? "The API Secret does not match this Testnet API Key."
          : code === -1021
            ? "Timestamp was rejected despite Testnet time synchronization. Retry shortly."
            : `Binance rejected the Testnet request${code !== null ? ` (code ${code})` : ""}.`;
      return { mode: "TESTNET", configured: true, authenticated: false, checkedAt, message };
    }
    return { mode: "TESTNET", configured: true, authenticated: true, checkedAt, message: "Binance Futures Testnet connection verified." };
  } catch {
    return { mode: "TESTNET", configured: true, authenticated: false, checkedAt, message: "Unable to reach Binance Futures Testnet." };
  }
}
