import ballerina/ai;
import ballerina/http;

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

        string stringResult = check claimsPolicyAgent.run(request.message, request.sessionId, context);
        return {message: stringResult};
    }
}
