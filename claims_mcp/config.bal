// HTTP listener port for the Claims MCP service.
configurable int mcpServicePort = 8090;

// Base URL of the Claims HTTP API (Step 2). All claim/policy ownership
// checks are enforced by this API - the MCP service relays its responses
// rather than re-implementing authorization.
configurable string claimsApiBaseUrl = "http://localhost:8080";

// Base URL of the Claims RAG coverage-question service (Step 5).
configurable string claimsRagBaseUrl = "http://localhost:8081";
