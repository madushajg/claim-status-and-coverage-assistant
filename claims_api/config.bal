// Database connection configuration for the claims_demo PostgreSQL database.
configurable string dbHost = "localhost";
configurable int dbPort = 5432;
configurable string dbUsername = ?;
configurable string dbPassword = ?;
configurable string dbDatabase = "claims_demo";

// HTTP listener configuration for the Claims API.
configurable int servicePort = 8080;
