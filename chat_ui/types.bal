// Request body submitted by the browser page to this UI's own /chat relay
// resource. Mirrors the fields the secure-chat endpoint expects, plus the
// customerId entered in the UI which is turned into the Authorization
// header server-side rather than being sent as a header directly from the
// browser (keeping the page's fetch() call same-origin and header-free).
public type UiChatRequest record {|
    string customerId;
    string sessionId;
    string message;
|};

// Response body returned by this UI's /chat relay resource to the browser.
public type UiChatResponse record {|
    string message;
|};
