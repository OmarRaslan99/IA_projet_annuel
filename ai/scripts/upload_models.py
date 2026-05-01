"""
upload_models.py — Upload des modèles .pkl entraînés vers S3
"""

import os
from pathlib import Path

import boto3
from dotenv import load_dotenv

load_dotenv()

ROOT = Path(__file__).resolve().parents[2]
MODELS_DIR = ROOT / "models"

MODELS_BUCKET = os.environ["S3_MODELS_BUCKET"]
AWS_REGION = os.getenv("AWS_REGION", "eu-west-3")

MODEL_FILES = [
    "outcome_model.pkl",
    "score_home_model.pkl",
    "score_away_model.pkl",
]


if __name__ == "__main__":
    s3 = boto3.client("s3", region_name=AWS_REGION)

    for filename in MODEL_FILES:
        local_path = MODELS_DIR / filename
        if not local_path.exists():
            print(f"⚠  {filename} not found — run 'make train' first")
            continue
        s3.upload_file(str(local_path), MODELS_BUCKET, filename)
        size_kb = local_path.stat().st_size // 1024
        print(f"✓ Uploaded {filename} ({size_kb} KB) → s3://{MODELS_BUCKET}/{filename}")
