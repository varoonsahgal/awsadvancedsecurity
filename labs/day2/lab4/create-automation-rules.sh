#!/usr/bin/env bash
# Lab 2.4 · Security Hub automation rules (CSPM / ASFF API) — run in the delegated admin (sky-dev).
#   ./create-automation-rules.sh <prod-account-id> <dev-account-id>
# Rule 1 escalates anything touching restricted data in prod.
# Rule 2 suppresses one accepted-risk control in the sandbox dev account, WITH a note saying why.
set -euo pipefail
PROD="${1:?prod account id}"; DEV="${2:?dev account id}"

aws securityhub create-automation-rule \
  --rule-name "escalate-restricted-data-in-prod" \
  --rule-order 1 \
  --rule-status ENABLED \
  --description "Restricted data + prod = page someone" \
  --criteria "{
      \"AwsAccountId\": [{\"Value\": \"$PROD\", \"Comparison\": \"EQUALS\"}],
      \"ResourceTags\": [{\"Key\": \"data-classification\", \"Value\": \"restricted\", \"Comparison\": \"EQUALS\"}],
      \"SeverityLabel\": [{\"Value\": \"MEDIUM\", \"Comparison\": \"EQUALS\"}, {\"Value\": \"HIGH\", \"Comparison\": \"EQUALS\"}]
    }" \
  --actions '[{
      "Type": "FINDING_FIELDS_UPDATE",
      "FindingFieldsUpdate": {
        "Severity": {"Label": "CRITICAL"},
        "Note": {"Text": "Escalated by skyfortress automation: restricted data in prod", "UpdatedBy": "skyfortress-automation"}
      }}]'

aws securityhub create-automation-rule \
  --rule-name "suppress-accepted-risk-dev-root-hw-mfa" \
  --rule-order 2 \
  --rule-status ENABLED \
  --description "Sandbox accepts IAM.6 (hardware MFA for root); root is centrally managed. Risk ticket SKY-142." \
  --criteria "{
      \"AwsAccountId\": [{\"Value\": \"$DEV\", \"Comparison\": \"EQUALS\"}],
      \"ComplianceSecurityControlId\": [{\"Value\": \"IAM.6\", \"Comparison\": \"EQUALS\"}]
    }" \
  --actions '[{
      "Type": "FINDING_FIELDS_UPDATE",
      "FindingFieldsUpdate": {
        "Workflow": {"Status": "SUPPRESSED"},
        "Note": {"Text": "Accepted risk SKY-142 (expires 2027-03-01)", "UpdatedBy": "skyfortress-automation"}
      }}]'

aws securityhub list-automation-rules --query 'AutomationRulesMetadata[].{Order:RuleOrder,Name:RuleName,Status:RuleStatus}' --output table
