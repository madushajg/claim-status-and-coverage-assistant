import ballerina/http;

// Client for the Claims Policy Agent's authenticated secure-chat service.
final http:Client claimsAgentSecureChatClient = check new (claimsAgentSecureChatBaseUrl);
