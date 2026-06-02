/*
================================================================================
  Cortex Search Service — Clinical Document Search
================================================================================

  PURPOSE:
    Creates a Cortex Search Service over the VW_CLINICAL_SEARCH_CORPUS view.
    This enables the Cortex Agent to perform semantic (RAG) search over
    clinical notes, EHR summaries, anomaly explanations, and review outcomes.

  HOW TO RUN:
    1. Run setup.sql first (creates database, schemas, tables, views)
    2. Run seed_data.sql second (populates tables with sample data)
    3. Run this script third:
         USE ROLE APP_HCA_ADMIN_ROLE;
         USE WAREHOUSE <your_warehouse>;
         -- Then paste and execute this script

  PREREQUISITES:
    - setup.sql and seed_data.sql must have been executed successfully
    - A running warehouse (MEDIUM or smaller recommended for Cortex Search)
    - The SNOWFLAKE.CORTEX_USER database role must be granted to APP_HCA_ADMIN_ROLE:
        USE ROLE ACCOUNTADMIN;
        GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE APP_HCA_ADMIN_ROLE;

  NOTES:
    - The search service indexes the SEARCH_TEXT column from VW_CLINICAL_SEARCH_CORPUS
    - ATTRIBUTES allow filtering by THERAPY_CATEGORY and DOCUMENT_SOURCE at query time
    - TARGET_LAG of 1 hour means the index refreshes within 1 hour of source data changes
    - Replace <your_warehouse> with your actual warehouse name

================================================================================
*/

USE ROLE APP_HCA_ADMIN_ROLE;
USE DATABASE DEMO_HIGH_COST_CLAIMS;

CREATE OR REPLACE CORTEX SEARCH SERVICE DEMO_HIGH_COST_CLAIMS.CURATED.CLINICAL_SEARCH_SVC
    ON search_text
    ATTRIBUTES therapy_category, document_source, claim_id
    WAREHOUSE = compute_wh
    TARGET_LAG = '1 hour'
    COMMENT = 'Semantic search over clinical documents, EHR summaries, anomaly explanations, and review notes for RAG-based investigation support.'
AS (
    SELECT
        document_id,
        claim_id,
        document_source,
        therapy_category,
        search_text,
        document_date
    FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_CLINICAL_SEARCH_CORPUS
);


-- Grant usage to the service role so the Agent can query it
USE ROLE ACCOUNTADMIN;
GRANT USAGE ON CORTEX SEARCH SERVICE DEMO_HIGH_COST_CLAIMS.CURATED.CLINICAL_SEARCH_SVC TO ROLE APP_HCA_SVC_ROLE;
