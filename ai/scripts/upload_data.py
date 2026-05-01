"""
upload_data.py — Upload des données bronze et silver vers S3
"""

import os
from pathlib import Path

import boto3
from dotenv import load_dotenv

load_dotenv()

ROOT = Path(__file__).resolve().parents[2]
BRONZE_DIR = ROOT / "data" / "bronze"
SILVER_DIR = ROOT / "data" / "silver"

BRONZE_BUCKET = os.environ["S3_BRONZE_BUCKET"]
SILVER_BUCKET = os.environ["S3_SILVER_BUCKET"]
AWS_REGION = os.getenv("AWS_REGION", "eu-west-3")


def upload_dir(local_dir: Path, bucket: str, prefix: str = "") -> None:
    s3 = boto3.client("s3", region_name=AWS_REGION)
    files = list(local_dir.rglob("*"))
    files = [f for f in files if f.is_file()]
    print(f"  Uploading {len(files)} files to s3://{bucket}/{prefix}")
    for f in files:
        key = prefix + str(f.relative_to(local_dir)).replace("\\", "/")
        s3.upload_file(str(f), bucket, key)
        print(f"    ✓ {key}")


if __name__ == "__main__":
    if BRONZE_DIR.exists():
        upload_dir(BRONZE_DIR, BRONZE_BUCKET, prefix="")
        print(f"✓ Bronze data uploaded to s3://{BRONZE_BUCKET}")
    else:
        print("⚠ Bronze dir not found, run 'make download' first")

    if SILVER_DIR.exists():
        upload_dir(SILVER_DIR, SILVER_BUCKET, prefix="")
        print(f"✓ Silver data uploaded to s3://{SILVER_BUCKET}")
    else:
        print("⚠ Silver dir not found, run 'make prepare' first")
