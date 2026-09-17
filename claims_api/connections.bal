import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;

final postgresql:Client claimsDbClient = check new (
    host = dbHost,
    username = dbUsername,
    password = dbPassword,
    database = dbDatabase,
    port = dbPort
);
