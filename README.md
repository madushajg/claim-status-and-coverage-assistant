
# Claims Status and Coverage Assistant

A read-only AI assistant that combines live claims data from APIs with grounded insurance policy explanations from a RAG knowledge base.

The assistant helps customers answer questions such as:

- What is happening with my claim?
- What has happened since my claim was reported?
- Is windshield damage covered?
- Which policy clause supports that answer?

The assistant must verify the customer's identity and claim ownership before disclosing claim or policy information.

## Scenario

**Scenario:** S-03: Claims Status and Coverage Assistant  
**Assignee:** Madusha Gunasekara  
**Estimated duration:** 90–120 minutes, assuming the shared claims baseline is prepared  
**Platforms:** macOS and Windows  
**Validation:** Conditional AI/API/RAG end-to-end  
**Agent authority:** Read-only

## Objective

Build an AI-powered claims assistant that:

1. Retrieves current claim status and timeline information from a Claims API.
2. Retrieves customer policy information from the Claims API.
3. Uses RAG to answer policy and coverage questions from approved policy documents.
4. Provides source-document and clause references for coverage answers.
5. Refuses to disclose information when customer identity or claim ownership cannot be established.
6. Refuses requests to approve, reject, create, or modify claims or policies.

## Architecture

```text
                         Customer
                            |
                            v
                    Claims Policy Agent
                            |
              +-------------+-------------+
              |                           |
              v                           v
         Claims MCP                  Claims RAG
              |                           |
              v                           v
         Claims HTTP API          Policy Documents
              |                    + Coverage Guides
              v                    + Exclusions
         PostgreSQL                + Process FAQs
              |
              v
       Current Claims Data
```

### Component responsibilities

| Component | Responsibility |
|---|---|
| **PostgreSQL** | Stores customers, policies, claims, and claim timeline events |
| **Claims API** | Exposes read-only resources backed by PostgreSQL |
| **Claims MCP** | Exposes typed tools for claim and policy operations |
| **Claims RAG** | Retrieves relevant policy passages from local Markdown documents |
| **Claims Policy Agent** | Orchestrates MCP tools and RAG to answer customer questions |
| **Tracing and Evaluation** | Verifies tool selection, grounding, authorization, and refusal behavior |

## Data boundaries

The assistant uses two different sources of truth.

### Live operational data

Used for questions about the current state of a claim:

- Claim status
- Claim timeline
- Customer policy information

Source:

```text
PostgreSQL → Claims API → Claims MCP
```

### Policy knowledge

Used for questions about coverage, exclusions, and insurance processes:

- Policy wording
- Coverage guides
- Exclusions
- Claims process FAQs

Source:

```text
Markdown documents → RAG ingestion → Vector knowledge base
```

**Important:** Do not use RAG to answer questions about the current claim status or timeline. Those answers must come from the Claims API.

Likewise, do not expect PostgreSQL claim records to contain the full policy wording. Policy explanations should be grounded in the RAG knowledge base.

## Prerequisites

Install or configure the following:

- PostgreSQL
- Ballerina / Integrator development environment
- An approved AI model provider
- An approved embedding provider
- Access to the required AI, API, RAG, and MCP capabilities
- A local development environment on macOS or Windows

## Project structure

A suggested structure for the tutorial is:

```text
claims-status-assistant/
├── README.md
├── db/
│   └── 001_claims_demo.sql
├── api/
│   └── ...
├── rag/
│   └── documents/
│       ├── POL-1001-MOTOR-COVERAGE.md
│       ├── motor-coverage-guide.md
│       ├── motor-exclusions.md
│       └── claims-process-faq.md
├── mcp/
│   └── ...
└── agent/
    └── ...
```

The exact project layout may vary depending on the selected Integrator project structure.

# Step 1: Prepare the claims data

## Goal

Create a small PostgreSQL database that supports the Claims API and ownership validation.

The baseline contains:

- Customer `C-100`
- Customer `C-200` for authorization testing
- Policy `POL-1001`
- Claim `CLM-1001`
- Three claim timeline events

## Database relationships

```text
Customer C-100
    |
    +── Policy POL-1001
    |
    └── Claim CLM-1001
             |
             +── Policy POL-1001
             |
             └── Claim timeline events
```

The critical relationship is:

```text
CLM-1001 → C-100 → POL-1001
```

The claim must belong to customer `C-100`, and the referenced policy must also belong to `C-100`.

## Create the database

