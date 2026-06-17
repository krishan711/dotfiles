#!/bin/bash
set -euo pipefail

KEY_FILE=~/.ssh/aws-tokenpage-yieldseeker.pub
AWS_PROFILE=tokenpage-yieldseeker
AWS_REGION=eu-west-1
OS_USER=ec2-user

usage() {
  echo "Usage: $0 <ssh-host>"
  echo ""
  echo "  Injects your public key via EC2 Instance Connect and adds it permanently"
  echo "  to authorized_keys on the given host."
  echo ""
  echo "  ssh-host: an SSH config alias (e.g. ys-appbox, ys-vpnbox)"
  exit 1
}

[ $# -lt 1 ] && usage

SSH_HOST=$1

HOST_IP=$(ssh -G "$SSH_HOST" | awk '/^hostname / {print $2}')
if [ -z "$HOST_IP" ]; then
  echo "Error: could not resolve hostname for '$SSH_HOST' from SSH config"
  exit 1
fi

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=ip-address,Values=$HOST_IP" \
  --profile "$AWS_PROFILE" --region "$AWS_REGION" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  echo "Error: no EC2 instance found with IP $HOST_IP"
  exit 1
fi

echo "Found $INSTANCE_ID for $SSH_HOST ($HOST_IP)"

echo "Injecting public key via EC2 Instance Connect..."
aws ec2-instance-connect send-ssh-public-key \
  --instance-id "$INSTANCE_ID" \
  --instance-os-user "$OS_USER" \
  --ssh-public-key "file://$KEY_FILE" \
  --profile "$AWS_PROFILE" --region "$AWS_REGION"

echo "Adding key permanently to authorized_keys..."
ssh "$SSH_HOST" "cat >> ~/.ssh/authorized_keys" < "$KEY_FILE"

echo "Done."
