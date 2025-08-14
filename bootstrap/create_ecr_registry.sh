#!/usr/bin/env bash
set -euo pipefail

# Usage: ./create_ecr_registry.sh <repo-name> [region]
# Example: ./create_ecr_registry.sh myapp us-west-2

REPO="${1:?Repository name required}"
REGION="${2:-us-west-2}"

echo "=== Checking for ECR repository '$REPO' in $REGION ==="

# Create repo if it doesn't exist
if aws ecr describe-repositories --repository-names "$REPO" --region "$REGION" >/dev/null 2>&1; then
  echo "Repository '$REPO' already exists."
else
  echo "Creating repository '$REPO'..."
  aws ecr create-repository \
    --repository-name "$REPO" \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 \
    --region "$REGION" \
    >/dev/null
  echo "Repository '$REPO' created."
fi

# Get the repo URI
REPO_URI=$(aws ecr describe-repositories \
  --repository-names "$REPO" \
  --region "$REGION" \
  --query 'repositories[0].repositoryUri' \
  --output text)

echo "Repository URI: $REPO_URI"

# Apply lifecycle policy (optional cleanup rules)
echo "Applying lifecycle policy..."
cat >/tmp/ecr-lifecycle.json <<'JSON'
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged after 7 days",
      "selection": { "tagStatus": "untagged", "countType": "sinceImagePushed", "countUnit": "days", "countNumber": 7 },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 2,
      "description": "Keep last 20 tagged images",
      "selection": { "tagStatus": "tagged", "tagPrefixList": [""], "countType": "imageCountMoreThan", "countNumber": 20 },
      "action": { "type": "expire" }
    }
  ]
}
JSON

aws ecr put-lifecycle-policy \
  --repository-name "$REPO" \
  --lifecycle-policy-text file:///tmp/ecr-lifecycle.json \
  --region "$REGION" \
  >/dev/null

rm -f /tmp/ecr-lifecycle.json
echo "Lifecycle policy applied."

# Docker login
echo "Logging in to ECR..."
aws ecr get-login-password --region "$REGION" |
  docker login --username AWS --password-stdin "$(cut -d/ -f1 <<<"$REPO_URI")"

echo "=== ECR setup complete ==="
echo "Push example:"
echo "  docker build -t $REPO:latest ."
echo "  docker tag $REPO:latest $REPO_URI:latest"
echo "  docker push $REPO_URI:latest"
