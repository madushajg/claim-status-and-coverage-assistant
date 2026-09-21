// The Claims Policy Assistant chat page: a minimal single-page UI with
// inline CSS and JavaScript, no build step or external assets. It posts
// to this same service's own /chat resource (same-origin, no CORS
// needed), which relays to the agent's authenticated secure-chat endpoint.
final string chatPageHtml = string `
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Claims Policy Assistant</title>
<style>
  body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; max-width: 720px; margin: 40px auto; padding: 0 16px; background: #f5f6f8; }
  h1 { font-size: 20px; color: #1f2937; }
  .bar { display: flex; gap: 8px; margin-bottom: 16px; }
  .bar input { flex: 1; padding: 8px; border: 1px solid #d1d5db; border-radius: 6px; }
  #log { background: #fff; border: 1px solid #d1d5db; border-radius: 8px; padding: 16px; height: 420px; overflow-y: auto; margin-bottom: 12px; }
  .msg { margin-bottom: 12px; max-width: 85%; padding: 8px 12px; border-radius: 8px; white-space: pre-wrap; line-height: 1.4; }
  .user { background: #2563eb; color: #fff; margin-left: auto; }
  .assistant { background: #e5e7eb; color: #111827; }
  .error { background: #fee2e2; color: #991b1b; }
  form { display: flex; gap: 8px; }
  form input[type=text] { flex: 1; padding: 10px; border: 1px solid #d1d5db; border-radius: 6px; }
  button { padding: 10px 16px; border: none; border-radius: 6px; background: #2563eb; color: #fff; cursor: pointer; }
  button:disabled { background: #9ca3af; cursor: default; }
  .hint { color: #6b7280; font-size: 13px; margin-top: 8px; }
</style>
</head>
<body>
  <h1>Claims Policy Assistant</h1>
  <div class="bar">
    <input id="customerId" type="text" placeholder="Customer id (e.g. C-100)" value="C-100">
  </div>
  <div id="log"></div>
  <form id="chatForm">
    <input id="message" type="text" placeholder="Ask about a claim, policy, or coverage..." autocomplete="off">
    <button type="submit" id="sendButton">Send</button>
  </form>
  <div class="hint">
    Every message is sent with the customer id above as the verified identity.
    Change it to test access control (e.g. C-100 vs C-200).
  </div>

<script>
  const sessionId = 'ui-session-' + Math.random().toString(36).slice(2);
  const log = document.getElementById('log');
  const form = document.getElementById('chatForm');
  const messageInput = document.getElementById('message');
  const customerIdInput = document.getElementById('customerId');
  const sendButton = document.getElementById('sendButton');

  function appendMessage(text, cssClass) {
    const div = document.createElement('div');
    div.className = 'msg ' + cssClass;
    div.textContent = text;
    log.appendChild(div);
    log.scrollTop = log.scrollHeight;
  }

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const message = messageInput.value.trim();
    const customerId = customerIdInput.value.trim();
    if (!message || !customerId) {
      return;
    }

    appendMessage(message, 'user');
    messageInput.value = '';
    sendButton.disabled = true;

    try {
      const response = await fetch('/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ customerId, sessionId, message })
      });
      const data = await response.json();
      if (response.ok) {
        appendMessage(data.message, 'assistant');
      } else {
        appendMessage(data.message || 'Request failed.', 'error');
      }
    } catch (err) {
      appendMessage('Network error: ' + err.message, 'error');
    } finally {
      sendButton.disabled = false;
      messageInput.focus();
    }
  });
</script>
</body>
</html>
`;
