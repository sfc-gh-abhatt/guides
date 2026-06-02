# High-Cost Therapy Anomaly Agent

A complete Snowflake setup for a **Payment Integrity** pipeline that detects anomalous high-cost therapy claims using ML scoring, investigates them, and tracks overpayment recovery — all queryable by a **Cortex Agent**.

---

## What You Get

| Component | Description |
|-----------|-------------|
| **Database** | `DEMO_HIGH_COST_CLAIMS` with 4 schemas (RAW, REF, CURATED, ANALYTICS) |
| **20 tables** | Reference data, raw claims, ML scores, cases, reviews, recoveries |
| **8 analytics views** | Pre-joined views optimized for agent queries |
| **Cortex Search Service** | Semantic search over clinical documents and anomaly explanations |
| **Semantic View** | Teaches Cortex Analyst how to query your structured data |
| **Cortex Agent** | The AI investigator that answers natural language questions |

---

## Prerequisites

Before you start, ensure you have:

1. **A Snowflake account** (any edition — Standard, Enterprise, or Business Critical)
2. **ACCOUNTADMIN role** (or a role that can create roles and databases)
3. **A running warehouse** (the scripts use `compute_wh` — change if yours is different)
4. **Cross-region inference enabled** (recommended for best model availability):
   ```sql
   ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
   ```

---

## Step-by-Step Setup

Run each script **in order**. Each script contains detailed instructions at the top.

### Step 1: Create Database Objects

```sql
-- Open a SQL Worksheet in Snowsight, paste setup.sql, and Run All
```

**File:** [`setup.sql`](setup.sql)

This creates:
- `APP_HCA_ADMIN_ROLE` (owns everything) and `APP_HCA_SVC_ROLE` (for app access)
- The database, 4 schemas, all tables, and all views

### Step 2: Load Sample Data

```sql
USE ROLE APP_HCA_ADMIN_ROLE;
USE WAREHOUSE compute_wh;
-- Paste seed_data.sql and Run All
```

**File:** [`seed_data.sql`](seed_data.sql)

Loads 15 claims, 27 claim lines, 24 documents, 8 EHR summaries, 15 anomaly results, 6 cases, 4 reviews, 2 recoveries, and all reference data.

### Step 3: Create Cortex Search Service

```sql
USE ROLE APP_HCA_ADMIN_ROLE;
USE WAREHOUSE compute_wh;
-- Paste cortex_search.sql and Run All
```

**File:** [`cortex_search.sql`](cortex_search.sql)

Creates a semantic search index over clinical narratives. **Wait 1-2 minutes** after running for the index to build.

> **Note:** Before running, you need to grant the Cortex role:
> ```sql
> USE ROLE ACCOUNTADMIN;
> GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE APP_HCA_ADMIN_ROLE;
> ```

### Step 4: Create Semantic View

```sql
USE ROLE APP_HCA_ADMIN_ROLE;
USE WAREHOUSE compute_wh;
-- Paste semantic_view.sql and Run All
```

**File:** [`semantic_view.sql`](semantic_view.sql)

Teaches the agent's Cortex Analyst tool how your tables relate and what each column means. Includes 10 verified queries for common questions.

### Step 5: Create the Cortex Agent

```sql
USE ROLE APP_HCA_ADMIN_ROLE;
USE WAREHOUSE compute_wh;
-- Paste cortex_agent.sql and Run All
```

**File:** [`cortex_agent.sql`](cortex_agent.sql)

Creates the `HCA_INVESTIGATOR_AGENT` that combines Cortex Analyst (structured queries) with Cortex Search (clinical document RAG).

### Step 6: Verify Everything Works

