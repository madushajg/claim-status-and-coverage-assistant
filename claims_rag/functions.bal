import ballerina/ai;
import ballerina/file;
import ballerina/io;

// Loads every Markdown file in the given directory, splits off its YAML
// frontmatter, chunks the remaining body by markdown headers, and
// re-attaches the parsed policy metadata (policyProduct/policyVersion/
// policyNumber/source) onto every resulting chunk. This is done explicitly
// because chunking does not carry a Document's custom metadata over to its
// Chunks, so retrieval-time metadata filtering would otherwise find nothing.
isolated function loadPolicyChunks(string documentsPath) returns ai:Chunk[]|error {
    file:MetaData[] entries = check file:readDir(documentsPath);
    ai:Chunk[] allChunks = [];
    foreach file:MetaData entry in entries {
        if entry.dir || !entry.absPath.endsWith(".md") {
            continue;
        }
        string markdownText = check io:fileReadString(entry.absPath);
        [PolicyDocumentMetadata?, string] [frontmatter, body] = check splitFrontmatter(markdownText);
        string fileName = check file:basename(entry.absPath);
        ai:Metadata documentMetadata = frontmatter is PolicyDocumentMetadata
            ? toChunkMetadata(frontmatter, fileName)
            : {fileName: fileName};
        ai:TextDocument document = {content: body, metadata: documentMetadata};

        ai:Chunk[] documentChunks = check policyMarkdownChunker.chunk(document);
        foreach ai:Chunk documentChunk in documentChunks {
            ai:Metadata chunkMetadata = documentChunk.metadata ?: {};
            ai:Metadata mergedMetadata = mergePolicyMetadataIntoChunk(chunkMetadata, documentMetadata);
            anydata chunkContent = documentChunk.content;
            string chunkText = chunkContent is string ? chunkContent : chunkContent.toString();
            ai:TextChunk taggedChunk = {content: chunkText, metadata: mergedMetadata};
            allChunks.push(taggedChunk);
        }
    }
    return allChunks;
}

// Ingests the local policy Markdown documents into the claims knowledge
// base as pre-chunked, pre-tagged chunks (see loadPolicyChunks). Passing
// Chunk[] to ingest skips any further internal chunking.
isolated function ingestPolicyDocuments(string documentsPath) returns int|error {
    ai:Chunk[] chunks = check loadPolicyChunks(documentsPath);
    ai:Error? ingestResult = claimsKnowledgeBase.ingest(chunks);
    if ingestResult is ai:Error {
        error? cause = ingestResult.cause();
        string causeMessage = cause is error ? cause.message() : "no cause";
        return error(string `Ingestion failed: ${ingestResult.message()}; cause: ${causeMessage}`);
    }
    return chunks.length();
}

// Builds the metadata filters constraining retrieval to the relevant
// policy product/version/number, when provided on the question.
isolated function buildCoverageFilters(CoverageQuestion coverageQuestion) returns ai:MetadataFilters? {
    ai:MetadataFilter[] filters = [];
    string? policyNumber = coverageQuestion.policyNumber;
    if policyNumber is string {
        filters.push({key: "policyNumber", value: policyNumber});
    }
    string? policyProduct = coverageQuestion.policyProduct;
    if policyProduct is string {
        filters.push({key: "policyProduct", value: policyProduct});
    }
    string? policyVersion = coverageQuestion.policyVersion;
    if policyVersion is string {
        filters.push({key: "policyVersion", value: policyVersion});
    }
    if filters.length() == 0 {
        return ();
    }
    return {filters, condition: ai:AND};
}

// Answers a coverage question using retrieval-augmented generation:
// retrieves the relevant policy passages (optionally constrained to a
// policy product/version/number), and asks the model to generate an
// answer grounded strictly in those passages. Returns () when the
// knowledge base has no sufficiently relevant evidence for the question.
isolated function answerCoverageQuestion(CoverageQuestion coverageQuestion) returns CoverageAnswer|error {
    ai:MetadataFilters? filters = buildCoverageFilters(coverageQuestion);
    ai:QueryMatch[] queryMatches = check claimsKnowledgeBase.retrieve(coverageQuestion.question, 5, filters);
    if queryMatches.length() == 0 {
        return {
            answer: "The available policy information is insufficient to answer this question.",
            sources: []
        };
    }

    ai:ChatUserMessage augmentedQuery = ai:augmentUserQuery(queryMatches, groundedAnswerInstruction(coverageQuestion.question));
    ai:ChatAssistantMessage assistantMessage = check policyModelProvider->chat(augmentedQuery, []);
    string? assistantContent = assistantMessage.content;
    string answerText = assistantContent is string ? assistantContent : "The available policy information is insufficient to answer this question.";

    CoverageAnswerSource[] sources = from ai:QueryMatch queryMatch in queryMatches
        let CoverageAnswerSource? answerSource = toCoverageAnswerSource(queryMatch)
        where answerSource is CoverageAnswerSource
        select answerSource;

    return {answer: answerText, sources: deduplicateSources(sources)};
}

// Instruction prepended to the user's question so the model answers only
// from the retrieved passages and clearly states when evidence is missing,
// instead of inventing coverage details.
isolated function groundedAnswerInstruction(string question) returns string {
    return string `Answer the following insurance policy question using only the provided context passages. ` +
        string `If the context does not contain enough information to answer confidently, state that the available ` +
        string `policy information is insufficient instead of guessing. Do not invent coverage details. ` +
        string `Question: ${question}`;
}
