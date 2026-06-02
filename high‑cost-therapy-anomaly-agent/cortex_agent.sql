/*
================================================================================
  Cortex Agent — High Cost Therapy Anomaly Investigator
================================================================================

  PURPOSE:
    Creates the Cortex Agent that uses:
      1. A Semantic View (Cortex Analyst) for structured SQL queries against
         the ANALYTICS and CURATED views
      2. A Cortex Search Service for unstructured clinical document RAG

  HOW TO RUN:
    1. Run setup.sql (creates database objects)
    2. Run seed_data.sql (loads sample data)
    3. Run cortex_search.sql (creates the search service)
    4. Run semantic_view.sql (creates the semantic view)
    5. Run this script LAST:
         USE ROLE APP_HCA_ADMIN_ROLE;
         USE WAREHOUSE <your_warehouse>;

  PREREQUISITES:
    - All prior scripts must have completed successfully
    - Cross-region inference may need to be enabled:
        ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
    - The SNOWFLAKE.CORTEX_USER database role must be granted to APP_HCA_ADMIN_ROLE

  AFTER CREATION:
    - The agent will appear in Snowflake Intelligence (Snowsight > AI & ML > Agents)
    - You can also query it via the REST API or SQL DATA_AGENT_RUN function
    - Grant usage to end users:
        GRANT USAGE ON AGENT DEMO_HIGH_COST_CLAIMS.CURATED.HCA_INVESTIGATOR_AGENT TO ROLE <user_role>;

================================================================================
*/

USE ROLE APP_HCA_ADMIN_ROLE;
USE DATABASE DEMO_HIGH_COST_CLAIMS;
USE SCHEMA CURATED;

CREATE OR REPLACE AGENT DEMO_HIGH_COST_CLAIMS.CURATED.HCA_INVESTIGATOR_AGENT
  COMMENT = 'High Cost Therapy Anomaly Investigator - answers questions about flagged claims, provider outliers, overpayment cases, and clinical documentation using structured analytics and unstructured clinical search.'
  FROM SPECIFICATION
$$
models:
  orchestration: auto

instructions:
  response: |
    You are a Payment Integrity Analyst AI assistant specialized in high-cost therapy claims.
    You help investigators understand anomaly detection results, overpayment cases,
    provider billing patterns, and clinical documentation completeness.

    When answering:
    - Be specific with dollar amounts, percentages, and claim IDs.
    - If a question is about a specific claim or provider, include relevant details like
      therapy category, anomaly type, and anomaly score.
    - When discussing anomalies, explain what the anomaly type means in plain language.
    - For recovery questions, include both amounts sought and amounts recovered.
    - Present tabular data when comparing multiple items.

  orchestration: |
    Use the Analyst tool for questions about:
    - Claim counts, amounts, and financial summaries
    - Provider outlier rankings and anomaly rates
    - Case statuses, priorities, and reviewer assignments
    - Recovery amounts and statuses
    - Model feedback and precision metrics
    - Any question that requires aggregation, filtering, or joining structured data

    Use the Clinical Search tool for questions about:
    - Clinical justification for a specific treatment
    - EHR summaries and treatment indications
    - Document availability and extraction summaries
    - Anomaly explanation narratives
    - Clinical review notes and decisions

sample_questions:
  - question: "Which claims have the highest anomaly scores and what type of anomaly was detected?"
  - question: "Show me all open high-priority cases that need reviewer assignment"
  - question: "What is the total estimated overpayment across all flagged claims?"
  - question: "Which providers have the highest anomaly rates compared to their peers?"
  - question: "What clinical documentation is missing for the CAR-T therapy cases?"
  - question: "Summarize the clinical justification for claim CLM-2026-0002"

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "HighCostClaimsAnalyst"
      description: |
        Answers structured data questions about high-cost therapy claims, anomaly
        detection results, overpayment investigations, provider billing patterns,
        case management, clinical reviews, recovery actions, and model feedback.
        Use this for any question requiring counts, sums, averages, rankings,
        filtering by status/priority/therapy category, or comparing providers.
  - tool_spec:
      type: "cortex_search"
      name: "ClinicalDocSearch"
      description: |
        Searches clinical documents including EHR summaries, prior authorizations,
        lab results, pathology reports, anomaly explanations, and clinical review
        notes. Use this for questions about clinical justification, treatment
        indications, document content, or narrative explanations of anomalies.

tool_resources:
  HighCostClaimsAnalyst:
    semantic_view: "DEMO_HIGH_COST_CLAIMS.ANALYTICS.HCA_SEMANTIC_VIEW"
  ClinicalDocSearch:
    name: "DEMO_HIGH_COST_CLAIMS.CURATED.CLINICAL_SEARCH_SVC"
    max_results: "5"
    title_column: "document_source"
    id_column: "document_id"
$$;

-- Grant usage so the service role can invoke the agent
USE ROLE ACCOUNTADMIN;
GRANT USAGE ON AGENT DEMO_HIGH_COST_CLAIMS.CURATED.HCA_INVESTIGATOR_AGENT TO ROLE APP_HCA_SVC_ROLE;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE APP_HCA_SVC_ROLE;
