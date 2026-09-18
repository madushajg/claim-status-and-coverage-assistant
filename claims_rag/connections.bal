import ballerina/ai;

// Embedding provider used to generate vector embeddings for the policy
// knowledge documents and for coverage questions at query time. Uses the
// default WSO2 provider configuration (the [ballerina.ai.wso2ProviderConfig]
// block maintained by the "Configure default WSO2 Model Provider" VS Code
// command) so both the embedding and chat model providers always read the
// same, freshly-issued serviceUrl/accessToken pair.
final ai:Wso2EmbeddingProvider policyEmbeddingProvider = check ai:getDefaultEmbeddingProvider();

// In-memory vector store backing the claims policy knowledge base. This is
// suitable for this tutorial only; production deployments should use a
// persistent vector store.
final ai:InMemoryVectorStore policyVectorStore = check new ();

// Chat model provider used to generate grounded answers to coverage
// questions from the retrieved policy passages.
final ai:Wso2ModelProvider policyModelProvider = check ai:getDefaultModelProvider();

// Chunker used to split each policy document by markdown headers so that
// clause headings become their own chunks, captured in chunk metadata
// (header/header1-header6) for source/clause references. Documents are
// chunked explicitly (see loadPolicyChunks) so that the policy-level
// metadata (policyProduct/policyVersion/policyNumber/source) can be
// re-attached to each chunk before ingestion.
final ai:MarkdownChunker policyMarkdownChunker = new ();

// Vector knowledge base composing the vector store and embedding provider.
// Chunking is DISABLED here because chunks are pre-built and tagged with
// policy metadata by loadPolicyChunks before being passed to ingest();
// letting the knowledge base chunk again would discard that metadata.
final ai:VectorKnowledgeBase claimsKnowledgeBase = new (policyVectorStore, policyEmbeddingProvider, "DISABLE");
