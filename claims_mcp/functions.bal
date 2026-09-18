import ballerina/http;

// Builds the test-only Authorization header value used by the Claims API,
// carrying the customer identity to be verified there.
isolated function authorizationHeaderFor(string customerId) returns map<string|string[]> {
    return {"Authorization": string `Bearer ${customerId}`};
}

// Calls the Claims API to retrieve a claim's status, relaying its
// ownership/authorization outcome rather than re-implementing it here.
isolated function fetchClaimStatus(string customerId, string claimId) returns Claim|AuthorizationError|error {
    Claim|http:ClientError result = claimsApiClient->/claims/[claimId].get(headers = authorizationHeaderFor(customerId));
    if result is Claim {
        return result;
    }
    if result is http:ApplicationResponseError {
        int statusCode = result.detail().statusCode;
        if statusCode == 403 {
            return error AuthorizationError("Access denied.");
        }
        if statusCode == 404 {
            return error("Claim not found.");
        }
    }
    return error("Failed to retrieve claim status.");
}

// Calls the Claims API to retrieve a claim's timeline, relaying its
// ownership/authorization outcome rather than re-implementing it here.
isolated function fetchClaimTimeline(string customerId, string claimId) returns TimelineEvent[]|AuthorizationError|error {
    TimelineEvent[]|http:ClientError result = claimsApiClient->/claims/[claimId]/timeline.get(headers = authorizationHeaderFor(customerId));
    if result is TimelineEvent[] {
        return result;
    }
    if result is http:ApplicationResponseError {
        int statusCode = result.detail().statusCode;
        if statusCode == 403 {
            return error AuthorizationError("Access denied.");
        }
        if statusCode == 404 {
            return error("Claim not found.");
        }
    }
    return error("Failed to retrieve claim timeline.");
}

// Calls the Claims API to retrieve the policies belonging to a customer,
// relaying its authorization outcome rather than re-implementing it here.
isolated function fetchCustomerPolicies(string customerId) returns Policy[]|AuthorizationError|error {
    Policy[]|http:ClientError result = claimsApiClient->/customers/[customerId]/policies.get(headers = authorizationHeaderFor(customerId));
    if result is Policy[] {
        return result;
    }
    if result is http:ApplicationResponseError {
        int statusCode = result.detail().statusCode;
        if statusCode == 403 {
            return error AuthorizationError("Access denied.");
        }
    }
    return error("Failed to retrieve customer policies.");
}

// Calls the Claims RAG service to answer a policy/coverage question.
isolated function fetchCoverageAnswer(string question, string? policyNumber, string? policyProduct, string? policyVersion) returns CoverageAnswer|error {
    record {|string question; string? policyNumber; string? policyProduct; string? policyVersion;|} requestPayload = {
        question,
        policyNumber,
        policyProduct,
        policyVersion
    };
    CoverageAnswer|http:ClientError result = claimsRagClient->/coverage/questions.post(requestPayload);
    if result is CoverageAnswer {
        return result;
    }
    return error("Failed to answer the coverage question.");
}
