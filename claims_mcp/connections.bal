import ballerina/http;

// Client for the Claims HTTP API (Step 2). Ownership checks are enforced
// there; this MCP service relays the outcome instead of duplicating them.
final http:Client claimsApiClient = check new (claimsApiBaseUrl);

// Client for the Claims RAG coverage-question service (Step 5).
final http:Client claimsRagClient = check new (claimsRagBaseUrl);
