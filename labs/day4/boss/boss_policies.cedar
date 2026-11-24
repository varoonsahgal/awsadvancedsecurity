// =====================================================================
// BOSS — The Poisoned Manifest
// Write the policy set for the customs automation agent (principal in Nimbus::Role::"automation-agent").
//
// The agent legitimately needs to:
//   - DocTool__read_manifest          (any manifest)
//   - OrderTool__get_order            (only for its own account_id)
//   - CustomsTool__clear_shipment     (any manifest)
//   - WebhookTool__post_webhook       (ONLY to https://hooks.nimbus.internal/...)
// It must never:
//   - DataTool__export_customer_data  (ever)
//   - post a webhook anywhere else — including look-alike hosts.
//
// Hint: Cedar's `like` operator supports * wildcards. Think hard about what comes right after
// "hooks.nimbus.internal" in a URL you trust.
// =====================================================================

permit (principal, action, resource);
