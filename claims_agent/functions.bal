import ballerina/ai;
import ballerina/mcp;

// Extracts the authenticated customer identity from the Authorization
// header of the incoming chat request. This is the same test-only identity
// mechanism used by the Claims API: the bearer token value itself is
// treated as the customer id (e.g. "Bearer C-100"). It must not be used as
// a production authentication mechanism.
isolated function extractCustomerId(string? authorizationHeader) returns string|error {
    if authorizationHeader is () {
        return error("Missing Authorization header");
    }
    string bearerPrefix = "Bearer ";
    if !authorizationHeader.startsWith(bearerPrefix) {
        return error("Invalid Authorization header format");
    }
    string customerId = authorizationHeader.substring(bearerPrefix.length()).trim();
    if customerId.length() == 0 {
        return error("Invalid Authorization header format");
    }
    return customerId;
}

// Key under which the server-verified customer identity is stored in the
// per-request ai:Context. This value is set by the chat trigger from a
// verified Authorization header - it is never supplied by the model.
const string CUSTOMER_ID_CONTEXT_KEY = "customerId";

// Reads the server-verified customer identity from the request context.
// Returns an error if the chat trigger did not set it, which should never
// happen for a request that has passed identity verification.
isolated function verifiedCustomerId(ai:Context ctx) returns string|error {
    ai:ContextEntry customerIdEntry = ctx.get(CUSTOMER_ID_CONTEXT_KEY);
    if customerIdEntry is string {
        return customerIdEntry;
    }
    return error("Missing verified customer identity in request context.");
}

// Extracts the first text content block from an MCP tool call result, or
// the structured content when present, as a JSON value ready to convert
// into a typed record.
isolated function extractToolResultJson(mcp:CallToolResult result) returns json|error {
    if result.isError == true {
        return error("The claims tool reported an error.");
    }
    map<anydata>? structuredContent = result.structuredContent;
    if structuredContent is map<anydata> {
        return structuredContent.toJson();
    }
    foreach mcp:ContentBlock contentBlock in result.content {
        if contentBlock is mcp:TextContent {
            return check contentBlock.text.fromJsonString();
        }
    }
    return error("The claims tool returned no readable content.");
}

// Calls the getClaimStatus tool on the Claims MCP server, injecting the
// server-verified customerId. The model never supplies or sees customerId.
#  Retrieve the current status of the caller's own claim (status, assigned team, reported date, SLA due date).
# + ctx - Context injected by the runtime, carrying the verified customer identity
# + claimId - The identifier of the claim to look up
# + return - The claim status, or an error if the claim cannot be found or does not belong to the caller
@ai:AgentTool
isolated function getClaimStatusTool(ai:Context ctx, string claimId) returns Claim|error {
    string customerId = check verifiedCustomerId(ctx);
    mcp:CallToolResult result = check claimsPolicyMcpToolKit.callTool({
        name: "getClaimStatus",
        arguments: {"customerId": customerId, "claimId": claimId}
    });
    json resultJson = check extractToolResultJson(result);
    return check resultJson.cloneWithType(Claim);
}

// Calls the getClaimTimeline tool on the Claims MCP server, injecting the
// server-verified customerId. The model never supplies or sees customerId.
# Retrieve the timeline of events for the caller's own claim.
# + ctx - Context injected by the runtime, carrying the verified customer identity
# + claimId - The identifier of the claim to look up
# + return - The claim's timeline events, or an error if the claim cannot be found or does not belong to the caller
@ai:AgentTool
isolated function getClaimTimelineTool(ai:Context ctx, string claimId) returns TimelineEvent[]|error {
    string customerId = check verifiedCustomerId(ctx);
    mcp:CallToolResult result = check claimsPolicyMcpToolKit.callTool({
        name: "getClaimTimeline",
        arguments: {"customerId": customerId, "claimId": claimId}
    });
    json resultJson = check extractToolResultJson(result);
    return check resultJson.cloneWithType();
}

// Calls the getCustomerPolicy tool on the Claims MCP server, injecting the
// server-verified customerId. The model never supplies or sees customerId.
# Retrieve the policies belonging to the caller's own customer account.
# + ctx - Context injected by the runtime, carrying the verified customer identity
# + return - The caller's policies
@ai:AgentTool
isolated function getCustomerPolicyTool(ai:Context ctx) returns Policy[]|error {
    string customerId = check verifiedCustomerId(ctx);
    mcp:CallToolResult result = check claimsPolicyMcpToolKit.callTool({
        name: "getCustomerPolicy",
        arguments: {"customerId": customerId}
    });
    json resultJson = check extractToolResultJson(result);
    return check resultJson.cloneWithType();
}

// Calls the answerCoverageQuestion tool on the Claims MCP server. This
// tool does not access customer-specific data, so no identity is required.
# Answer a policy or coverage question (what is covered, what is excluded, which clause applies) using the approved policy knowledge base.
# + question - The coverage or policy question to answer
# + policyNumber - The relevant policy number, if known
# + policyProduct - The relevant policy product, if known
# + policyVersion - The relevant policy version, if known
# + return - A grounded answer with source document and clause references
@ai:AgentTool
isolated function answerCoverageQuestionTool(string question, string? policyNumber, string? policyProduct, string? policyVersion) returns CoverageAnswer|error {
    mcp:CallToolResult result = check claimsPolicyMcpToolKit.callTool({
        name: "answerCoverageQuestion",
        arguments: {"question": question, "policyNumber": policyNumber, "policyProduct": policyProduct, "policyVersion": policyVersion}
    });
    json resultJson = check extractToolResultJson(result);
    return check resultJson.cloneWithType();
}
