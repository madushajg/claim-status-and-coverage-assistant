import ballerina/http;
import ballerina/log;
import ballerina/otel as _;

// HTTP listener port for the Claims RAG query service.
configurable int ragServicePort = 8081;

// POST /coverage/questions
// Answers a coverage/policy question using retrieval-augmented generation
// against the local policy knowledge base populated at service startup.
service /coverage on new http:Listener(ragServicePort) {

    function init() returns error? {
        int ingestedCount = check ingestPolicyDocuments(ragDocumentsPath);
        log:printInfo(string `Ingested ${ingestedCount} policy document(s) into the claims knowledge base.`);
    }

    resource function post questions(@http:Payload CoverageQuestion coverageQuestion) returns CoverageAnswer|http:InternalServerError {
        CoverageAnswer|error coverageAnswer = answerCoverageQuestion(coverageQuestion);
        if coverageAnswer is error {
            return <http:InternalServerError>{body: {message: "Failed to answer the coverage question."}};
        }
        return coverageAnswer;
    }
}
