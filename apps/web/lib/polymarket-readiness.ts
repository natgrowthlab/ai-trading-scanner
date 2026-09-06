export type Btc5mReadinessInput = {
  marketActive: boolean;
  secondsRemaining: number;
  btcMoveUsd: number;
  selectedSidePrice: number;
};

export type ReadinessCheck = {
  label: string;
  passed: boolean;
  detail: string;
};

export type Btc5mReadiness = {
  decision: "READY_FOR_REVIEW" | "NOT_READY";
  checks: ReadinessCheck[];
  disclaimer: string;
};

/**
 * Mirrors the public, non-execution reference thresholds from the isolated
 * 5min-btc-polymarket module. This function deliberately returns a review
 * decision only: it does not create a position, size a stake, or call an API.
 */
export function evaluateBtc5mReadiness(input: Btc5mReadinessInput): Btc5mReadiness {
  const checks: ReadinessCheck[] = [
    {
      label: "Market state",
      passed: input.marketActive,
      detail: input.marketActive ? "The selected 5-minute market is active." : "The selected market is inactive or already closed.",
    },
    {
      label: "Entry window",
      passed: input.secondsRemaining >= 60 && input.secondsRemaining <= 150,
      detail: `${input.secondsRemaining}s remaining; the reference window is 60–150 seconds before close.`,
    },
    {
      label: "BTC impulse",
      passed: Math.abs(input.btcMoveUsd) >= 70,
      detail: `$${Math.abs(input.btcMoveUsd).toFixed(2)} move; the reference threshold is at least $70 in the active interval.`,
    },
    {
      label: "Directional skew",
      passed: input.selectedSidePrice >= 0.7,
      detail: `${(input.selectedSidePrice * 100).toFixed(1)}% selected-side price; the reference threshold is 70% or higher.`,
    },
  ];

  return {
    decision: checks.every((check) => check.passed) ? "READY_FOR_REVIEW" : "NOT_READY",
    checks,
    disclaimer: "This is a rule checklist for independent review, not a trade instruction or execution system.",
  };
}
