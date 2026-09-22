# Deploy the live Binance Futures dashboard to Vercel

The Next.js application is ready to deploy from `apps/web`. Its `/binance` page
proxies public Binance USDT-M Futures market data through a same-origin Route Handler. No
Binance credential is needed for that page and no order endpoint is included.

## Vercel project settings

1. Import `natgrowthlab/ai-trading-scanner` in Vercel.
2. Set **Root Directory** to `apps/web`.
3. Keep the detected Next.js build command (`npm run build`) and install command
   (`npm install`).
4. Deploy. Visit `/binance` on the assigned domain.

The handler caches public Binance responses for five seconds and serves a
same-origin `/api/v1/binance/market` route, avoiding browser CORS exposure.
It attempts Binance Futures global, demo, and Testnet public endpoints in sequence because
availability can differ by the serverless region. The API returns `marketDataMode`
as `LIVE` or `TESTNET`; the interface labels a Testnet fallback and does not call it
live market data. Set the optional server-only
`BINANCE_PUBLIC_API_BASE_URL` in Vercel only if a specific compliant endpoint is
required for your deployment.

## Secrets and real execution

Do **not** add Binance credentials as `NEXT_PUBLIC_*` variables; that prefix makes
values available to the browser. This deployment intentionally has no order API and
will not trade. If a later Testnet execution service is added, configure its keys as
server-only, sensitive Vercel environment variables and use keys with withdrawals
disabled. Deploy environment-variable changes again before expecting them to apply.

## Testnet credential verification

To verify a Binance Futures Testnet key without exposing account details or placing
an order, add these **sensitive, Production** variables in Vercel:

```text
BINANCE_FUTURES_BASE_URL=https://demo-fapi.binance.com
BINANCE_FUTURES_API_KEY=your_testnet_key
BINANCE_FUTURES_API_SECRET=your_testnet_secret
```

The dashboard calls a signed Testnet account request server-side and reports only
whether authentication succeeded. It never returns the key, secret, balance,
positions, or an order endpoint.

The dashboard uses the Binance USDT-M Futures market endpoints for ticker, order-book and
kline data. Their public endpoint has request-weight limits, so do not shorten the
five-second refresh interval without implementing a rate-limit budget.
