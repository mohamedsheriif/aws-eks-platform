#!/usr/bin/env bash
#
# Creates the S3 bucket that holds Terraform state for one environment.
# Terraform can't create the bucket it stores its own state in, so this runs once,
# before the first `terragrunt apply`. Safe to re-run: every step is idempotent.
#
# Usage:   ./scripts/bootstrap.sh <env>
# Example: ./scripts/bootstrap.sh dev
#
# Reads project, region and account_id from live/<env>/env.hcl. The bucket name and
# AWS profile below follow the same pattern as state_bucket and aws_profile there.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <env>   (e.g. $0 dev)" >&2
  exit 1
fi

ENV="$1"
ENV_FILE="$(dirname "$0")/../live/${ENV}/env.hcl"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found" >&2
  exit 1
fi

# Reads a quoted value such as `region = "us-east-1"` from env.hcl.
read_env() {
  sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/p" "$ENV_FILE" | head -n 1
}

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------
PROJECT="$(read_env project)"
REGION="$(read_env region)"
ACCOUNT_ID="$(read_env account_id)"

BUCKET="${PROJECT}-${ENV}-tfstate-${ACCOUNT_ID}"
PROFILE="${AWS_PROFILE:-${PROJECT}-${ENV}}"

# Old state versions are kept this long, so a bad apply can be rolled back.
NONCURRENT_VERSION_DAYS=90

aws_cli() {
  aws --profile "$PROFILE" --region "$REGION" "$@"
}

echo "Environment : $ENV"
echo "Account     : $ACCOUNT_ID"
echo "Region      : $REGION"
echo "Profile     : $PROFILE"
echo "Bucket      : $BUCKET"
echo

# ---------------------------------------------------------------------------
# 1. Make sure the profile points at the right account
# ---------------------------------------------------------------------------
CALLER_ACCOUNT="$(aws_cli sts get-caller-identity --query Account --output text)"
if [[ "$CALLER_ACCOUNT" != "$ACCOUNT_ID" ]]; then
  echo "Error: profile $PROFILE is account $CALLER_ACCOUNT, but env.hcl expects $ACCOUNT_ID" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Create the bucket
# ---------------------------------------------------------------------------
if aws_cli s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "==> Bucket already exists"
else
  echo "==> Creating bucket"
  if [[ "$REGION" == "us-east-1" ]]; then
    # us-east-1 is the default location and rejects an explicit LocationConstraint.
    aws_cli s3api create-bucket --bucket "$BUCKET"
  else
    aws_cli s3api create-bucket --bucket "$BUCKET" \
      --create-bucket-configuration "LocationConstraint=$REGION"
  fi
  aws_cli s3api wait bucket-exists --bucket "$BUCKET"
fi

# ---------------------------------------------------------------------------
# 3. Block all public access
# ---------------------------------------------------------------------------
echo "==> Blocking public access"
aws_cli s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# ---------------------------------------------------------------------------
# 4. Keep every version of the state
# ---------------------------------------------------------------------------
echo "==> Enabling versioning"
aws_cli s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

# ---------------------------------------------------------------------------
# 5. Encrypt at rest
# ---------------------------------------------------------------------------
echo "==> Enabling default encryption"
aws_cli s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{ "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" } }]
  }'

# ---------------------------------------------------------------------------
# 6. Reject requests that don't use TLS
# ---------------------------------------------------------------------------
echo "==> Applying TLS-only bucket policy"
aws_cli s3api put-bucket-policy --bucket "$BUCKET" --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Sid\": \"DenyInsecureTransport\",
    \"Effect\": \"Deny\",
    \"Principal\": \"*\",
    \"Action\": \"s3:*\",
    \"Resource\": [\"arn:aws:s3:::${BUCKET}\", \"arn:aws:s3:::${BUCKET}/*\"],
    \"Condition\": { \"Bool\": { \"aws:SecureTransport\": \"false\" } }
  }]
}"

# ---------------------------------------------------------------------------
# 7. Expire old state versions and stale uploads
# ---------------------------------------------------------------------------
echo "==> Applying lifecycle rules"
aws_cli s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" \
  --lifecycle-configuration "{
    \"Rules\": [{
      \"ID\": \"state-housekeeping\",
      \"Status\": \"Enabled\",
      \"Filter\": {},
      \"NoncurrentVersionExpiration\": { \"NoncurrentDays\": ${NONCURRENT_VERSION_DAYS} },
      \"AbortIncompleteMultipartUpload\": { \"DaysAfterInitiation\": 7 }
    }]
  }"

# ---------------------------------------------------------------------------
# 8. Tag it like everything else
# ---------------------------------------------------------------------------
echo "==> Tagging"
aws_cli s3api put-bucket-tagging --bucket "$BUCKET" \
  --tagging "TagSet=[{Key=Project,Value=${PROJECT}},{Key=Environment,Value=${ENV}},{Key=ManagedBy,Value=bootstrap}]"

echo
echo "Done. State bucket $BUCKET is ready."
echo "Terragrunt locks state with a lock file in the same bucket (use_lockfile), so no DynamoDB table is needed."
