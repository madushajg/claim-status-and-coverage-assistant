import ballerina/time;

// Claim record - API representation, mirrors the `claims` table.
public type Claim record {|
    string claimId;
    string customerId;
    string policyNumber;
    string status;
    string reportedAt;
    string slaDueAt;
    string assignedTeam;
|};

// Raw claim row as returned by the database, before timestamp formatting.
type ClaimRow record {|
    string claimId;
    string customerId;
    string policyNumber;
    string status;
    time:Utc reportedAt;
    time:Utc slaDueAt;
    string assignedTeam;
|};

// A single event in a claim's timeline - API representation.
public type TimelineEvent record {|
    string time;
    string event;
|};

// Raw timeline event row as returned by the database.
type TimelineEventRow record {|
    time:Utc time;
    string event;
|};

// Policy record - API representation, mirrors the `policies` table.
public type Policy record {|
    string policyNumber;
    string customerId;
    string policyProduct;
    string policyVersion;
    string effectiveDate;
|};

// Raw policy row as returned by the database.
type PolicyRow record {|
    string policyNumber;
    string customerId;
    string policyProduct;
    string policyVersion;
    time:Date effectiveDate;
|};

// Consistent authorization error body. Deliberately generic so that it does
// not reveal whether the requested claim/policy exists for another customer.
public type AuthorizationError record {|
    string message;
|};

// Generic not-found error body.
public type NotFoundError record {|
    string message;
|};
