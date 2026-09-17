import ballerina/ai;
import ballerina/data.yaml;
import ballerina/lang.regexp;

// Matches a leading YAML frontmatter block delimited by "---" lines, e.g.:
// ---
// key: value
// ---
// remaining document body...
final regexp:RegExp frontmatterPattern = re `^---\r?\n(.*?)\r?\n---\r?\n?`;

// Splits a Markdown document's raw text into its YAML frontmatter metadata
// and the remaining Markdown body. If no frontmatter block is present, the
// metadata is (), and the body is the original text unchanged.
isolated function splitFrontmatter(string markdownText) returns [PolicyDocumentMetadata?, string]|error {
    regexp:Groups? groups = frontmatterPattern.findGroups(markdownText);
    if groups is () {
        return [(), markdownText];
    }
    regexp:Span fullMatch = groups[0];
    regexp:Span? frontmatterSpan = groups[1];
    if frontmatterSpan is () {
        return [(), markdownText];
    }
    string frontmatterYaml = frontmatterSpan.substring();
    string body = markdownText.substring(fullMatch.endIndex);
    map<json> rawMetadata = check yaml:parseString(frontmatterYaml);
    PolicyDocumentMetadata metadata = check parsePolicyDocumentMetadata(rawMetadata);
    return [metadata, body];
}

// Reads the "source" key (a YAML reserved-word clash with the "source"
// keyword prevents naming the record field the same) from the raw parsed
// frontmatter map, along with the remaining known fields.
isolated function parsePolicyDocumentMetadata(map<json> rawMetadata) returns PolicyDocumentMetadata|error {
    anydata sourceValue = rawMetadata["source"];
    if sourceValue !is string {
        return error("Policy document frontmatter is missing the 'source' field");
    }
    PolicyDocumentMetadata metadata = {sourceDocument: sourceValue};
    anydata policyProductValue = rawMetadata["policyProduct"];
    if policyProductValue is string {
        metadata.policyProduct = policyProductValue;
    }
    anydata policyVersionValue = rawMetadata["policyVersion"];
    if policyVersionValue is string {
        metadata.policyVersion = policyVersionValue;
    }
    anydata policyNumberValue = rawMetadata["policyNumber"];
    if policyNumberValue is string {
        metadata.policyNumber = policyNumberValue;
    }
    anydata effectiveDateValue = rawMetadata["effectiveDate"];
    if effectiveDateValue is string {
        metadata.effectiveDate = effectiveDateValue;
    } else if effectiveDateValue !is () {
        // YAML parses unquoted dates (e.g. 2026-01-01) as a date-like value;
        // fall back to its string form so metadata stays string-typed.
        metadata.effectiveDate = effectiveDateValue.toString();
    }
    return metadata;
}

// Converts parsed frontmatter metadata into an ai:Metadata value so it can
// be attached to the ingested document for later retrieval filtering.
isolated function toChunkMetadata(PolicyDocumentMetadata policyMetadata, string fileName) returns ai:Metadata {
    ai:Metadata metadata = {
        fileName: fileName,
        "source": policyMetadata.sourceDocument
    };
    string? policyProduct = policyMetadata.policyProduct;
    if policyProduct is string {
        metadata["policyProduct"] = policyProduct;
    }
    string? policyVersion = policyMetadata.policyVersion;
    if policyVersion is string {
        metadata["policyVersion"] = policyVersion;
    }
    string? policyNumber = policyMetadata.policyNumber;
    if policyNumber is string {
        metadata["policyNumber"] = policyNumber;
    }
    string? effectiveDate = policyMetadata.effectiveDate;
    if effectiveDate is string {
        metadata["effectiveDate"] = effectiveDate;
    }
    return metadata;
}
