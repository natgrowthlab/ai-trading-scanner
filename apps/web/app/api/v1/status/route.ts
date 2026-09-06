import { NextResponse } from "next/server";
import { storageHealth } from "../../../../lib/signal-store";

export const runtime = "nodejs";

export async function GET() {
  const webhookConfigured = Boolean(process.env.TRADINGVIEW_WEBHOOK_SECRET);
  const telegramConfigured = Boolean(process.env.TELEGRAM_BOT_TOKEN && process.env.TELEGRAM_CHAT_ID);
  const storage = await storageHealth();
  return NextResponse.json({ status: "ok", dataProvider: "TRADINGVIEW_WEBHOOKS", tradingViewWebhook: webhookConfigured ? "CONFIGURED" : "NOT_CONFIGURED", telegram: telegramConfigured ? "CONFIGURED" : "NOT_CONFIGURED", signalStorage: storage.storage, signalCount: storage.signalCount, checkedAt: new Date().toISOString() });
}