```sql
USE ROLE APP_HCA_ADMIN_ROLE;

-- Check tables have data
SELECT 'CLAIM_HEADER' AS tbl, COUNT(*) AS rows FROM DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER
UNION ALL SELECT 'ANOMALY_RESULT', COUNT(*) FROM DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_ANOMALY_RESULT
UNION ALL SELECT 'CLAIM_CASE', COUNT(*) FROM DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_CASE;

-- Check views return data
SELECT * FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_SUSPECTED_OVERPAYMENT_CASES LIMIT 5;
SELECT * FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_PROVIDER_OUTLIER_SUMMARY;

-- Check search service is ready (wait 1-2 min after creation)
SHOW CORTEX SEARCH SERVICES IN SCHEMA DEMO_HIGH_COST_CLAIMS.CURATED;

-- Check agent exists
SHOW AGENTS IN SCHEMA DEMO_HIGH_COST_CLAIMS.CURATED;
```

---

## Using the Agent

Once created, the agent appears in **Snowsight → AI & ML → Agents** as `HCA_INVESTIGATOR_AGENT`. Click it to start chatting.

You can also query it programmatically via:
- **REST API:** `POST /api/v2/databases/DEMO_HIGH_COST_CLAIMS/schemas/CURATED/agents/HCA_INVESTIGATOR_AGENT:run`
- **SQL:** `SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(...)`

---

## Sample Questions to Ask the Agent

### Anomaly Detection & Scores

| Question | What it demonstrates |
|----------|---------------------|
| "Which claims have the highest anomaly scores?" | Ranks flagged claims by severity |
| "What types of anomalies were detected and how many of each?" | Groups by anomaly type |
| "Show me all claims flagged as DUPLICATE_BILLING" | Filters by specific anomaly type |
| "What is the total estimated overpayment across all flagged claims?" | Aggregation over financial data |

### Case Management

| Question | What it demonstrates |
|----------|---------------------|
| "Show me all open high-priority cases that need a reviewer assigned" | Multi-filter: status + priority + NULL check |
| "What is the status of case CASE-002?" | Specific case lookup |
| "How many cases are in each status?" | Status distribution |
| "Which reviewer has the most cases?" | Reviewer workload analysis |

### Provider Analysis

| Question | What it demonstrates |
|----------|---------------------|
| "Which providers have the highest anomaly rates compared to their peers?" | Provider outlier ranking |
| "Tell me about Dr. Amanda Patel's billing patterns" | Specific provider deep dive |
| "Which provider has the most estimated overpayment?" | Financial risk by provider |

### Financial & Recovery

| Question | What it demonstrates |
|----------|---------------------|
| "How much money has been recovered so far?" | Recovery tracking |
| "What's the difference between estimated and confirmed overpayment?" | ML vs. confirmed amounts |
| "Show claims where billed amount exceeds CMS expected by more than $10,000" | Fee schedule variance |

### Clinical Documentation (triggers Cortex Search)

| Question | What it demonstrates |
|----------|---------------------|
| "What is the clinical justification for claim CLM-2026-0002?" | RAG over EHR summaries |
| "What clinical documentation is missing for CAR-T therapy cases?" | Doc completeness + search |
| "Summarize the treatment indication for patient 1001" | Clinical narrative retrieval |
| "What did the reviewer say about the duplicate billing case?" | Review notes search |

### Cross-tool Questions (Agent routes to both tools)

| Question | What it demonstrates |
|----------|---------------------|
| "For the highest-scoring anomaly case, what clinical evidence supports or contradicts the flag?" | Analyst (find case) + Search (find evidence) |
| "Which CAR-T claims have incomplete documentation and what documents are missing?" | Structured + doc gap analysis |

---

## Highlighted Anomalies in the Sample Data

The seed data includes these specific anomalies you can investigate:

