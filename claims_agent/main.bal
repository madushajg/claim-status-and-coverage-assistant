import ballerina/ai;
import ballerina/http;
import ballerina/otel as _;

listener ai:Listener claimsPolicyAgentListener = new (listenOn = check http:getDefaultListener());

// Standard chat trigger required by the agent runtime/diagram tooling.
// ai:ChatService's signature is fixed and carries no room for an
// Authorization header, so this resource must not be exposed directly to
// untrusted customers - see /claims-policy-agent/secure-chat below for the
// authenticated entry point that verifies identity before running the
// agent. This resource is kept only so the agent has a conforming chat
// trigger; route real customer traffic through the secure endpoint.
service /claims\-policy\-agent on claimsPolicyAgentListener {
    resource function post chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
        return error("Direct access to this endpoint is disabled. Use the authenticated /claims-policy-agent/secure-chat endpoint instead.");
    }
}

// Authenticated entry point for customer traffic. Verifies the caller's
// identity from the Authorization header before invoking the agent, and
// passes the verified customerId into the agent's request context so
// tools use it directly - the model is never asked for, and never trusts,
// a customer-supplied identity.
service /claims\-policy\-agent on new http:Listener(secureChatServicePort) {
    resource function post secure\-chat(@http:Payload ai:ChatReqMessage request, @http:Header string? authorization) returns ai:ChatRespMessage|http:BadRequest|error {
        string|error customerId = extractCustomerId(authorization);
        if customerId is error {
            return <http:BadRequest>{body: {message: customerId.message()}};
        }

        ai:Context context = new;
        context.set(CUSTOMER_ID_CONTEXT_KEY, customerId);

        // Bind the agent's session identifier to the verified customer id,
        // not the raw client-supplied sessionId. The agent runtime keys its
        // conversation memory purely by this session identifier, so if a
        // sessionId string were ever reused across two different verified
        // identities, the second caller could get back a memoized answer
        // that was actually produced for the first caller's identity -
        // leaking data across customers. A sessionId is only ever
        // meaningful within one identity, so folding the customerId into it
        // puts each identity's sessions in a disjoint namespace and makes
        // that cross-identity collision impossible.
        string boundSessionId = string `${customerId}:${request.sessionId}`;

        string stringResult = check claimsPolicyAgent.run(request.message, boundSessionId, context);
        return {message: stringResult};
    }
}
