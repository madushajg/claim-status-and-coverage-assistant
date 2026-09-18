import ballerina/ai;
import ballerina/data.yaml;
import ballerina/lang.regexp;

// The delimiter line marking the start and end of a YAML frontmatter block.
const string FRONTMATTER_DELIMITER = "---";

// Matches a single newline, used to split Markdown text into lines.
final regexp:RegExp newlinePattern = re `\n`;

// Splits a Markdown document's raw text into its YAML frontmatter metadata
// and the remaining Markdown body. The frontmatter block is delimited by a
// "---" line at the very start of the document and a second "---" line
// that closes it, e.g.:
// ---
// key: value
// ---
// remaining document body...
// If no frontmatter block is present, the metadata is (), and the body is
// the original text unchanged. Matching is done line-by-line (rather than
// with a single regular expression) so the YAML block, which spans
// multiple lines, is captured reliably regardless of line-ending style.
isolated function splitFrontmatter(string markdownText) returns [PolicyDocumentMetadata?, string]|error {
    string[] lines = newlinePattern.split(markdownText);
    if lines.length() == 0 || lines[0].trim() != FRONTMATTER_DELIMITER {
        return [(), markdownText];
    }
    int? closingLineIndex = ();
    foreach int lineIndex in 1 ..< lines.length() {
        if lines[lineIndex].trim() == FRONTMATTER_DELIMITER {
            closingLineIndex = lineIndex;
            break;
        }
    }
    if closingLineIndex is () {
        return [(), markdownText];
    }
    string[] frontmatterLines = lines.slice(1, closingLineIndex);
    string frontmatterYaml = string:'join("\n", ...frontmatterLines);
    string[] bodyLines = lines.slice(closingLineIndex + 1);
    string body = string:'join("\n", ...bodyLines);
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

// Merges the source document's policy metadata into a chunk's own
// computed metadata (header/index/id/etc.), keeping the chunk's computed
// fields and adding the policy-level fields alongside them.
isolated function mergePolicyMetadataIntoChunk(ai:Metadata chunkMetadata, ai:Metadata documentMetadata) returns ai:Metadata {
    ai:Metadata mergedMetadata = chunkMetadata.clone();
    anydata sourceValue = documentMetadata["source"];
    if sourceValue is string {
        mergedMetadata["source"] = sourceValue;
    }
    anydata policyProductValue = documentMetadata["policyProduct"];
    if policyProductValue is string {
        mergedMetadata["policyProduct"] = policyProductValue;
    }
    anydata policyVersionValue = documentMetadata["policyVersion"];
    if policyVersionValue is string {
        mergedMetadata["policyVersion"] = policyVersionValue;
    }
    anydata policyNumberValue = documentMetadata["policyNumber"];
    if policyNumberValue is string {
        mergedMetadata["policyNumber"] = policyNumberValue;
    }
    anydata effectiveDateValue = documentMetadata["effectiveDate"];
    if effectiveDateValue is string {
        mergedMetadata["effectiveDate"] = effectiveDateValue;
    }
    return mergedMetadata;
}

// Builds a source/clause reference from a retrieved query match's chunk
// metadata. The clause is the most specific markdown header captured by
// the MarkdownChunker (header, falling back to header2, the level used for
// "## Clause ..." headings in the policy documents).
isolated function toCoverageAnswerSource(ai:QueryMatch queryMatch) returns CoverageAnswerSource? {
    ai:Chunk chunk = queryMatch.chunk;
    ai:Metadata? metadata = chunk.metadata;
    if metadata is () {
        return ();
    }
    anydata sourceValue = metadata["source"];
    if sourceValue !is string {
        return ();
    }
    string? clause = metadata.header ?: metadata.header2;
    CoverageAnswerSource answerSource = {sourceDocument: sourceValue, clause};
    anydata policyNumberValue = metadata["policyNumber"];
    if policyNumberValue is string {
        answerSource.policyNumber = policyNumberValue;
    }
    anydata policyProductValue = metadata["policyProduct"];
    if policyProductValue is string {
        answerSource.policyProduct = policyProductValue;
    }
    anydata policyVersionValue = metadata["policyVersion"];
    if policyVersionValue is string {
        answerSource.policyVersion = policyVersionValue;
    }
    return answerSource;
}

// Deduplicates source references by (sourceDocument, clause) pair, keeping
// the first occurrence order so citation lists don't repeat the same
// clause when multiple retrieved chunks came from it.
isolated function deduplicateSources(CoverageAnswerSource[] sources) returns CoverageAnswerSource[] {
    CoverageAnswerSource[] uniqueSources = [];
    string[] seenKeys = [];
    foreach CoverageAnswerSource candidateSource in sources {
        string key = string `${candidateSource.sourceDocument}|${candidateSource.clause ?: ""}`;
        if seenKeys.indexOf(key) is () {
            seenKeys.push(key);
            uniqueSources.push(candidateSource);
        }
    }
    return uniqueSources;
}
