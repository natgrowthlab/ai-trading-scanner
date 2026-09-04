from __future__ import annotations

from dataclasses import dataclass
from itertools import product
from random import Random
from statistics import quantiles
from typing import Callable


@dataclass(frozen=True)
class OptimizationResult:
    parameters: dict[str, float]
    fitness: float


@dataclass(frozen=True)
class WalkForwardWindow:
    train_start: int
    train_end: int
    validation_start: int
    validation_end: int


def grid_search(
    space: dict[str, list[float]], evaluate: Callable[[dict[str, float]], float]
) -> list[OptimizationResult]:
    keys = list(space)
    return sorted(
        [
            OptimizationResult(dict(zip(keys, values)), evaluate(dict(zip(keys, values))))
            for values in product(*(space[key] for key in keys))
        ],
        key=lambda result: result.fitness,
        reverse=True,
    )


def random_search(
    space: dict[str, list[float]],
    evaluate: Callable[[dict[str, float]], float],
    iterations: int,
    seed: int = 0,
) -> list[OptimizationResult]:
    rng = Random(seed)
    keys = list(space)
    results = [
        OptimizationResult({key: rng.choice(space[key]) for key in keys}, 0)
        for _ in range(iterations)
    ]
    return sorted(
        [OptimizationResult(result.parameters, evaluate(result.parameters)) for result in results],
        key=lambda result: result.fitness,
        reverse=True,
    )


def walk_forward_windows(
    total_bars: int, train_bars: int, validation_bars: int
) -> list[WalkForwardWindow]:
    windows = []
    start = 0
    while start + train_bars + validation_bars <= total_bars:
        windows.append(
            WalkForwardWindow(
                start, start + train_bars, start + train_bars, start + train_bars + validation_bars
            )
        )
        start += validation_bars
    return windows


def monte_carlo_net_r(
    trade_returns: list[float], simulations: int = 1000, seed: int = 0
) -> dict[str, float]:
    if not trade_returns:
        return {"p5": 0, "p50": 0, "p95": 0}
    rng = Random(seed)
    outcomes = []
    for _ in range(simulations):
        shuffled = trade_returns[:]
        rng.shuffle(shuffled)
        outcomes.append(sum(shuffled))
    p5, p50, p95 = (
        quantiles(outcomes, n=100, method="inclusive")[4],
        quantiles(outcomes, n=100, method="inclusive")[49],
        quantiles(outcomes, n=100, method="inclusive")[94],
    )
    return {"p5": p5, "p50": p50, "p95": p95}
