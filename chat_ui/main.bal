import ballerina/http;

// Serves the Claims Policy Assistant chat page and relays chat requests to
// the authenticated /claims-policy-agent/secure-chat endpoint (Step 8/10).
// The browser only ever talks to this same-origin service - it never calls
// the agent's secure-chat listener directly - so no CORS configuration is
// needed on either side. The customer id entered in the page is converted
// into the test-only "Authorization: Bearer <customerId>" header here,
// server-side, before the relay call.
service / on new http:Listener(chatUiPort) {

    // GET / - serves the chat page.
    resource function get .() returns http:Response {
        http:Response response = new;
        response.setTextPayload(chatPageHtml, contentType = "text/html");
        return response;
    }

    // POST /chat - relays a chat message to the Claims Policy Agent's
    // secure-chat endpoint, using the customerId supplied by the page as
    // the test-only Authorization bearer token.
    resource function post chat(@http:Payload UiChatRequest chatRequest) returns UiChatResponse|http:BadRequest|http:InternalServerError {
        string customerId = chatRequest.customerId.trim();
        if customerId.length() == 0 {
            return <http:BadRequest>{body: {message: "Please enter a customer id."}};
        }

        map<string|string[]> headers = {"Authorization": string `Bearer ${customerId}`};
        record {|string message; string sessionId;|} agentRequestPayload = {
            message: chatRequest.message,
            sessionId: chatRequest.sessionId
        };

        record {|string message;|}|http:ClientError agentResult = claimsAgentSecureChatClient->/claims\-policy\-agent/secure\-chat.post(
            agentRequestPayload,
            headers = headers
        );

        if agentResult is record {|string message;|} {
            return {message: agentResult.message};
        }

        if agentResult is http:ClientRequestError {
            anydata errorBody = agentResult.detail().body;
            string errorMessage = errorBody is map<anydata> && errorBody["message"] is string
                ? <string>errorBody["message"]
                : "The request was rejected.";
            return <http:BadRequest>{body: {message: errorMessage}};
        }

        return <http:InternalServerError>{body: {message: "Failed to reach the Claims Policy Agent."}};
    }
}
