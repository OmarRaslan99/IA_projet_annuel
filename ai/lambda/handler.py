"""
handler.py — Lambda entrypoint pour l'inférence AI

Payload attendu (body JSON de l'API Gateway) :
  { "home": "France", "away": "Germany", "tournament": "FIFA World Cup" }

Réponse :
  {
    "outcome": { "home": 67.2, "draw": 12.3, "away": 20.5 },
    "score":   { "home": 2, "away": 1 }
  }

Les modèles sont chargés depuis S3 au premier appel puis mis en cache
en mémoire (durée de vie du conteneur Lambda).
"""

from __future__ import annotations

import json
import logging
import os
import pickle
import tempfile
from pathlib import Path
from typing import Any

import boto3
import numpy as np
import pandas as pd

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ── Env vars (injectées par Terraform) ────────────────────────────────────────
MODELS_BUCKET = os.environ["MODELS_BUCKET"]
OUTCOME_MODEL_KEY = os.environ.get("OUTCOME_MODEL_KEY", "outcome_model.pkl")
SCORE_HOME_MODEL_KEY = os.environ.get("SCORE_HOME_MODEL_KEY", "score_home_model.pkl")
SCORE_AWAY_MODEL_KEY = os.environ.get("SCORE_AWAY_MODEL_KEY", "score_away_model.pkl")
SILVER_BUCKET = os.environ.get("S3_SILVER_BUCKET", "")
SILVER_KEY = os.environ.get("SILVER_KEY", "matches_features.parquet")
AWS_REGION = os.environ.get("AWS_REGION", "eu-west-3")

# ── Module-level cache (survive entre invocations du même conteneur) ──────────
_models: dict[str, Any] | None = None
_history: pd.DataFrame | None = None

