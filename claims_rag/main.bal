import ballerina/io;

// Ingests the local Markdown policy knowledge documents into the in-memory
// vector knowledge base. Run this automation once at startup, or whenever
// the documents in `ragDocumentsPath` change, to (re)populate the
// knowledge base used by the coverage-question query capability.
public function main() returns error? {
    int ingestedCount = check ingestPolicyDocuments(ragDocumentsPath);
    io:println(string `Ingested ${ingestedCount} policy document(s) into the claims knowledge base.`);
}
