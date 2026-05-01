"""
predict.py — Inférence locale et partagée (utilisée aussi par le handler Lambda)

Usage CLI :
  python src/inference/predict.py --home France --away Germany \
      --tournament "FIFA World Cup"
"""

from __future__ import annotations

import argparse
import json
import pickle
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
MODELS_DIR = ROOT / "models"
SILVER_DIR = ROOT / "data" / "silver"

# ---------------------------------------------------------------------------
# Feature helpers
# ---------------------------------------------------------------------------

TOURNAMENT_WEIGHTS = {
    "FIFA World Cup": 5,
    "UEFA Euro": 4,
    "Copa America": 4,
    "Africa Cup of Nations": 4,
    "CONCACAF Gold Cup": 3,
    "Asian Cup": 3,
    "FIFA World Cup qualification": 3,
    "UEFA Euro qualification": 3,
    "Friendly": 1,
}
DEFAULT_WEIGHT = 2

ROLLING_WINDOW = 10
H2H_WINDOW = 5
FEATURES = [
    "tournament_weight",
    "home_rank", "away_rank", "rank_diff",
    "home_win_rate", "home_draw_rate", "home_goals_scored_avg", "home_goals_conceded_avg",
    "away_win_rate", "away_draw_rate", "away_goals_scored_avg", "away_goals_conceded_avg",
    "h2h_home_wins", "h2h_draws", "h2h_away_wins",
]


def _load_models(models_dir: Path) -> dict[str, Any]:
    with open(models_dir / "outcome_model.pkl", "rb") as f:
        outcome_bundle = pickle.load(f)
    with open(models_dir / "score_home_model.pkl", "rb") as f:
        score_home_bundle = pickle.load(f)
    with open(models_dir / "score_away_model.pkl", "rb") as f:
        score_away_bundle = pickle.load(f)
    return {
        "outcome": outcome_bundle["model"],
        "score_home": score_home_bundle["model"],
        "score_away": score_away_bundle["model"],
    }


def _build_feature_row(
    home: str,
    away: str,
    tournament: str,
    history: pd.DataFrame,
) -> pd.DataFrame:
    """Construit un vecteur de features pour un match à venir."""
    ranking = history[["date", "home_team", "away_team",
                        "home_rank", "away_rank"]].copy()

    # Récupérer le dernier ranking connu pour chaque équipe
    def last_rank(team: str) -> float:
        rows = history[
            (history["home_team"] == team) | (history["away_team"] == team)
        ].tail(1)
        if rows.empty:
            return np.nan
        r = rows.iloc[-1]
        return float(r["home_rank"] if r["home_team"] == team else r["away_rank"])

    home_rank = last_rank(home)
    away_rank = last_rank(away)

    # Rolling stats home
    def rolling(team: str, is_home: bool) -> dict:
        played = history[
            (history["home_team"] == team) | (history["away_team"] == team)
        ].tail(ROLLING_WINDOW)
        if played.empty:
            return {"win_rate": np.nan, "draw_rate": np.nan,
                    "goals_scored_avg": np.nan, "goals_conceded_avg": np.nan}
        wins, draws, gs_list, gc_list = 0, 0, [], []
        for _, r in played.iterrows():
            if r["home_team"] == team:
                gs, gc = r["home_score"], r["away_score"]
            else:
                gs, gc = r["away_score"], r["home_score"]
            gs_list.append(gs)
            gc_list.append(gc)
            if gs > gc:
                wins += 1
            elif gs == gc:
                draws += 1
        n = len(played)
        return {
            "win_rate": wins / n, "draw_rate": draws / n,
            "goals_scored_avg": float(np.mean(gs_list)),
            "goals_conceded_avg": float(np.mean(gc_list)),
        }

    hs = rolling(home, True)
    aws = rolling(away, False)

    # H2H
    h2h = history[
        ((history["home_team"] == home) & (history["away_team"] == away)) |
        ((history["home_team"] == away) & (history["away_team"] == home))
    ].tail(H2H_WINDOW)
    hw, draws_h2h, aw = 0, 0, 0
    for _, r in h2h.iterrows():
        if r["home_score"] > r["away_score"]:
            winner = r["home_team"]
        elif r["home_score"] < r["away_score"]:
            winner = r["away_team"]
        else:
            draws_h2h += 1
            continue
        if winner == home:
            hw += 1
        else:
            aw += 1

    tw = TOURNAMENT_WEIGHTS.get(tournament, DEFAULT_WEIGHT)

    row = {
        "tournament_weight": tw,
        "home_rank": home_rank,
        "away_rank": away_rank,
        "rank_diff": home_rank - away_rank if not (np.isnan(home_rank) or np.isnan(away_rank)) else np.nan,
        "home_win_rate": hs["win_rate"],
        "home_draw_rate": hs["draw_rate"],
        "home_goals_scored_avg": hs["goals_scored_avg"],
        "home_goals_conceded_avg": hs["goals_conceded_avg"],
        "away_win_rate": aws["win_rate"],
        "away_draw_rate": aws["draw_rate"],
        "away_goals_scored_avg": aws["goals_scored_avg"],
        "away_goals_conceded_avg": aws["goals_conceded_avg"],
        "h2h_home_wins": hw,
        "h2h_draws": draws_h2h,
        "h2h_away_wins": aw,
    }
    return pd.DataFrame([row])[FEATURES]


def predict(
    home: str,
    away: str,
    tournament: str = "FIFA World Cup",
    models_dir: Path | None = None,
    history: pd.DataFrame | None = None,
) -> dict:
    """
    Retourne :
    {
      "outcome": {"home": 67.2, "draw": 12.3, "away": 20.5},
      "score":   {"home": 2, "away": 1}
    }
    """
    if models_dir is None:
        models_dir = MODELS_DIR
    if history is None:
        history = pd.read_parquet(SILVER_DIR / "matches_features.parquet")

    models = _load_models(models_dir)
    X = _build_feature_row(home, away, tournament, history)

    proba = models["outcome"].predict_proba(X)[0]
    home_goals = max(0, round(float(models["score_home"].predict(X)[0])))
    away_goals = max(0, round(float(models["score_away"].predict(X)[0])))

    return {
        "outcome": {
            "home": round(float(proba[0]) * 100, 1),
            "draw": round(float(proba[1]) * 100, 1),
            "away": round(float(proba[2]) * 100, 1),
        },
        "score": {
            "home": home_goals,
            "away": away_goals,
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Predict match outcome and score")
    parser.add_argument("--home", required=True, help="Home team name")
    parser.add_argument("--away", required=True, help="Away team name")
    parser.add_argument("--tournament", default="FIFA World Cup",
                        help="Tournament name (default: FIFA World Cup)")
    args = parser.parse_args()

    result = predict(args.home, args.away, args.tournament)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
