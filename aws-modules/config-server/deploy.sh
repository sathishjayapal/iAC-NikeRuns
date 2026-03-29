#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Checking AWS credentials..."
aws sts get-caller-identity > /dev/null 2>&1 || {
  echo "ERROR: AWS credentials not set. Export AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN from your acloud.guru sandbox."
  exit 1
}

echo "==> Detecting your public IP for SSH access..."
MY_IP=$(curl -s ifconfig.me)
if [ -z "$MY_IP" ]; then
  echo "ERROR: Could not detect public IP. Set allowed_ssh_cidr manually in terraform.tfvars."
  exit 1
fi
echo "    Your IP: $MY_IP"

echo "==> Checking terraform.tfvars..."
if [ ! -f terraform.tfvars ]; then
  echo "ERROR: terraform.tfvars not found. Copy terraform.tfvars.example and fill in your values."
  exit 1
fi

# Inject current IP into tfvars (overwrite any previous value)
if grep -q "allowed_ssh_cidr" terraform.tfvars; then
  sed -i.bak "s|allowed_ssh_cidr.*|allowed_ssh_cidr = \"$MY_IP/32\"|" terraform.tfvars && rm -f terraform.tfvars.bak
else
  echo "allowed_ssh_cidr = \"$MY_IP/32\"" >> terraform.tfvars
fi

echo "==> Running terraform init..."
terraform init -upgrade

echo "==> Running terraform apply..."
terraform apply -auto-approve

echo ""
echo "==> Deployment complete. Waiting 90 seconds for container to start..."
sleep 90

HEALTH_URL=$(terraform output -raw health_url)
SSH_CMD=$(terraform output -raw ssh_command)

echo ""
echo "==> Checking health endpoint..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" || true)

if [ "$HTTP_STATUS" = "200" ]; then
  echo "    SUCCESS — config server is up!"
else
  echo "    WARNING — got HTTP $HTTP_STATUS. Container may still be starting."
  echo "    Re-check manually: curl $HEALTH_URL"
fi

echo ""
echo "===== DEPLOYMENT SUMMARY ====="
echo "Health URL : $HEALTH_URL"
echo "SSH command: $SSH_CMD"
echo "=============================="
