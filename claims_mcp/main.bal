import ballerina/mcp;

listener mcp:StreamableHttpListener mcpListener = check new (mcpServicePort);

@mcp:StreamableHttpServiceConfig {
    info: {
        name: "Claims MCP",
        version: "1.0.0",
        description: "Read-only tools for claim status, claim timeline, customer policy, and policy coverage questions."
    },
    sessionMode: mcp:STATELESS
}
service mcp:StreamableHttpService /claims\-mcp on mcpListener {

    // Retrieves the current status of a claim after verifying that it
    // belongs to the authenticated customer.
    @mcp:Tool {
        description: "Retrieve the current status of a claim (status, assigned team, reported date, SLA due date) for the authenticated customer."
    }
    remote function getClaimStatus(string customerId, string claimId) returns Claim|AuthorizationError|error {
        return fetchClaimStatus(customerId, claimId);
    }

    // Retrieves the timeline of a claim after verifying that it belongs
    // to the authenticated customer.
    @mcp:Tool {
        description: "Retrieve the timeline of events for a claim for the authenticated customer."
    }
    remote function getClaimTimeline(string customerId, string claimId) returns TimelineEvent[]|AuthorizationError|error {
        return fetchClaimTimeline(customerId, claimId);
    }

    // Retrieves the policies belonging to the authenticated customer.
    @mcp:Tool {
        description: "Retrieve the policies belonging to the authenticated customer."
    }
    remote function getCustomerPolicy(string customerId) returns Policy[]|AuthorizationError|error {
        return fetchCustomerPolicies(customerId);
    }

    // Answers a policy/coverage question using RAG over the approved
    // policy knowledge base.
    @mcp:Tool {
        description: "Answer a policy or coverage question (e.g. what is covered, what is excluded, which clause applies) using the approved policy knowledge base."
    }
    remote function answerCoverageQuestion(string question, string? policyNumber, string? policyProduct, string? policyVersion) returns CoverageAnswer|error {
        return fetchCoverageAnswer(question, policyNumber, policyProduct, policyVersion);
    }
}
