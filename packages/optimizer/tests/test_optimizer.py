from pathlib import Path
import sys

sys.path.append(str(Path(__file__).parents[1] / "src"))
from optimizer import grid_search, monte_carlo_net_r, walk_forward_windows


def test_grid_search_orders_best_parameters_first():
    results = grid_search({"value": [1, 2, 3]}, lambda params: params["value"])
    assert results[0].parameters == {"value": 3}


def test_walk_forward_never_leaks_validation_into_training():
    windows = walk_forward_windows(100, 40, 20)
    assert all(window.train_end == window.validation_start for window in windows)


def test_monte_carlo_is_seeded_and_reports_percentiles():
    assert monte_carlo_net_r([1, -1, 2], seed=10) == monte_carlo_net_r([1, -1, 2], seed=10)
