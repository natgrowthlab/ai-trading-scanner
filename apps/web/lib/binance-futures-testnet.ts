import { createHmac } from "node:crypto";

const TESTNET_BASE_URL = "https://demo-fapi.binance.com";

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
  const baseUrl = process.env.BINANCE_FUTURES_BASE_URL ?? TESTNET_BASE_URL;
  if (baseUrl !== TESTNET_BASE_URL) throw new Error("Only Binance Futures Testnet is allowed");
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

  const parameters = new URLSearchParams({ timestamp: Date.now().toString(), recvWindow: "5000" });
  const signature = createHmac("sha256", config.apiSecret).update(parameters.toString()).digest("hex");
  try {
    const response = await fetch(`${config.baseUrl}/fapi/v2/account?${parameters}&signature=${signature}`, {
      headers: { "X-MBX-APIKEY": config.apiKey },
      cache: "no-store",
      signal: AbortSignal.timeout(8_000),
    });
    if (!response.ok) {
      return { mode: "TESTNET", configured: true, authenticated: false, checkedAt, message: "Binance rejected the Testnet credentials or request." };
    }
    return { mode: "TESTNET", configured: true, authenticated: true, checkedAt, message: "Binance Futures Testnet connection verified." };
  } catch {
    return { mode: "TESTNET", configured: true, authenticated: false, checkedAt, message: "Unable to reach Binance Futures Testnet." };
  }
}
