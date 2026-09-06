import { NextResponse } from "next/server";

export const runtime = "nodejs";

export function GET() {
  const webhookConfigured = Boolean(process.env.TRADINGVIEW_WEBHOOK_SECRET);
  const telegramConfigured = Boolean(process.env.TELEGRAM_BOT_TOKEN && process.env.TELEGRAM_CHAT_ID);
  return NextResponse.json({ status: "ok", dataProvider: "MOCK", tradingViewWebhook: webhookConfigured ? "CONFIGURED" : "NOT_CONFIGURED", telegram: telegramConfigured ? "CONFIGURED" : "NOT_CONFIGURED", signalStorage: "EPHEMERAL_RUNTIME", checkedAt: new Date().toISOString() });
}
