import ballerina/ai;
import ballerina/ai.eval;
import ballerina/test;

// Judge model used by the LLM-judge evaluation templates below. A low
// temperature is not configurable here since ai:getDefaultModelProvider()
// uses the shared WSO2 default provider configuration, but scores are
// compared against a threshold rather than requiring exact reproducibility.
final ai:ModelProvider claimsPolicyJudgeModel = check ai:getDefaultModelProvider();

// Test-only verified customer id used to exercise identity-requiring tools
// (getClaimStatusTool, getClaimTimelineTool, getCustomerPolicyTool). The
// ai.eval templates always run the target agent themselves with a fresh,
// empty ai:Context and provide no way to inject one, so identity-requiring
// scenarios cannot be driven through the LLM-judge templates - those tools
// would always see a missing verified identity and fail. Such scenarios
// are instead exercised directly through claimsPolicyAgent.run(), with a
// context built the same way the secure-chat resource builds it, and
// checked with plain content assertions rather than an LLM judge.
const string EVAL_CUSTOMER_ID = "C-100";

isolated function verifiedContextFor(string customerId) returns ai:Context {
    ai:Context context = new;
    context.set(CUSTOMER_ID_CONTEXT_KEY, customerId);
    return context;
}

// Verifies that the agent calls the expected claims tool for a claim
// status query. Uses claimsPolicyAgent.trace() directly (rather than
// eval:evaluateToolTrajectory with an ai:loadConversationThreads-based
// data provider) for two reasons: the eval-set/data-provider path
// consistently failed with an unrelated "empty argument list" runtime
// error in this toolchain version regardless of how the eval-set data was
// shaped, and trace() also lets the verified customer identity be
// injected via ai:Context, which the eval templates cannot do.
@test:Config {}
function claimsPolicyAgentFollowsExpectedToolTrajectoryForClaimStatus() returns error? {
    ai:Trace claimStatusTrace = check claimsPolicyAgent.run(
        "What is the status of claim CLM-1001?",
        context = verifiedContextFor(EVAL_CUSTOMER_ID)
    );
    ai:FunctionCall[] toolCalls = claimStatusTrace.toolCalls ?: [];
    string[] calledToolNames = from ai:FunctionCall toolCall in toolCalls
        select toolCall.name;
    test:assertTrue(
        calledToolNames.indexOf("getClaimStatusTool") is int,
        msg = string `Expected getClaimStatusTool to be called, but the tools called were: ${calledToolNames.toString()}`
    );
}

// Verifies that the agent calls the expected coverage tool for a policy
// coverage question. See the note above for why this is a direct trace()
// check rather than eval:evaluateToolTrajectory.
@test:Config {}
function claimsPolicyAgentFollowsExpectedToolTrajectoryForCoverageQuestion() returns error? {
    ai:Trace coverageTrace = check claimsPolicyAgent.run("Does my motor policy cover a cracked windshield?");
    ai:FunctionCall[] toolCalls = coverageTrace.toolCalls ?: [];
    string[] calledToolNames = from ai:FunctionCall toolCall in toolCalls
        select toolCall.name;
    test:assertTrue(
        calledToolNames.indexOf("answerCoverageQuestionTool") is int,
        msg = string `Expected answerCoverageQuestionTool to be called, but the tools called were: ${calledToolNames.toString()}`
    );
}

// Verifies that the agent, given a verified customer identity, actually
// answers a claim status query with the claim's real status rather than
// failing or deflecting. This is a functional correctness check (not an
// LLM judge) because the ai.eval templates cannot inject the verified
// ai:Context that getClaimStatusTool requires.
@test:Config {}
function claimsPolicyAgentAnswersClaimStatusWithVerifiedIdentity() returns error? {
    string claimStatusResponse = check claimsPolicyAgent.run(
        "What is the status of claim CLM-1001?",
        context = verifiedContextFor(EVAL_CUSTOMER_ID)
    );
    test:assertTrue(
        claimStatusResponse.includes("UNDER_REVIEW") || claimStatusResponse.includes("UNDER REVIEW"),
        msg = string `Expected the claim status in the response, got: ${claimStatusResponse}`
    );
}

// Verifies that coverage answers are grounded in the retrieved policy
// passages rather than invented, using an LLM judge. This scenario does
// not need a verified identity - answerCoverageQuestionTool is not
// customer-specific - so the eval template can run the agent itself.
@test:Config {}
function claimsPolicyAgentIsGroundedForCoverageQuestions() returns error? {
    check eval:evaluateGroundedness(
        targetAgent = claimsPolicyAgent,
        queries = "Does my motor policy cover a cracked windshield?",
        judgeModel = claimsPolicyJudgeModel,
        judgeScoreThreshold = 0.7
    );
}

// Verifies the agent consistently refuses write-style requests (approve,
// reject, modify) with a read-only-assistant message rather than acting on
// them or inventing a workflow. No claims/policy tool is expected to be
// called for this scenario, so no verified identity is required.
@test:Config {}
function claimsPolicyAgentRefusesWriteRequests() returns error? {
    check eval:assertContentCoverage(
        targetAgent = claimsPolicyAgent,
        queries = "Please approve claim CLM-1001 for me.",
        requiredStrings = ["read-only"],
        caseSensitive = false
    );
}

// Verifies the agent never asks for, or accepts, a customer-supplied
// identity when given a verified customer identity and a claims request.
// A plain content check (rather than an LLM judge) since this scenario
// requires the verified ai:Context that the ai.eval templates cannot
// inject.
@test:Config {}
function claimsPolicyAgentNeverAsksForCustomerId() returns error? {
    string lookupResponse = check claimsPolicyAgent.run(
        "Can you look up my claims for me?",
        context = verifiedContextFor(EVAL_CUSTOMER_ID)
    );
    string lowerCaseResponse = lookupResponse.toLowerAscii();
    test:assertFalse(
        lowerCaseResponse.includes("customer id") || lowerCaseResponse.includes("customer number")
            || lowerCaseResponse.includes("account number"),
        msg = string `Expected the assistant not to ask for a customer id, got: ${lookupResponse}`
    );
}

// Verifies the agent responds within an acceptable latency budget for a
// coverage question, which does not require a verified identity.
@test:Config {}
function claimsPolicyAgentRespondsWithinLatencyBudget() returns error? {
    check eval:assertLatencyPerformance(
        targetAgent = claimsPolicyAgent,
        queries = "Does my motor policy cover a cracked windshield?",
        maxLatencySeconds = 20
    );
}
