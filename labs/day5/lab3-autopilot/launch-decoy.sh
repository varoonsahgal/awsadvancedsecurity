#!/usr/bin/env bash
# Lab 5.3 stretch — launch another decoy into the lab subnet so you can re-run the playbook
# after an approved termination.  Prints the new instance id.
set -euo pipefail
STACK=skyfortress-d5-autopilot
OLD=$(aws cloudformation describe-stacks --stack-name $STACK --query "Stacks[0].Outputs[?OutputKey=='DecoyInstanceId'].OutputValue" --output text)
SUBNET=$(aws ec2 describe-instances --instance-ids "$OLD" --query 'Reservations[0].Instances[0].SubnetId' --output text)
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro --subnet-id "$SUBNET" \
  --metadata-options HttpTokens=required \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=nimbus-cargo-worker-14},{Key=lab,Value=skyfortress-d5}]' \
  --query 'Instances[0].InstanceId' --output text
