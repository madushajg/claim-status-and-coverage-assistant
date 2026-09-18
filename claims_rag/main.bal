import ballerina/io;

// Ingests the local Markdown policy knowledge documents into the in-memory
// vector knowledge base, then answers a set of sample coverage questions
// to demonstrate the RAG query function end-to-end. The knowledge base is
// in-memory, so ingestion and querying must happen within the same run.
public function main() returns error? {
    int ingestedCount = check ingestPolicyDocuments(ragDocumentsPath);
    io:println(string `Ingested ${ingestedCount} policy document(s) into the claims knowledge base.`);

    CoverageQuestion[] sampleQuestions = [
        {question: "Does policy POL-1001 cover windshield replacement?", policyNumber: "POL-1001"},
        {question: "Which policy clause supports that answer?", policyNumber: "POL-1001"},
        {question: "Does policy POL-1001 cover damage caused by an earthquake?", policyNumber: "POL-1001"}
    ];

    foreach CoverageQuestion sampleQuestion in sampleQuestions {
        CoverageAnswer coverageAnswer = check answerCoverageQuestion(sampleQuestion);
        io:println("\nQuestion: ", sampleQuestion.question);
        io:println("Answer: ", coverageAnswer.answer);
        io:println("Sources: ", coverageAnswer.sources);
    }
}
