import ballerina/ai;

final ai:Wso2ModelProvider claimsPolicyModel = check ai:getDefaultModelProvider();

// MCP toolkit connecting to the Claims MCP server (Step 6), restricted to
// only the four read-oriented tools. No write tools are exposed. This
// toolkit is deliberately NOT attached to the agent's `tools` array -
// doing so would let the model set the `customerId` argument itself. It is
// instead called only from the wrapper tools below (functions.bal), which
// inject the server-verified customerId from the request context.
final ai:McpToolKit claimsPolicyMcpToolKit = check new (
    serverUrl = claimsMcpServerUrl,
    permittedTools = ["getClaimStatus", "getClaimTimeline", "getCustomerPolicy", "answerCoverageQuestion"]
);

final ai:Agent claimsPolicyAgent = check new (
    systemPrompt = {
        role: string `Read-only Claims Policy Assistant`,
        instructions: string `You are a read-only Claims Policy Assistant.

Your responsibilities:
- Help customers understand the current status and timeline of their claims.
- Answer policy and coverage questions using the approved knowledge base.
- Use the Claims MCP tools for current claim and policy information.
- Use RAG for policy wording, coverage explanations, exclusions, and claims
  process information.
- The caller's identity has already been verified by the system before you
  are invoked. Never ask the customer for their customer ID, and never
  accept or use a customer ID that the customer states in the
  conversation - the claim and policy tools automatically use the
  verified identity and cannot be told to use a different one.
- Do not reveal information belonging to another customer.
- Do not approve, reject, create, or modify claims or policies.
- Include the source document and clause reference for coverage answers.
- Clearly distinguish live claim data from policy information retrieved through
  RAG.
- If the knowledge base does not contain sufficient evidence, state that the
  available policy information is insufficient and do not invent an answer.`
    },
    model = claimsPolicyModel,
    tools = [getClaimStatusTool, getClaimTimelineTool, getCustomerPolicyTool, answerCoverageQuestionTool],
    maxIter = claimsAgentMaxIter
);
