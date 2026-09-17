
-- Claims Status and Coverage Assistant
-- Demo database baseline
-- PostgreSQL
--
-- Run this script inside the claims_demo database:
-- psql claims_demo -f 001_claims_demo.sql

BEGIN;

-- ------------------------------------------------------------
-- Reset demo tables
-- ------------------------------------------------------------
-- Drop child tables first because of foreign-key dependencies.

DROP TABLE IF EXISTS claim_timeline;
DROP TABLE IF EXISTS claims;
DROP TABLE IF EXISTS policies;
DROP TABLE IF EXISTS customers;

-- ------------------------------------------------------------
-- Customers
-- ------------------------------------------------------------

CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    full_name TEXT NOT NULL
);

-- ------------------------------------------------------------
-- Policies
-- ------------------------------------------------------------

CREATE TABLE policies (
    policy_number VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL
        REFERENCES customers(customer_id),
    policy_product TEXT NOT NULL,
    policy_version TEXT NOT NULL,
    effective_date DATE NOT NULL
);

-- ------------------------------------------------------------
-- Claims
-- ------------------------------------------------------------

CREATE TABLE claims (
    claim_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL
        REFERENCES customers(customer_id),
    policy_number VARCHAR(50) NOT NULL
        REFERENCES policies(policy_number),
    status VARCHAR(50) NOT NULL,
    reported_at TIMESTAMPTZ NOT NULL,
    sla_due_at TIMESTAMPTZ NOT NULL,
    assigned_team TEXT NOT NULL
);

-- ------------------------------------------------------------
-- Claim timeline
-- ------------------------------------------------------------

CREATE TABLE claim_timeline (
    id BIGSERIAL PRIMARY KEY,
    claim_id VARCHAR(50) NOT NULL
        REFERENCES claims(claim_id),
    event_time TIMESTAMPTZ NOT NULL,
    event VARCHAR(100) NOT NULL
);

-- ------------------------------------------------------------
-- Sample customers
-- ------------------------------------------------------------

INSERT INTO customers (customer_id, full_name)
VALUES
    ('C-100', 'Test Customer'),
    ('C-200', 'Other Test Customer');

-- ------------------------------------------------------------
-- Sample policy
-- ------------------------------------------------------------

INSERT INTO policies (
    policy_number,
    customer_id,
    policy_product,
    policy_version,
    effective_date
)
VALUES (
    'POL-1001',
    'C-100',
    'MOTOR',
    '2026.1',
    '2026-01-01'
);

-- ------------------------------------------------------------
-- Sample claim
-- ------------------------------------------------------------

INSERT INTO claims (
    claim_id,
    customer_id,
    policy_number,
    status,
    reported_at,
    sla_due_at,
    assigned_team
)
VALUES (
    'CLM-1001',
    'C-100',
    'POL-1001',
    'UNDER_REVIEW',
    '2026-01-20T09:00:00Z',
    '2026-01-27T09:00:00Z',
    'Motor Claims'
);

-- ------------------------------------------------------------
-- Sample claim timeline
-- ------------------------------------------------------------

INSERT INTO claim_timeline (
    claim_id,
    event_time,
    event
)
VALUES
    (
        'CLM-1001',
        '2026-01-20T09:00:00Z',
        'CLAIM_REGISTERED'
    ),
    (
        'CLM-1001',
        '2026-01-21T12:30:00Z',
        'DOCUMENTS_RECEIVED'
    ),
    (
        'CLM-1001',
        '2026-01-23T10:15:00Z',
        'ASSESSMENT_STARTED'
    );

COMMIT;

-- ------------------------------------------------------------
-- Verification queries
-- ------------------------------------------------------------

-- 1. Verify the claim and its ownership relationship.
SELECT
    c.claim_id,
    c.customer_id,
    c.policy_number,
    c.status,
    c.reported_at,
    c.sla_due_at,
    c.assigned_team
FROM claims c
WHERE c.claim_id = 'CLM-1001';

-- 2. Verify the claim -> policy -> customer relationship.
SELECT
    c.claim_id,
    c.customer_id AS claim_customer_id,
    c.policy_number,
    p.customer_id AS policy_customer_id,
    p.policy_product,
    p.policy_version
FROM claims c
JOIN policies p
    ON p.policy_number = c.policy_number
WHERE c.claim_id = 'CLM-1001';

-- 3. Verify the timeline.
SELECT
    event_time,
    event
FROM claim_timeline
WHERE claim_id = 'CLM-1001'
ORDER BY event_time;

-- 4. Verify the second customer exists for authorization testing.
SELECT *
FROM customers
ORDER BY customer_id;