```bash
createdb claims_demo
```

If the database already exists, connect to it:

```bash
psql claims_demo
```

## Load the sample data

Run the SQL baseline:

```bash
psql claims_demo -f db/001_claims_demo.sql
```

The SQL script creates:

```text
customers
policies
claims
claim_timeline
```

It also inserts the sample data and runs verification queries.

## Verify the baseline

Verify that the claim exists:

```sql
SELECT *
FROM claims
WHERE claim_id = 'CLM-1001';
```

Verify ownership:

```sql
SELECT
    c.claim_id,
    c.customer_id AS claim_customer_id,
    c.policy_number,
    p.customer_id AS policy_customer_id
FROM claims c
JOIN policies p
    ON p.policy_number = c.policy_number
WHERE c.claim_id = 'CLM-1001';
```

Expected relationship:

```text
claim_id   claim_customer_id   policy_number   policy_customer_id
CLM-1001   C-100               POL-1001        C-100
```

Verify the timeline:

```sql
SELECT event_time, event
FROM claim_timeline
WHERE claim_id = 'CLM-1001'
ORDER BY event_time;
```

# Step 2: Build the Claims HTTP API

## Goal

Expose read-only HTTP resources backed by PostgreSQL.

### Required resources

| Method | Resource | Purpose |
|---|---|---|
| `GET` | `/claims/{claimId}` | Retrieve the current claim status |
| `GET` | `/claims/{claimId}/timeline` | Retrieve the claim timeline |
| `GET` | `/customers/{customerId}/policies` | Retrieve policies belonging to a customer |

## API behavior

The API must:

1. Require a test customer identity or access token.
2. Extract the authenticated customer identity.
3. Validate that the requested claim or policy belongs to that customer.
4. Return the requested data only after ownership is verified.
5. Return a consistent authorization error when access is not permitted.
6. Avoid revealing whether another customer's claim or policy exists.

## Example authenticated identity

For the demo, use a test identity such as:

```text
customer_id: C-100
```

This identity is only for demonstrating the authorization flow. It should not be treated as a production authentication mechanism.

## Example requests

### Get claim status

```http
GET /claims/CLM-1001
Authorization: Bearer <test-token>
```

Expected response:

```json
{
  "claimId": "CLM-1001",
  "customerId": "C-100",
  "policyNumber": "POL-1001",
  "status": "UNDER_REVIEW",
  "reportedAt": "2026-01-20T09:00:00Z",
  "slaDueAt": "2026-01-27T09:00:00Z",
  "assignedTeam": "Motor Claims"
}
```

### Get claim timeline

```http
GET /claims/CLM-1001/timeline
Authorization: Bearer <test-token>
```

Expected response:

```json
[
  {
    "time": "2026-01-20T09:00:00Z",
    "event": "CLAIM_REGISTERED"
  },
  {
    "time": "2026-01-21T12:30:00Z",
    "event": "DOCUMENTS_RECEIVED"
  },
  {
    "time": "2026-01-23T10:15:00Z",
    "event": "ASSESSMENT_STARTED"
  }
]
```

### Get customer policies

```http
GET /customers/C-100/policies
Authorization: Bearer <test-token>
```

Expected response:

```json
[
  {
    "policyNumber": "POL-1001",
    "customerId": "C-100",
    "policyProduct": "MOTOR",
    "policyVersion": "2026.1",
    "effectiveDate": "2026-01-01"
  }
]
```

## Authorization test

Attempt to retrieve `CLM-1001` using customer identity `C-200`.

Expected behavior:

```text
403 Forbidden
```

The response must not reveal claim details or confirm whether the claim belongs to another customer.

# Step 3: Prepare the policy knowledge documents

## Goal

Create local Markdown documents containing the policy wording and supporting claims information.

These documents will be ingested into the RAG knowledge base.

## Suggested documents

```text
rag/documents/
├── POL-1001-MOTOR-COVERAGE.md
├── motor-coverage-guide.md
├── motor-exclusions.md
└── claims-process-faq.md
```

## Document metadata

Each document should include metadata such as:

- Policy product
- Policy version
- Clause
- Effective date
- Source document

This metadata allows the RAG query function to retrieve passages from the correct policy product and version.

## Example policy document

Create `POL-1001-MOTOR-COVERAGE.md`:

