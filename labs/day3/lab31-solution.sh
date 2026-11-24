#!/usr/bin/env bash
# Lab 3.1 reference solution - run from CloudShell AFTER deploying lab31-egress-vpc.yaml as stack "sky-lab31".
# Try the lab by hand first. This script is the "break glass" path for instructors and stragglers.
set -euo pipefail
R=us-east-1; STACK=sky-lab31
out() { aws cloudformation describe-stacks --region $R --stack-name $STACK --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
VPC=$(out VpcId); FWSUB=$(out FirewallSubnetId); PRIV_RT=$(out PrivateRouteTableId); PUB_RT=$(out PublicRouteTableId)

echo "== 1. DNS Firewall =="
DL=$(aws route53resolver create-firewall-domain-list --region $R --name kraken-c2 --creator-request-id "dl-$(date +%s)" --query FirewallDomainList.Id --output text)
aws route53resolver update-firewall-domains --region $R --firewall-domain-list-id "$DL" --operation ADD --domains '*.kraken-c2.example' 'kraken-c2.example' >/dev/null
RG=$(aws route53resolver create-firewall-rule-group --region $R --name sky-dns-guard --creator-request-id "rg-$(date +%s)" --query FirewallRuleGroup.Id --output text)
aws route53resolver create-firewall-rule --region $R --name sinkhole-kraken-c2 --creator-request-id "r-$(date +%s)" \
  --firewall-rule-group-id "$RG" --firewall-domain-list-id "$DL" --priority 100 --action BLOCK \
  --block-response OVERRIDE --block-override-domain sinkhole.skyfortress.lab --block-override-dns-type CNAME --block-override-ttl 60 >/dev/null
MAL=$(aws route53resolver list-firewall-domain-lists --region $R --query "FirewallDomainLists[?Name=='AWSManagedDomainsAggregateThreatList'].Id" --output text)
aws route53resolver create-firewall-rule --region $R --name aws-aggregate-threats --creator-request-id "r2-$(date +%s)" \
  --firewall-rule-group-id "$RG" --firewall-domain-list-id "$MAL" --priority 200 --action BLOCK --block-response NXDOMAIN >/dev/null
aws route53resolver associate-firewall-rule-group --region $R --name sky-dns-guard-assoc --creator-request-id "a-$(date +%s)" \
  --firewall-rule-group-id "$RG" --vpc-id "$VPC" --priority 101 >/dev/null

echo "== 2. Network Firewall rule groups =="
jq -Rs '{RulesSource:{RulesString:.},StatefulRuleOptions:{RuleOrder:"STRICT_ORDER"}}' lab31-egress-guard.rules > /tmp/guard.json
GUARD=$(aws network-firewall create-rule-group --region $R --rule-group-name sky-egress-guard --type STATEFUL --capacity 100 \
  --rule-group file:///tmp/guard.json --query RuleGroupResponse.RuleGroupArn --output text)
ALLOW=$(aws network-firewall create-rule-group --region $R --rule-group-name sky-egress-allowlist --type STATEFUL --capacity 100 \
  --rule-group '{"RulesSource":{"RulesSourceList":{"Targets":[".amazonaws.com",".amazonlinux.com"],"TargetTypes":["TLS_SNI","HTTP_HOST"],"GeneratedRulesType":"ALLOWLIST"}},"StatefulRuleOptions":{"RuleOrder":"STRICT_ORDER"}}' \
  --query RuleGroupResponse.RuleGroupArn --output text)

echo "== 3. Policy + firewall =="
POL=$(aws network-firewall create-firewall-policy --region $R --firewall-policy-name sky-egress-policy --firewall-policy "{
  \"StatelessDefaultActions\":[\"aws:forward_to_sfe\"],\"StatelessFragmentDefaultActions\":[\"aws:forward_to_sfe\"],
  \"StatefulEngineOptions\":{\"RuleOrder\":\"STRICT_ORDER\"},
  \"StatefulDefaultActions\":[\"aws:drop_established\",\"aws:alert_established\"],
  \"StatefulRuleGroupReferences\":[{\"ResourceArn\":\"$GUARD\",\"Priority\":10},{\"ResourceArn\":\"$ALLOW\",\"Priority\":20}]}" \
  --query FirewallPolicyResponse.FirewallPolicyArn --output text)
aws network-firewall create-firewall --region $R --firewall-name sky-egress-fw --firewall-policy-arn "$POL" \
  --vpc-id "$VPC" --subnet-mappings SubnetId="$FWSUB" >/dev/null
echo "waiting for firewall endpoint (3-6 min)..."
until [ "$(aws network-firewall describe-firewall --region $R --firewall-name sky-egress-fw --query FirewallStatus.Status --output text)" = READY ]; do sleep 20; printf .; done; echo
EP=$(aws network-firewall describe-firewall --region $R --firewall-name sky-egress-fw --query 'FirewallStatus.SyncStates.*.Attachment.EndpointId' --output text)
aws network-firewall update-logging-configuration --region $R --firewall-name sky-egress-fw --logging-configuration \
  '{"LogDestinationConfigs":[{"LogType":"ALERT","LogDestinationType":"CloudWatchLogs","LogDestination":{"logGroup":"/skyfortress/nfw/alert"}}]}' >/dev/null

echo "== 4. Routing: private -> FW -> NAT, and symmetric return =="
aws ec2 replace-route --region $R --route-table-id "$PRIV_RT" --destination-cidr-block 0.0.0.0/0 --vpc-endpoint-id "$EP"
aws ec2 create-route  --region $R --route-table-id "$PUB_RT"  --destination-cidr-block 10.66.2.0/24 --vpc-endpoint-id "$EP"
echo "done. endpoint=$EP  now run: implant status via SSM"
