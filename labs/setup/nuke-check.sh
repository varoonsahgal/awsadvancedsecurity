#!/usr/bin/env bash
# Lists the EXPENSIVE lab resources still running across your sandbox profiles. Read-only.
# Usage: ./nuke-check.sh [profile ...]   (default: management, sky-dev, sky-prod)
set -uo pipefail
PROFILES=("$@"); [[ ${#PROFILES[@]} -eq 0 ]] && PROFILES=(default sky-dev sky-prod)
R="${AWS_REGION:-us-east-1}"
for p in "${PROFILES[@]}"; do
  P=(--region "$R"); [[ "$p" != "default" ]] && P+=(--profile "$p")
  echo "━━ $p ━━"
  printf '  Network Firewalls: '; aws network-firewall list-firewalls "${P[@]}" --query 'length(Firewalls)' --output text 2>/dev/null || echo "?"
  printf '  EKS clusters:      '; aws eks list-clusters "${P[@]}" --query 'length(clusters)' --output text 2>/dev/null || echo "?"
  printf '  NAT gateways:      '; aws ec2 describe-nat-gateways "${P[@]}" --filter Name=state,Values=available --query 'length(NatGateways)' --output text 2>/dev/null || echo "?"
  printf '  Running EC2:       '; aws ec2 describe-instances "${P[@]}" --filters Name=instance-state-name,Values=running --query 'length(Reservations[].Instances[])' --output text 2>/dev/null || echo "?"
  printf '  Load balancers:    '; aws elbv2 describe-load-balancers "${P[@]}" --query 'length(LoadBalancers)' --output text 2>/dev/null || echo "?"
  printf '  Interface VPCEs:   '; aws ec2 describe-vpc-endpoints "${P[@]}" --filters Name=vpc-endpoint-type,Values=Interface --query 'length(VpcEndpoints)' --output text 2>/dev/null || echo "?"
  printf '  CFN stacks (sky*): '; aws cloudformation list-stacks "${P[@]}" --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "length(StackSummaries[?starts_with(StackName,'sky')])" --output text 2>/dev/null || echo "?"
done
echo; echo "Anything non-zero above costs money by the hour. Run the lab's cleanup block."