```markdown
---
source: POL-1001-MOTOR-COVERAGE.md
policyProduct: MOTOR
policyVersion: "2026.1"
policyNumber: POL-1001
effectiveDate: 2026-01-01
---

# Motor Policy Coverage

## Clause 4.2 Windscreen Cover

Accidental damage to the front, rear, or side windscreen is covered when
windscreen cover is included in the policy schedule.

The standard excess applies unless the repair is completed through an
approved repair partner.
```

## Additional example document

Create `claims-process-faq.md`:

```markdown
---
source: claims-process-faq.md
policyProduct: MOTOR
policyVersion: "2026.1"
effectiveDate: 2026-01-01
---

# Claims Process FAQs

## How long does a claim assessment take?

Claim assessment timelines depend on the type of claim, the documents
received, and the complexity of the assessment.

Customers should refer to the latest claim timeline for the current
progress of an individual claim.
```

**Important:** The RAG documents should contain the actual knowledge needed to answer the question. Do not add unsupported coverage statements just to make the demo pass.

# Step 4: Create the RAG ingestion flow

## Goal

Load the local Markdown documents into a vector knowledge base.

## Required configuration

1. Add a text data loader.
2. Configure the local Markdown document directory.
3. Configure an in-memory vector store for the tutorial.
4. Configure an approved embedding provider.
5. Create a vector knowledge base.
6. Ingest the policy documents.

## Ingestion flow

```text
Local Markdown Files
        |
        v
Text Data Loader
        |
        v
Document Chunking
        |
        v
Embedding Provider
        |
        v
In-Memory Vector Store
        |
        v
Claims Knowledge Base
```

## Retrieval requirements

The RAG flow should support filtering or constraining retrieval by:

- Policy product
- Policy version
- Relevant policy identifier, when available

For example, a question about `POL-1001` should retrieve passages relevant to the `MOTOR` policy product and version `2026.1`.

# Step 5: Create the RAG query function

## Goal

Accept a coverage question, retrieve relevant policy passages, and generate a grounded answer.

## Suggested inputs

```text
question
policyNumber
policyProduct
policyVersion
```

## Suggested output

```json
{
  "answer": "Accidental damage to the front, rear, or side windscreen is covered when windscreen cover is included in the policy schedule. The standard excess applies unless the repair is completed through an approved repair partner.",
  "sources": [
    {
      "source": "POL-1001-MOTOR-COVERAGE.md",
      "clause": "4.2 Windscreen Cover",
      "policyNumber": "POL-1001",
      "policyProduct": "MOTOR",
      "policyVersion": "2026.1"
    }
  ]
}
```

The exact response structure may vary, but the result must include enough metadata to identify the source document and clause.

## RAG behavior

The query function must:

1. Retrieve passages relevant to the question.
2. Restrict retrieval to the correct policy product and version.
3. Generate an answer grounded in the retrieved passages.
4. Return source-document and clause references.
5. State when the retrieved evidence is insufficient.
6. Avoid inventing coverage details.

# Step 6: Create the Claims MCP service

## Goal

Expose the claims capabilities as typed, read-only MCP tools.

Create a stateless MCP service at:

```text
/claims-mcp
```

## Required tools

| Tool | Purpose |
|---|---|
| `getClaimStatus` | Retrieve the current status of a claim |
| `getClaimTimeline` | Retrieve the timeline of a claim |
| `getCustomerPolicy` | Retrieve policies belonging to a customer |
| `answerCoverageQuestion` | Answer a policy or coverage question using RAG |

## Tool responsibilities

### `getClaimStatus`

Use when the customer asks about:

- Current claim status
- Assigned team
- Reported date
- SLA due date

### `getClaimTimeline`

Use when the customer asks:

- What has happened?
- What documents were received?
- What steps have been completed?
- What happened since the claim was reported?

### `getCustomerPolicy`

Use when the customer asks about:

- Their policy information
- Policy number
- Policy product
- Policy version
- Policies associated with their customer account

### `answerCoverageQuestion`

Use when the customer asks:

- Is something covered?
- What does the policy say?
- What exclusions apply?
- Which clause supports the answer?

## MCP security requirements

Every data-access tool must:

1. Receive or validate the authenticated customer identity.
2. Verify ownership before returning customer-specific information.
3. Return a consistent authorization error when ownership cannot be established.
4. Avoid exposing another customer's claim or policy details.

The MCP service must not bypass the authorization checks implemented by the Claims API.

# Step 7: Create the Claims Policy Agent

## Goal

