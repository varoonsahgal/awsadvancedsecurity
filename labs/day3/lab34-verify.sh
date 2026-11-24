#!/usr/bin/env bash
# Lab 3.4 verifier: the unsigned Kraken image must be REJECTED at admission; the signed one ADMITTED.
# usage: ./lab34-verify.sh <ecr-repo-uri>        e.g. 1234.dkr.ecr.us-east-1.amazonaws.com/nimbus/manifest-api
set -uo pipefail
REPO=${1:?usage: $0 <ecr-repo-uri>}
SIGNED=$(aws ecr describe-images --repository-name "${REPO#*/}" --image-ids imageTag=v1 --query 'imageDetails[0].imageDigest' --output text)
echo "== unsigned kraken image (tag kraken-hotfix) =="
out=$(kubectl run kraken-hotfix -n nimbus --image="$REPO:kraken-hotfix" --restart=Never --dry-run=server -o name 2>&1)
if echo "$out" | grep -qiE "denied|verifyImages|signature|failed to verify"; then rej=1; echo -e "  \033[92m[REJECTED]\033[0m $(echo "$out" | head -c 220)"; else rej=0; echo -e "  \033[91m[ADMITTED]\033[0m $out"; fi
echo "== signed nimbus image (v1 @ $SIGNED) =="
out=$(kubectl run manifest-api -n nimbus --image="$REPO:v1" --restart=Never --dry-run=server -o jsonpath='{.spec.containers[0].image}' 2>&1)
if [[ "$out" == *"@sha256:"* ]]; then adm=1; echo -e "  \033[92m[ADMITTED]\033[0m image mutated to digest: $out"; else adm=0; echo -e "  \033[91m[PROBLEM]\033[0m $out"; fi
echo
if [ $rej = 1 ] && [ $adm = 1 ]; then
  echo "  Owlsley: Provenance enforced at the gate. >> $(echo 'fWxpYXNfc3BpaHNfZGVuZ2lzX3lsbm97WUtTCg==' | base64 -d | rev)"
else
  echo "  Kraken: your gate is a suggestion. (Check kyverno logs: kubectl -n kyverno logs deploy/kyverno-admission-controller)"
fi
