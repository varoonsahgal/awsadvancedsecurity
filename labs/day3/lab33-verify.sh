#!/usr/bin/env bash
# Lab 3.3 verifier - checks the Citadel's walls from the attacker's AND the defender's side.
# usage: ./lab33-verify.sh <vault-bucket-name>
set -uo pipefail
B=${1:?usage: $0 <vault-bucket-name>}
pass=0; fail=0
ok()  { echo -e "  \033[92m[HELD]\033[0m $1"; pass=$((pass+1)); }
bad() { echo -e "  \033[91m[BREACH]\033[0m $1"; fail=$((fail+1)); }

echo "== node metadata options =="
for id in $(aws ec2 describe-instances --filters Name=tag:eks:cluster-name,Values=citadel Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId' --output text); do
  read -r tok hop <<<"$(aws ec2 describe-instances --instance-ids "$id" --query 'Reservations[0].Instances[0].MetadataOptions.[HttpTokens,HttpPutResponseHopLimit]' --output text)"
  [ "$tok" = required ] && [ "$hop" = 1 ] && ok "$id IMDSv2 required, hop limit 1" || bad "$id tokens=$tok hop=$hop (want required/1)"
done

echo "== node role =="
ROLE=$(aws eks describe-nodegroup --cluster-name citadel --nodegroup-name citadel-ng --query 'nodegroup.nodeRole' --output text | awk -F/ '{print $NF}')
aws iam list-attached-role-policies --role-name "$ROLE" --query 'AttachedPolicies[].PolicyName' --output text | grep -q AmazonS3ReadOnlyAccess \
  && bad "node role still has AmazonS3ReadOnlyAccess" || ok "node role no longer grants S3"

echo "== attacker's view (namespace kraken) =="
kubectl exec -n kraken kraken-shell -- aws sts get-caller-identity >/dev/null 2>&1 && bad "kraken-shell can obtain AWS credentials" || ok "kraken-shell has no AWS credentials"
c=$(kubectl exec -n kraken kraken-probe -- curl -s -m 3 -o /dev/null -w '%{http_code}' -X PUT -H 'X-aws-ec2-metadata-token-ttl-seconds: 10' http://169.254.169.254/latest/api/token 2>/dev/null); c=${c:-000}
[ "$c" = 000 ] && ok "IMDS unreachable from pod" || bad "IMDS answered pod with HTTP $c"
c=$(kubectl exec -n kraken kraken-probe -- curl -s -m 4 -o /dev/null -w '%{http_code}' https://aws.amazon.com 2>/dev/null); c=${c:-000}
[ "$c" = 000 ] && ok "internet egress blocked" || bad "internet egress open (HTTP $c)"
c=$(kubectl exec -n kraken kraken-probe -- curl -s -m 3 -o /dev/null -w '%{http_code}' http://vault-web.nimbus.svc.cluster.local 2>/dev/null); c=${c:-000}
[ "$c" = 000 ] && ok "cannot reach nimbus/vault-web" || bad "lateral movement to nimbus/vault-web (HTTP $c)"

echo "== defender's view (namespace nimbus) =="
id=$(kubectl exec -n nimbus deploy/vault-app -- aws sts get-caller-identity --query Arn --output text 2>/dev/null)
[[ "$id" == *assumed-role/sky-vault-reader/* ]] && ok "vault-app runs as $id (Pod Identity)" || bad "vault-app identity is '$id' (want sky-vault-reader via Pod Identity)"
kubectl exec -n nimbus deploy/vault-app -- aws s3 cp "s3://$B/manifest.txt" - >/dev/null 2>&1 && ok "vault-app can still read its vault" || bad "vault-app lost access to its vault (over-tightened?)"

echo; echo "  held=$pass breached=$fail"
if [ "$fail" -eq 0 ] && [ "$pass" -ge 8 ]; then
  echo "  Owlsley: The Citadel holds. >> $(echo 'fWRsb2hfc2xsYXdfbGVkYXRpY3tZS1MK' | base64 -d | rev)"
else
  echo "  Kraken: a crack in the wall is all I need. Fix the BREACH lines and re-run."
fi
