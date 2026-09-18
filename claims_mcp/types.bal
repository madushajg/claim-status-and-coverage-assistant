// Claim status information returned by the getClaimStatus tool.
public type Claim record {|
    string claimId;
    string customerId;
    string policyNumber;
    string status;
    string reportedAt;
    string slaDueAt;
    string assignedTeam;
|};

// A single event in a claim's timeline, returned by the getClaimTimeline tool.
public type TimelineEvent record {|
    string time;
    string event;
|};

// Policy information returned by the getCustomerPolicy tool.
public type Policy record {|
    string policyNumber;
    string customerId;
    string policyProduct;
    string policyVersion;
    string effectiveDate;
|};

// A single source/clause reference backing a coverage answer.
public type CoverageAnswerSource record {|
    string sourceDocument;
    string? clause = ();
    string? policyNumber = ();
    string? policyProduct = ();
    string? policyVersion = ();
|};

// The grounded answer returned by the answerCoverageQuestion tool.
public type CoverageAnswer record {|
    string answer;
    CoverageAnswerSource[] sources;
|};

// A consistent authorization error surfaced to the MCP client when the
// caller's identity cannot be established, or ownership of the requested
// claim/policy cannot be verified. Deliberately generic so it never
// confirms or denies whether a claim/policy belongs to another customer.
public type AuthorizationError distinct error;
