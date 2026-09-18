// Claim status information, mirrors the getClaimStatus MCP tool response.
type Claim record {|
    string claimId;
    string customerId;
    string policyNumber;
    string status;
    string reportedAt;
    string slaDueAt;
    string assignedTeam;
|};

// A single event in a claim's timeline, mirrors the getClaimTimeline MCP
// tool response.
type TimelineEvent record {|
    string time;
    string event;
|};

// Policy information, mirrors the getCustomerPolicy MCP tool response.
type Policy record {|
    string policyNumber;
    string customerId;
    string policyProduct;
    string policyVersion;
    string effectiveDate;
|};

// A single source/clause reference backing a coverage answer.
type CoverageAnswerSource record {|
    string sourceDocument;
    string? clause = ();
    string? policyNumber = ();
    string? policyProduct = ();
    string? policyVersion = ();
|};

// The grounded answer to a coverage question, mirrors the
// answerCoverageQuestion MCP tool response.
type CoverageAnswer record {|
    string answer;
    CoverageAnswerSource[] sources;
|};