Create an AI Chat Agent that uses the Claims MCP service and the Claims RAG capability to answer customer questions.

## Agent configuration

1. Add an AI Chat Agent.
2. Attach the Claims MCP server.
3. Permit only the four read-oriented tools.
4. Configure an appropriate model provider.
5. Configure a maximum iteration limit.
6. Enable tracing.

## Allowed tools

```text
getClaimStatus
getClaimTimeline
getCustomerPolicy
answerCoverageQuestion
```

No write tools should be exposed.

## Suggested agent instructions

```text
You are a read-only Claims Policy Assistant.

Your responsibilities:
- Help customers understand the current status and timeline of their claims.
- Answer policy and coverage questions using the approved knowledge base.
- Use the Claims MCP tools for current claim and policy information.
- Use RAG for policy wording, coverage explanations, exclusions, and claims
  process information.
- Verify customer identity and claim ownership before disclosing claim or
  policy information.
- Do not reveal information belonging to another customer.
- Do not approve, reject, create, or modify claims or policies.
- Include the source document and clause reference for coverage answers.
- Clearly distinguish live claim data from policy information retrieved through
  RAG.
- If the knowledge base does not contain sufficient evidence, state that the
  available policy information is insufficient and do not invent an answer.
```

## Tool-selection behavior

| Customer question | Required capability |
|---|---|
| What is the status of claim CLM-1001? | `getClaimStatus` |
| What has happened since this claim was reported? | `getClaimTimeline` |
| Which policies do I have? | `getCustomerPolicy` |
| Does policy POL-1001 cover windshield replacement? | `answerCoverageQuestion` |
| Which clause supports that answer? | `answerCoverageQuestion` |

# Step 8: Configure identity and authorization behavior

## Goal

Ensure the assistant does not disclose sensitive information without verified identity and ownership.

The authorization flow should be:

```text
Customer Request
      |
      v
Authenticated Customer Identity
      |
      v
Claims API / MCP Authorization Check
      |
      +── Ownership verified ──> Return data
      |
      └── Ownership not verified ──> Refuse
```

## Required behavior

### Verified customer

Customer `C-100` requests claim `CLM-1001`.

Expected:

```text
Return the claim status or timeline.
```

### Unverified identity

A request is made without a valid customer identity.

Expected:

```text
Do not disclose claim or policy information.
```

### Wrong customer

Customer `C-200` requests claim `CLM-1001`.

Expected:

```text
Return a consistent authorization error.
Do not reveal claim details or confirm whether another customer's claim exists.
```

### Unsupported write request

Customer asks:

```text
Approve claim CLM-1001 for me.
```

Expected:

```text
Refuse because the assistant is read-only and cannot approve claims.
```

# Step 9: Enable tracing and evaluation

## Tracing

Enable agent tracing to inspect:

- User request
- Agent reasoning and tool selection
- MCP tool calls
- Claims API calls
- RAG retrieval
- Retrieved passages
- Final response

Use tracing to verify that:

- Current claim information comes from the API.
- Coverage answers come from RAG.
- Authorization checks happen before sensitive data is returned.
- The agent does not call unauthorized write operations.

## Trace correlation

API, MCP, RAG, and agent traces should be correlated for the same request.

A useful correlation flow is:

```text
Agent Request ID
      |
      +── MCP Request ID
      |
      +── Claims API Request ID
      |
      └── RAG Query ID
```

## Sensitive data

Verify that sensitive customer and claim values are not unnecessarily retained in traces.

Use test identities and sample data for the tutorial.

# Step 10: Test the scenario

## Test 1: Current claim status

**Question**

```text
What is the status of claim CLM-1001?
```

**Expected behavior**

- Authenticate the customer.
- Verify ownership.
- Call `getClaimStatus`.
- Retrieve the current status from the Claims API.
- Return `UNDER_REVIEW`.

The agent must not invent a status.

## Test 2: Claim timeline

**Question**

```text
What has happened since this claim was reported?
```

**Expected behavior**

- Call `getClaimTimeline`.
- Retrieve the timeline from the Claims API.
- Summarize the returned events.
- Do not invent additional events.

## Test 3: Coverage question

**Question**

```text
Does policy POL-1001 cover windshield replacement?
```

**Expected behavior**

- Identify the relevant policy.
- Call `answerCoverageQuestion`.
- Retrieve the relevant policy passage through RAG.
- Explain the coverage conditions.
- Include the source document and clause reference.

Expected source:

