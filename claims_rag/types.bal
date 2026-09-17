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