| Claim | Anomaly Type | Score | Story |
|-------|-------------|-------|-------|
| CLM-2026-0008 | DUPLICATE_BILLING | 0.91 | Same chemo infusion code (96413) billed twice on same date. Provider confirmed error. $6K recovered. |
| CLM-2026-0013 | DRUG_DIAG_MISMATCH | 0.88 | Second CAR-T (Kymriah) within 14 months. Limited evidence for re-treatment. $25K estimated overpayment. |
| CLM-2026-0002 | FEE_SCHEDULE_VARIANCE | 0.85 | CAR-T billed at $520K vs CMS expected $94.4K. 434% markup. $28.5K confirmed and fully recovered. |
| CLM-2026-0006 | UNBUNDLING | 0.82 | IV chemo (96413) and SC chemo (96401) on same date — mutually exclusive per CCI rules. $15.2K estimated. |
| CLM-2026-0005 | EXCESSIVE_UNITS | 0.78 | 10 units of SC injection when typical is 1-2. Possible unit-of-measure confusion (mg vs vials). |
| CLM-2026-0010 | EXCESSIVE_UNITS | 0.76 | 4 first-hour chemo units (96413) when typical is 1-2. Extended treatment beyond protocol. |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CORTEX AGENT                                      │
│                   (HCA_INVESTIGATOR_AGENT)                                │
├────────────────────────────┬────────────────────────────────────────────┤
│     Cortex Analyst         │         Cortex Search                       │
│  (Semantic View → SQL)     │    (Clinical Doc RAG)                       │
├────────────────────────────┼────────────────────────────────────────────┤
│                            │                                             │
│  ANALYTICS VIEWS           │  CLINICAL_SEARCH_SVC                        │
│  ├─ VW_SUSPECTED_OVERPAY…  │  ├─ EHR Summaries                          │
│  ├─ VW_PROVIDER_OUTLIER…   │  ├─ Claim Documents                        │
│  ├─ VW_HIGH_COST_THERAPY…  │  ├─ Anomaly Explanations                   │
│  ├─ VW_DOCUMENT_COMPLETE…  │  └─ Clinical Review Notes                  │
│  ├─ VW_BUNDLING_EXCEPT…    │                                             │
│  └─ VW_MODEL_FEEDBACK…     │                                             │
├────────────────────────────┴────────────────────────────────────────────┤
│                    DEMO_HIGH_COST_CLAIMS                                  │
│  ┌──────────┬──────────┬──────────────┬───────────────────────────────┐  │
│  │   RAW    │   REF    │   CURATED    │         ANALYTICS             │  │
│  │ Claims   │ Codes    │ ML Scores    │ Pre-joined Views              │  │
│  │ Lines    │ Rules    │ Cases        │ (Agent queries here)          │  │
│  │ Docs     │ Fees     │ Reviews      │                               │  │
│  │ EHR      │ Config   │ Recoveries   │                               │  │
│  └──────────┴──────────┴──────────────┴───────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## File Summary

| File | Purpose | Run Order |
|------|---------|-----------|
| `setup.sql` | Creates roles, database, schemas, tables, views, grants | 1st |
| `seed_data.sql` | Inserts sample data into all tables | 2nd |
| `cortex_search.sql` | Creates Cortex Search Service for clinical doc RAG | 3rd |
| `semantic_view.sql` | Creates Semantic View for Cortex Analyst | 4th |
| `cortex_agent.sql` | Creates the Cortex Agent | 5th |
| `README.md` | This file | — |

---

## Customization

- **Warehouse name:** All scripts use `compute_wh`. Find-and-replace if yours differs.
- **More data:** The seed is intentionally small for demo purposes. You can generate more claims using the same patterns.
- **Additional tools:** You can add UDFs/stored procedures as custom tools to the agent (e.g., a tool that updates case status).

---

## Cleanup

To remove everything:

```sql
USE ROLE APP_HCA_ADMIN_ROLE;
DROP DATABASE IF EXISTS DEMO_HIGH_COST_CLAIMS;

USE ROLE ACCOUNTADMIN;
DROP ROLE IF EXISTS APP_HCA_ADMIN_ROLE;
DROP ROLE IF EXISTS APP_HCA_SVC_ROLE;
```
