// HTTP listener port for the Chat UI.
configurable int chatUiPort = 8092;

// Base URL of the Claims Policy Agent's authenticated secure-chat service
// (Step 8/10). The UI's own backend relays requests here, passing through
// the Authorization header the customer entered - this keeps the browser
// same-origin (talking only to chat_ui) and avoids needing CORS on the
// agent's secure-chat listener.
configurable string claimsAgentSecureChatBaseUrl = "http://localhost:8091";
