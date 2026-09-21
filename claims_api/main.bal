import ballerina/http;
import ballerina/otel as _;

// Consistent authorization error used whenever the caller cannot be
// authenticated, or is authenticated but does not own the requested
// resource. The message is deliberately generic so it never confirms or
// denies the existence of another customer's claim or policy.
final http:Forbidden accessDenied = {
    body: {message: "Access denied."}
};

service / on new http:Listener(servicePort) {

    // GET /claims/{claimId}
    // Retrieves the current status of a claim, after verifying that the
    // claim belongs to the authenticated customer.
    resource function get claims/[string claimId](@http:Header string? authorization)
            returns Claim|http:Forbidden|http:NotFound|http:BadRequest|http:InternalServerError {
        string|error customerId = extractCustomerId(authorization);
        if customerId is error {
            return <http:BadRequest>{body: {message: customerId.message()}};
        }

        Claim|error? claim = findClaimById(claimId);
        if claim is error {
            return <http:InternalServerError>{body: {message: "Failed to retrieve claim."}};
        }
        if claim is () {
            return <http:NotFound>{body: {message: "Claim not found."}};
        }
        if claim.customerId != customerId {
            return accessDenied;
        }
        return claim;
    }

    // GET /claims/{claimId}/timeline
    // Retrieves the timeline of a claim, after verifying ownership.
    resource function get claims/[string claimId]/timeline(@http:Header string? authorization)
            returns TimelineEvent[]|http:Forbidden|http:NotFound|http:BadRequest|http:InternalServerError {
        string|error customerId = extractCustomerId(authorization);
        if customerId is error {
            return <http:BadRequest>{body: {message: customerId.message()}};
        }

        Claim|error? claim = findClaimById(claimId);
        if claim is error {
            return <http:InternalServerError>{body: {message: "Failed to retrieve claim."}};
        }
        if claim is () {
            return <http:NotFound>{body: {message: "Claim not found."}};
        }
        if claim.customerId != customerId {
            return accessDenied;
        }

        TimelineEvent[]|error timeline = findClaimTimeline(claimId);
        if timeline is error {
            return <http:InternalServerError>{body: {message: "Failed to retrieve claim timeline."}};
        }
        return timeline;
    }

    // GET /customers/{customerId}/policies
    // Retrieves the policies belonging to a customer, after verifying that
    // the authenticated customer matches the requested customer.
    resource function get customers/[string customerId]/policies(@http:Header string? authorization)
            returns Policy[]|http:Forbidden|http:BadRequest|http:InternalServerError {
        string|error authenticatedCustomerId = extractCustomerId(authorization);
        if authenticatedCustomerId is error {
            return <http:BadRequest>{body: {message: authenticatedCustomerId.message()}};
        }
        if authenticatedCustomerId != customerId {
            return accessDenied;
        }

        Policy[]|error policies = findPoliciesByCustomerId(customerId);
        if policies is error {
            return <http:InternalServerError>{body: {message: "Failed to retrieve policies."}};
        }
        return policies;
    }
}
