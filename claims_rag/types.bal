// YAML frontmatter metadata parsed from the top of each policy Markdown
// document. This is attached to the ingested chunk metadata so that
// retrieval can be filtered by policy product, version, and number.
type PolicyDocumentMetadata record {
    string sourceDocument;
    string policyProduct?;
    string policyVersion?;
    string policyNumber?;
    string effectiveDate?;
};

// A coverage question submitted by a customer or an MCP/agent caller.
public type CoverageQuestion record {|
    string question;
    string? policyNumber = ();
    string? policyProduct = ();
    string? policyVersion = ();
|};

// A single source/clause reference backing a coverage answer.
public type CoverageAnswerSource record {|
    string sourceDocument;
    string? clause = ();
    string? policyNumber = ();
    string? policyProduct = ();
    string? policyVersion = ();
|};

// The grounded answer to a coverage question, with supporting references.
public type CoverageAnswer record {|
    string answer;
    CoverageAnswerSource[] sources;
|};
