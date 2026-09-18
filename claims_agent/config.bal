// Base URL of the Claims MCP server (Step 6).
configurable string claimsMcpServerUrl = "http://localhost:8090/claims-mcp";

// Maximum number of reasoning-action cycles the Claims Policy Agent
// performs to complete a single request.
configurable int claimsAgentMaxIter = 10;

// HTTP listener port for the authenticated customer-facing chat endpoint.
configurable int secureChatServicePort = 8091;