```text
POL-1001-MOTOR-COVERAGE.md
Clause 4.2 Windscreen Cover
```

## Test 4: Clause reference

**Question**

```text
Which policy clause supports that answer?
```

**Expected behavior**

Return the relevant source and clause:

```text
Source: POL-1001-MOTOR-COVERAGE.md
Clause: 4.2 Windscreen Cover
```

## Test 5: Unauthorized claim access

**Question**

```text
What is the status of claim CLM-1001?
```

**Authenticated identity**

```text
C-200
```

**Expected behavior**

- Reject the request.
- Do not return claim details.
- Do not confirm whether the claim belongs to another customer.
- Return a consistent authorization error.

## Test 6: Unsupported write operation

**Question**

```text
Approve claim CLM-1001 for me.
```

**Expected behavior**

Refuse because the assistant is read-only and cannot approve, reject, create, or modify claims or policies.

## Test 7: Insufficient RAG evidence

**Question**

```text
Does policy POL-1001 cover damage caused by an earthquake?
```

**Expected behavior**

If the knowledge base does not contain sufficient evidence:

- State that the available policy information is insufficient.
- Do not invent a coverage decision.
- Do not claim that the damage is covered or excluded without evidence.

# Expected outcomes

The completed assistant should demonstrate that:

- Current claim status is retrieved from the Claims API.
- Current claim timeline is retrieved from the Claims API.
- Policy explanations are grounded in RAG.
- Coverage answers include source-document and clause references.
- The assistant distinguishes live operational data from policy knowledge.
- A customer who does not own a claim receives no claim or policy details.
- The agent refuses write operations.
- The agent states when evidence is insufficient.
- API, MCP, RAG, and agent traces can be correlated.

# Implementation checklist

## Claims data

- [ ] PostgreSQL is running locally.
- [ ] `claims_demo` database exists.
- [ ] Customers, policies, claims, and timeline tables are created.
- [ ] `CLM-1001` belongs to `C-100`.
- [ ] `CLM-1001` references `POL-1001`.
- [ ] `POL-1001` belongs to `C-100`.
- [ ] Timeline events are loaded and verified.

## Claims API

- [ ] `GET /claims/{claimId}` implemented.
- [ ] `GET /claims/{claimId}/timeline` implemented.
- [ ] `GET /customers/{customerId}/policies` implemented.
- [ ] Test customer identity or access token supported.
- [ ] Ownership validation implemented.
- [ ] Consistent authorization error implemented.
- [ ] No unauthorized data disclosure.

## RAG

- [ ] Policy documents created as local Markdown.
- [ ] Metadata added to documents.
- [ ] Text data loader configured.
- [ ] In-memory vector store configured.
- [ ] Approved embedding provider configured.
- [ ] Documents ingested.
- [ ] Correct policy product and version used for retrieval.
- [ ] Source and clause metadata returned.
- [ ] Insufficient evidence handled correctly.

## MCP

- [ ] MCP service available at `/claims-mcp`.
- [ ] `getClaimStatus` exposed.
- [ ] `getClaimTimeline` exposed.
- [ ] `getCustomerPolicy` exposed.
- [ ] `answerCoverageQuestion` exposed.
- [ ] Tools are typed and read-only.
- [ ] Identity propagated or validated.
- [ ] Ownership checks enforced.

## Agent

- [ ] AI Chat Agent created.
- [ ] Claims MCP server attached.
- [ ] Only four read-oriented tools permitted.
- [ ] Model provider configured.
- [ ] Maximum iteration limit configured.
- [ ] Read-only behavior configured.
- [ ] API required for current claim data.
- [ ] RAG required for policy explanations.
- [ ] Source and clause references required.
- [ ] Refusal behavior configured.

## Validation

- [ ] Claim status test passed.
- [ ] Claim timeline test passed.
- [ ] Coverage question test passed.
- [ ] Clause reference test passed.
- [ ] Unauthorized customer test passed.
- [ ] Write-operation refusal test passed.
- [ ] Insufficient-evidence test passed.
- [ ] Tracing enabled.
- [ ] Sensitive values reviewed in traces.
- [ ] API, MCP, RAG, and agent traces correlated.

# Notes

This tutorial intentionally uses a small local dataset and an in-memory vector store to keep the implementation focused.

For production, replace the test identity mechanism, local database setup, and in-memory vector store with appropriate production-grade authentication, data storage, authorization, and retrieval infrastructure.