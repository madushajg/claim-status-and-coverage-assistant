import ballerina/sql;
import ballerina/time;

// Formats a time:Utc value as an ISO-8601 string, e.g. "2026-01-20T09:00:00Z".
isolated function formatUtc(time:Utc utc) returns string {
    return time:utcToString(utc);
}

// Formats a time:Date value as an ISO-8601 date string, e.g. "2026-01-01".
isolated function formatDate(time:Date date) returns string {
    return string `${date.year}-${padTwoDigits(date.month)}-${padTwoDigits(date.day)}`;
}

isolated function padTwoDigits(int value) returns string {
    if value < 10 {
        return string `0${value}`;
    }
    return value.toString();
}

// Retrieves a claim by its identifier, regardless of owner.
// Returns () when the claim does not exist.
isolated function findClaimById(string claimId) returns Claim|error? {
    sql:ParameterizedQuery query = `SELECT
            claim_id AS "claimId",
            customer_id AS "customerId",
            policy_number AS "policyNumber",
            status AS "status",
            reported_at AS "reportedAt",
            sla_due_at AS "slaDueAt",
            assigned_team AS "assignedTeam"
        FROM claims
        WHERE claim_id = ${claimId}`;
    ClaimRow|sql:Error result = claimsDbClient->queryRow(query);
    if result is sql:NoRowsError {
        return ();
    }
    if result is sql:Error {
        return result;
    }
    Claim claim = {
        claimId: result.claimId,
        customerId: result.customerId,
        policyNumber: result.policyNumber,
        status: result.status,
        reportedAt: formatUtc(result.reportedAt),
        slaDueAt: formatUtc(result.slaDueAt),
        assignedTeam: result.assignedTeam
    };
    return claim;
}

// Retrieves the timeline events for a claim ordered by time.
isolated function findClaimTimeline(string claimId) returns TimelineEvent[]|error {
    sql:ParameterizedQuery query = `SELECT
            event_time AS "time",
            event AS "event"
        FROM claim_timeline
        WHERE claim_id = ${claimId}
        ORDER BY event_time`;
    stream<TimelineEventRow, sql:Error?> resultStream = claimsDbClient->query(query);
    TimelineEvent[] events = check from TimelineEventRow eventRow in resultStream
        select {
            time: formatUtc(eventRow.time),
            event: eventRow.event
        };
    return events;
}

// Retrieves the policies that belong to a customer.
isolated function findPoliciesByCustomerId(string customerId) returns Policy[]|error {
    sql:ParameterizedQuery query = `SELECT
            policy_number AS "policyNumber",
            customer_id AS "customerId",
            policy_product AS "policyProduct",
            policy_version AS "policyVersion",
            effective_date AS "effectiveDate"
        FROM policies
        WHERE customer_id = ${customerId}`;
    stream<PolicyRow, sql:Error?> resultStream = claimsDbClient->query(query);
    Policy[] policies = check from PolicyRow policyRow in resultStream
        select {
            policyNumber: policyRow.policyNumber,
            customerId: policyRow.customerId,
            policyProduct: policyRow.policyProduct,
            policyVersion: policyRow.policyVersion,
            effectiveDate: formatDate(policyRow.effectiveDate)
        };
    return policies;
}

// Extracts the authenticated customer identity from the Authorization header.
// This is a test-only identity mechanism: the bearer token value itself is
// treated as the customer id (e.g. "Bearer C-100"). It must not be used as a
// production authentication mechanism.
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
