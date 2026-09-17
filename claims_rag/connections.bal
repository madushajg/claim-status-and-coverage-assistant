import ballerina/ai;

// Embedding provider used to generate vector embeddings for the policy
// knowledge documents and for coverage questions at query time.
final ai:Wso2EmbeddingProvider policyEmbeddingProvider = check new (
    serviceUrl = embeddingServiceUrl,
    accessToken = embeddingAccessToken
);

// In-memory vector store backing the claims policy knowledge base. This is
// suitable for this tutorial only; production deployments should use a
// persistent vector store.
final ai:InMemoryVectorStore policyVectorStore = check new ();

// Vector knowledge base composing the vector store and embedding provider.
// Chunking is handled automatically ("AUTO") based on document type.
final ai:VectorKnowledgeBase claimsKnowledgeBase = new (policyVectorStore, policyEmbeddingProvider);
