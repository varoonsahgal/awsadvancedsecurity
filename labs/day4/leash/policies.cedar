// =====================================================================
// Lab 4.4 — Leash the Agent
// STARTER POLICY. Today the refund agent may call ANY tool with ANY input.
// The Kraken Collective loves this file. Replace it with least-privilege rules.
//
// Entity model (mirrors what an AgentCore Gateway exposes to Cedar):
//   principal : Nimbus::User::"<id>"      attrs: account_id (String), parents: Nimbus::Role
//   action    : Nimbus::Action::"<Target>__<tool>"
//   resource  : Nimbus::Gateway::"refund-gateway"
//   context   : { input: <the tool call arguments>, day_of_week: "Mon".."Sun" }
//
// Cedar semantics you need:
//   * default DENY — nothing is allowed unless some permit matches
//   * any matching forbid beats every permit
//   * a policy whose condition hits a runtime ERROR (e.g. comparing a String with <=) is skipped
// =====================================================================

permit (principal, action, resource);