TOURNAMENT_WEIGHTS = {
    "FIFA World Cup": 5, "UEFA Euro": 4, "Copa America": 4,
    "Africa Cup of Nations": 4, "CONCACAF Gold Cup": 3, "Asian Cup": 3,
    "FIFA World Cup qualification": 3, "UEFA Euro qualification": 3, "Friendly": 1,
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


def _download_from_s3(bucket: str, key: str, local_path: str) -> None:
    s3 = boto3.client("s3", region_name=AWS_REGION)
    s3.download_file(bucket, key, local_path)


def _load_models() -> dict[str, Any]:
    global _models
    if _models is not None:
        return _models

    tmp = tempfile.gettempdir()
    bundles = {}
    for name, key in [
        ("outcome", OUTCOME_MODEL_KEY),
        ("score_home", SCORE_HOME_MODEL_KEY),
        ("score_away", SCORE_AWAY_MODEL_KEY),
    ]:
        local = os.path.join(tmp, key)
        if not os.path.exists(local):
            logger.info(f"Downloading {key} from s3://{MODELS_BUCKET}")
            _download_from_s3(MODELS_BUCKET, key, local)
        with open(local, "rb") as f:
            bundles[name] = pickle.load(f)["model"]

    _models = bundles
    return _models


def _load_history() -> pd.DataFrame:
    global _history
    if _history is not None:
        return _history

    if not SILVER_BUCKET:
        raise ValueError("S3_SILVER_BUCKET env var not set")

    local = os.path.join(tempfile.gettempdir(), "matches_features.parquet")
    if not os.path.exists(local):
        logger.info(f"Downloading silver data from s3://{SILVER_BUCKET}/{SILVER_KEY}")
        _download_from_s3(SILVER_BUCKET, SILVER_KEY, local)

    _history = pd.read_parquet(local)
    return _history


def _build_features(home: str, away: str, tournament: str, history: pd.DataFrame) -> pd.DataFrame:
    def last_rank(team: str) -> float:
        rows = history[(history["home_team"] == team) | (history["away_team"] == team)].tail(1)
        if rows.empty:
            return np.nan
        r = rows.iloc[-1]
        return float(r["home_rank"] if r["home_team"] == team else r["away_rank"])

    def rolling(team: str) -> dict:
        played = history[(history["home_team"] == team) | (history["away_team"] == team)].tail(ROLLING_WINDOW)
        if played.empty:
            return {"win_rate": np.nan, "draw_rate": np.nan, "goals_scored_avg": np.nan, "goals_conceded_avg": np.nan}
        wins, draws, gs_list, gc_list = 0, 0, [], []
        for _, r in played.iterrows():
            gs, gc = (r["home_score"], r["away_score"]) if r["home_team"] == team else (r["away_score"], r["home_score"])
            gs_list.append(gs); gc_list.append(gc)
            if gs > gc: wins += 1
            elif gs == gc: draws += 1
        n = len(played)
        return {"win_rate": wins/n, "draw_rate": draws/n, "goals_scored_avg": float(np.mean(gs_list)), "goals_conceded_avg": float(np.mean(gc_list))}

    hs = rolling(home); aws = rolling(away)
    hr = last_rank(home); ar = last_rank(away)

    h2h = history[
        ((history["home_team"] == home) & (history["away_team"] == away)) |
        ((history["home_team"] == away) & (history["away_team"] == home))
    ].tail(H2H_WINDOW)
    hw, dh, aw_wins = 0, 0, 0
    for _, r in h2h.iterrows():
        if r["home_score"] > r["away_score"]: winner = r["home_team"]
        elif r["home_score"] < r["away_score"]: winner = r["away_team"]
        else: dh += 1; continue
        if winner == home: hw += 1
        else: aw_wins += 1

    tw = TOURNAMENT_WEIGHTS.get(tournament, DEFAULT_WEIGHT)
    row = {
        "tournament_weight": tw,
        "home_rank": hr, "away_rank": ar,
        "rank_diff": (hr - ar) if not (np.isnan(hr) or np.isnan(ar)) else np.nan,
        "home_win_rate": hs["win_rate"], "home_draw_rate": hs["draw_rate"],
        "home_goals_scored_avg": hs["goals_scored_avg"], "home_goals_conceded_avg": hs["goals_conceded_avg"],
        "away_win_rate": aws["win_rate"], "away_draw_rate": aws["draw_rate"],
        "away_goals_scored_avg": aws["goals_scored_avg"], "away_goals_conceded_avg": aws["goals_conceded_avg"],
        "h2h_home_wins": hw, "h2h_draws": dh, "h2h_away_wins": aw_wins,
    }
    return pd.DataFrame([row])[FEATURES]


def _cors_headers() -> dict:
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "POST,OPTIONS",
    }


def handler(event: dict, context: Any) -> dict:
    # Handle CORS preflight
    if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
        return {"statusCode": 200, "headers": _cors_headers(), "body": ""}

    try:
        body = event.get("body", "{}")
        if isinstance(body, str):
            body = json.loads(body)

        home = body.get("home", "").strip()
        away = body.get("away", "").strip()
        tournament = body.get("tournament", "FIFA World Cup").strip()

        if not home or not away:
            return {
                "statusCode": 400,
                "headers": _cors_headers(),
                "body": json.dumps({"error": "'home' and 'away' fields are required"}),
            }

        models = _load_models()
        history = _load_history()

        X = _build_features(home, away, tournament, history)
        proba = models["outcome"].predict_proba(X)[0]
        home_goals = max(0, round(float(models["score_home"].predict(X)[0])))
        away_goals = max(0, round(float(models["score_away"].predict(X)[0])))

        result = {
            "outcome": {
                "home": round(float(proba[0]) * 100, 1),
                "draw": round(float(proba[1]) * 100, 1),
                "away": round(float(proba[2]) * 100, 1),
            },
            "score": {"home": home_goals, "away": away_goals},
        }

        logger.info(f"Prediction: {home} vs {away} ({tournament}) → {result}")

        return {
            "statusCode": 200,
            "headers": {**_cors_headers(), "Content-Type": "application/json"},
            "body": json.dumps(result),
        }

    except Exception as exc:
        logger.exception("Prediction failed")
        return {
            "statusCode": 500,
            "headers": _cors_headers(),
            "body": json.dumps({"error": "Internal server error"}),
        }
