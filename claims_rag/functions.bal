import ballerina/ai;
import ballerina/file;
import ballerina/io;

// Loads every Markdown file in the given directory, splits off its YAML
// frontmatter, and builds an ai:TextDocument carrying the parsed metadata
// so that retrieval can later be filtered by policy product/version/number.
isolated function loadPolicyDocuments(string documentsPath) returns ai:TextDocument[]|error {
    file:MetaData[] entries = check file:readDir(documentsPath);
    ai:TextDocument[] documents = [];
    foreach file:MetaData entry in entries {
        if entry.dir || !entry.absPath.endsWith(".md") {
            continue;
        }
        string markdownText = check io:fileReadString(entry.absPath);
        [PolicyDocumentMetadata?, string] [frontmatter, body] = check splitFrontmatter(markdownText);
        string fileName = check file:basename(entry.absPath);
        ai:Metadata metadata = frontmatter is PolicyDocumentMetadata
            ? toChunkMetadata(frontmatter, fileName)
            : {fileName: fileName};
        ai:TextDocument document = {
            content: body,
            metadata: metadata
        };
        documents.push(document);
    }
    return documents;
}

// Ingests the local policy Markdown documents into the claims knowledge
// base. The knowledge base chunks, embeds, and stores each document
// automatically.
isolated function ingestPolicyDocuments(string documentsPath) returns int|error {
    ai:TextDocument[] documents = check loadPolicyDocuments(documentsPath);
    check claimsKnowledgeBase.ingest(documents);
    return documents.length();
}
