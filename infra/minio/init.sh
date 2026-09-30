#!/usr/bin/env bash
# =====================================================================
# init.sh — Initialisation MinIO via conteneur Python éphémère
# Crée les buckets : ycc-documents, ycc-kyc, ycc-pdf
# Note : mc n'est plus distribué publiquement
# =====================================================================
set -euo pipefail

NETWORK="${YCC_NETWORK:-ycc-network}"
MINIO_HOST="${MINIO_HOST:-minio-ycc:9000}"
MINIO_USER="${MINIO_USER:-ycc-admin}"
MINIO_PASSWORD="${MINIO_PASSWORD:-ycc-admin-password}"

echo "═══════════════════════════════════════════════════════"
echo "  INIT MINIO"
echo "═══════════════════════════════════════════════════════"

docker run --rm \
    --network "$NETWORK" \
    -e MINIO_ENDPOINT="http://$MINIO_HOST" \
    -e MINIO_USER="$MINIO_USER" \
    -e MINIO_PASSWORD="$MINIO_PASSWORD" \
    python:3.11-alpine sh -c '
        pip install --quiet boto3 2>/dev/null || pip3 install --quiet boto3 &&
        python << "PYEOF"
import os
import boto3
from botocore.exceptions import ClientError

s3 = boto3.client(
    "s3",
    endpoint_url=os.environ["MINIO_ENDPOINT"],
    aws_access_key_id=os.environ["MINIO_USER"],
    aws_secret_access_key=os.environ["MINIO_PASSWORD"],
    region_name="us-east-1",
)

for bucket in ["ycc-documents", "ycc-kyc", "ycc-pdf"]:
    try:
        s3.create_bucket(Bucket=bucket)
        print("  OK -", bucket)
    except ClientError as e:
        if e.response["Error"]["Code"] == "BucketAlreadyOwnedByYou":
            print("  deja present -", bucket)

print()
print("═══════════════════════════════════════════════════════")
print("  MINIO INITIALISE")
print("═══════════════════════════════════════════════════════")
PYEOF
    '
