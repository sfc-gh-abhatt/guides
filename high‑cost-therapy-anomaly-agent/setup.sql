/*
================================================================================
  DEMO_HIGH_COST_CLAIMS — Complete Snowflake Setup Script
================================================================================

  PURPOSE:
    Creates all database objects for a Payment Integrity pipeline that detects
    anomalous high-cost therapy claims using ML scoring, routes them through
    investigation workflows, and tracks overpayment recovery.

  WHAT THIS SCRIPT DOES:
    1. Creates roles (APP_HCA_ADMIN_ROLE owns objects; APP_HCA_SVC_ROLE for applications)
    2. Creates a database named DEMO_HIGH_COST_CLAIMS
    3. Creates 4 schemas (RAW, REF, CURATED, ANALYTICS)
    4. Creates 9 reference tables (REF schema)
    5. Creates 5 raw transaction tables (RAW schema)
    6. Creates 6 curated/analytics tables (CURATED schema)
    7. Creates 8 analytics views (ANALYTICS schema)
    8. Grants APP_HCA_ADMIN_ROLE to APP_HCA_SVC_ROLE for application access

  HOW TO RUN:
    1. Log in to your Snowflake account (https://<your-account>.snowflakecomputing.com)
    2. Open a SQL Worksheet (click "+ Worksheet" in the left nav)
    3. Paste this entire script into the worksheet
    4. Click "Run All" (or Ctrl+Shift+Enter / Cmd+Shift+Enter)
    5. All objects will be created under the DEMO_HIGH_COST_CLAIMS database

  PREREQUISITES:
    - You must be logged in as ACCOUNTADMIN (or a role that can create roles
      and databases). The script switches to ACCOUNTADMIN at the start.
    - A running warehouse must be set in your session (the script uses your
      session's current warehouse for DDL execution).

  IMPORTANT NOTES:
    - This script uses CREATE OR REPLACE, which means re-running it will DROP
      and RECREATE all objects. Any existing data in these tables will be lost.
    - The tables are created empty; data must be loaded separately.
    - Two roles are created:
        APP_HCA_ADMIN_ROLE  — owns the database and all objects (used to create them)
        APP_HCA_SVC_ROLE    — inherits APP_HCA_ADMIN_ROLE; intended for application
                          service accounts that need read + selective write access

  ROLE HIERARCHY:
    ACCOUNTADMIN
        └── APP_HCA_ADMIN_ROLE   (owns DEMO_HIGH_COST_CLAIMS and all objects)
                └── APP_HCA_SVC_ROLE  (for application integrations; read all,
                                   write to CURATED case/review/recovery/feedback)

  ARCHITECTURE:
    ┌──────────────────────────────────────────────────────────────────────┐
    │                    DEMO_HIGH_COST_CLAIMS                              │
    ├──────────┬──────────┬──────────────┬─────────────────────────────────┤
    │   RAW    │   REF    │   CURATED    │          ANALYTICS              │
    ├──────────┼──────────┼──────────────┼─────────────────────────────────┤
    │Claims,   │Lookup    │ML scores,    │Pre-built views for dashboards   │
    │Lines,    │tables,   │cases,        │and downstream integrations      │
    │Documents,│codes,    │reviews,      │                                 │
    │EHR data  │rules     │recoveries    │                                 │
    └──────────┴──────────┴──────────────┴─────────────────────────────────┘

================================================================================
*/

-- =============================================================================
-- STEP 1: Role Setup
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS APP_HCA_ADMIN_ROLE
    COMMENT = 'Owns DEMO_HIGH_COST_CLAIMS database and all objects within it.';

CREATE ROLE IF NOT EXISTS APP_HCA_SVC_ROLE
    COMMENT = 'Application service role. Inherits from APP_HCA_ADMIN_ROLE for read access; has selective write grants for case management.';

GRANT ROLE APP_HCA_ADMIN_ROLE TO ROLE ACCOUNTADMIN;

-- =============================================================================
-- STEP 2: Create Database and Schemas (as APP_HCA_ADMIN_ROLE)
-- =============================================================================

GRANT CREATE DATABASE ON ACCOUNT TO ROLE APP_HCA_ADMIN_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE APP_HCA_ADMIN_ROLE;

USE ROLE APP_HCA_ADMIN_ROLE;

CREATE OR REPLACE DATABASE DEMO_HIGH_COST_CLAIMS;

CREATE SCHEMA DEMO_HIGH_COST_CLAIMS.RAW
    COMMENT = 'Raw transaction tables: claims, lines, documents';

CREATE SCHEMA DEMO_HIGH_COST_CLAIMS.REF
    COMMENT = 'Reference/lookup tables: codes, rules, fee schedules';

CREATE SCHEMA DEMO_HIGH_COST_CLAIMS.CURATED
    COMMENT = 'AI/analytics output: anomaly scores, cases, reviews, recoveries';

CREATE SCHEMA DEMO_HIGH_COST_CLAIMS.ANALYTICS
    COMMENT = 'Pre-built views for dashboards and executive reporting';


-- =============================================================================
-- STEP 3: Create Reference Tables (REF Schema)
-- =============================================================================

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.REF.REF_PATIENT (
    PATIENT_ID                   NUMBER(38,0) NOT NULL,
    AGE_BAND                     VARCHAR(10)  NOT NULL,
    GENDER                       VARCHAR(1)   NOT NULL,
    STATE                        VARCHAR(2)   NOT NULL,
    PAYER_TYPE                   VARCHAR(30)  NOT NULL,
    MEMBER_PLAN                  VARCHAR(40)  NOT NULL,
    RISK_GROUP                   VARCHAR(20)  NOT NULL,
    SYNTHETIC_POPULATION_SEGMENT VARCHAR(30)  NOT NULL,
    CONSTRAINT PK_PATIENT PRIMARY KEY (PATIENT_ID)
)
COMMENT = 'De-identified patient demographics reference including age band, gender, state, payer type, member plan, and risk group.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.REF.REF_PROVIDER (
    PROVIDER_ID                       NUMBER(38,0)  NOT NULL,
    PROVIDER_NAME_SYNTHETIC           VARCHAR(120)  NOT NULL,
    NPI_LIKE_ID                       VARCHAR(10)   NOT NULL,
    SPECIALTY                         VARCHAR(80)   NOT NULL,
    ORGANIZATION_NAME_SYNTHETIC       VARCHAR(120)  NOT NULL,
    FACILITY_TYPE                     VARCHAR(40)   NOT NULL,
    STATE                             VARCHAR(2)    NOT NULL,
    RISK_TIER                         VARCHAR(10)   NOT NULL,
    HISTORICAL_BILLING_PATTERN_SCORE  FLOAT         NOT NULL,
    CREATED_AT                        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_PROVIDER PRIMARY KEY (PROVIDER_ID)
)
COMMENT = 'Provider reference with synthetic names, NPI-like IDs, specialties, facility types, risk tiers, and historical billing pattern scores.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.REF.REF_PROCEDURE_CODE (
    PROCEDURE_CODE          VARCHAR(10)  NOT NULL,
    CODE_TYPE               VARCHAR(10)  NOT NULL,
    PROCEDURE_DESCRIPTION   VARCHAR(200) NOT NULL,
    THERAPY_CATEGORY        VARCHAR(60)  NOT NULL,
    EXPECTED_SETTING        VARCHAR(40)  NOT NULL,
    TYPICAL_UNITS_MIN       NUMBER(38,0) NOT NULL,
    TYPICAL_UNITS_MAX       NUMBER(38,0) NOT NULL,
    BASE_FEE_SCHEDULE_AMOUNT FLOAT       NOT NULL,
    BUNDLING_FAMILY         VARCHAR(20),
    CAN_BE_PRIMARY          BOOLEAN NOT NULL DEFAULT TRUE,
    CAN_BE_ADD_ON           BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT PK_PROCEDURE PRIMARY KEY (PROCEDURE_CODE)
)
COMMENT = 'CPT/HCPCS procedure code reference with therapy category mapping, typical unit ranges, base fee schedule amounts, and bundling family assignments.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.REF.REF_DRUG (
    DRUG_CODE                  VARCHAR(10)  NOT NULL,
    NDC_LIKE_CODE              VARCHAR(13)  NOT NULL,
    DRUG_NAME_SYNTHETIC        VARCHAR(120) NOT NULL,
    THERAPY_CATEGORY           VARCHAR(60)  NOT NULL,
    TYPICAL_DIAGNOSIS_CATEGORY VARCHAR(60)  NOT NULL,
    UNIT_COST                  FLOAT        NOT NULL,
    ADMINISTRATION_ROUTE       VARCHAR(30)  NOT NULL,
    CONSTRAINT PK_DRUG PRIMARY KEY (DRUG_CODE)
)
COMMENT = 'Specialty drug reference containing synthetic drug names, NDC-like codes, therapy categories, unit costs, and administration routes.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.REF.REF_DIAGNOSIS_CODE (
    DIAGNOSIS_CODE        VARCHAR(10)  NOT NULL,
    DIAGNOSIS_DESCRIPTION VARCHAR(200) NOT NULL,
    DIAGNOSIS_CATEGORY    VARCHAR(60)  NOT NULL,
    THERAPY_CAT_GENE      BOOLEAN DEFAULT FALSE,
    THERAPY_CAT_CART      BOOLEAN DEFAULT FALSE,
    THERAPY_CAT_ONC_INFUSION    BOOLEAN DEFAULT FALSE,
    THERAPY_CAT_ENZYME_REPLACE  BOOLEAN DEFAULT FALSE,
    THERAPY_CAT_HEMOPHILIA      BOOLEAN DEFAULT FALSE,
    THERAPY_CAT_ORPHAN_BIO      BOOLEAN DEFAULT FALSE,
    THERAPY_CAT_TRANSPLANT      BOOLEAN DEFAULT FALSE,
    CONSTRAINT PK_DIAGNOSIS PRIMARY KEY (DIAGNOSIS_CODE)
)
COMMENT = 'ICD-10 diagnosis code reference with therapy category eligibility flags. Maps diagnosis codes to the 7 high-cost therapy categories.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.REF.REF_ANOMALY_TYPE_CONFIG (
    ANOMALY_TYPE            VARCHAR(40)  NOT NULL,
    DISPLAY_NAME            VARCHAR(80)  NOT NULL,
    DESCRIPTION             VARCHAR(300),
    DEFAULT_SCORE_THRESHOLD FLOAT NOT NULL DEFAULT 0.5,
    AUTO_ESCALATE_FLAG      BOOLEAN NOT NULL DEFAULT FALSE,
    ENABLED_FLAG            BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT PK_ANOMALY_CONFIG PRIMARY KEY (ANOMALY_TYPE)
)
COMMENT = 'Configuration for the 8 anomaly detection types: DUPLICATE_BILLING, UNBUNDLING, EXCESSIVE_UNITS, FEE_SCHEDULE_VARIANCE, CODING_INCONSISTENCY, DRUG_DIAG_MISMATCH, INCORRECT_PROCEDURE_COMBO, PROVIDER_OUTLIER.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.REF.REF_BUNDLING_RULE (
    RULE_ID              NUMBER(38,0) NOT NULL,
    PRIMARY_CODE         VARCHAR(10)  NOT NULL,
    SECONDARY_CODE       VARCHAR(10)  NOT NULL,
    RULE_TYPE            VARCHAR(30)  NOT NULL,
    DESCRIPTION          VARCHAR(200) NOT NULL,
    ALLOWED_TOGETHER_FLAG BOOLEAN     NOT NULL,
    BUNDLE_EXPECTED_FLAG BOOLEAN      NOT NULL,
    SEVERITY_WEIGHT      FLOAT        NOT NULL,
    EFFECTIVE_DATE       DATE NOT NULL DEFAULT '2026-01-01',
    END_DATE             DATE,
    CONSTRAINT PK_BUNDLING_RULE PRIMARY KEY (RULE_ID)
)
COMMENT = 'CCI-based procedure bundling rules defining which procedure code pairs should be billed together or separately.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.REF.REF_CMS_2026_FEE_SCHEDULE (
    PROCEDURE_CODE              VARCHAR(10)  NOT NULL,
    CALENDAR_YEAR               NUMBER(38,0) NOT NULL DEFAULT 2026,
    ALLOWED_AMOUNT              FLOAT        NOT NULL,
    PROFESSIONAL_TECHNICAL_IND  VARCHAR(5)   DEFAULT 'G',
    SITE_OF_SERVICE_ADJUSTMENT  FLOAT        DEFAULT 1,
    BILATERAL_INDICATOR         VARCHAR(1)   DEFAULT '0',
    MULTIPLE_PROCEDURE_INDICATOR VARCHAR(1)  DEFAULT '0',
    GLOBAL_PERIOD               VARCHAR(3)   DEFAULT 'XXX',
    FEE_SCHEDULE_SOURCE_FLAG    VARCHAR(60)  DEFAULT 'synthetic_demo_based_on_2026_structure',
    CONSTRAINT PK_FEE_SCHEDULE PRIMARY KEY (PROCEDURE_CODE, CALENDAR_YEAR)
)
COMMENT = 'CMS 2026 Medicare Physician Fee Schedule reference for fee schedule variance anomaly detection.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.REF.REF_REQUIRED_DOCUMENT_RULE (
    RULE_ID                NUMBER(38,0) NOT NULL,
    THERAPY_CATEGORY       VARCHAR(60)  NOT NULL,
    ANOMALY_TYPE           VARCHAR(40)  NOT NULL,
    REQUIRED_DOCUMENT_TYPE VARCHAR(60)  NOT NULL,
    PRIORITY_RANK          NUMBER(38,0) NOT NULL,
    CONSTRAINT PK_DOC_RULE PRIMARY KEY (RULE_ID)
)
COMMENT = 'Rules defining which supporting documents are required for specific therapy category and anomaly type combinations during investigation.';


-- =============================================================================
-- STEP 4: Create Raw Transaction Tables (RAW Schema)
-- =============================================================================

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER (
    CLAIM_ID              VARCHAR(20)  NOT NULL,
    PATIENT_ID            NUMBER(38,0) NOT NULL,
    PROVIDER_ID           NUMBER(38,0) NOT NULL,
    CLAIM_TYPE            VARCHAR(20)  NOT NULL,
    BILL_TYPE             VARCHAR(4),
    PLACE_OF_SERVICE      VARCHAR(40)  NOT NULL,
    ADMISSION_DATE        DATE,
    DISCHARGE_DATE        DATE,
    SERVICE_FROM_DATE     DATE         NOT NULL,
    SERVICE_TO_DATE       DATE         NOT NULL,
    CLAIM_RECEIVED_DATE   DATE         NOT NULL,
    CLAIM_PAID_DATE       DATE,
    DIAGNOSIS_PRIMARY     VARCHAR(10)  NOT NULL,
    DIAGNOSIS_SECONDARY_1 VARCHAR(10),
    DIAGNOSIS_SECONDARY_2 VARCHAR(10),
    THERAPY_CATEGORY      VARCHAR(60)  NOT NULL,
    TOTAL_BILLED_AMOUNT   FLOAT        NOT NULL,
    TOTAL_ALLOWED_AMOUNT  FLOAT        NOT NULL,
    TOTAL_PAID_AMOUNT     FLOAT        NOT NULL,
    STATUS                VARCHAR(20)  NOT NULL DEFAULT 'PAID',
    HIGH_COST_FLAG        BOOLEAN      NOT NULL DEFAULT FALSE,
    COST_THRESHOLD_FLAG   FLOAT,
    SOURCE_SYSTEM         VARCHAR(30)  NOT NULL DEFAULT 'DEMO_GENERATOR',
    CONSTRAINT PK_CLAIM_HEADER PRIMARY KEY (CLAIM_ID)
)
COMMENT = 'Primary claim header table containing one row per healthcare claim. Includes patient/provider linkage, dates of service, diagnosis codes, therapy category, and financial totals.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_LINE (
    CLAIM_LINE_ID              VARCHAR(30)  NOT NULL,
    CLAIM_ID                   VARCHAR(20)  NOT NULL,
    LINE_NUMBER                NUMBER(38,0) NOT NULL,
    PROCEDURE_CODE             VARCHAR(10)  NOT NULL,
    DRUG_CODE                  VARCHAR(10),
    REVENUE_CODE               VARCHAR(4),
    MODIFIER_1                 VARCHAR(2),
    MODIFIER_2                 VARCHAR(2),
    DIAGNOSIS_POINTER          VARCHAR(10)  NOT NULL,
    UNITS                      NUMBER(38,0) NOT NULL,
    LINE_BILLED_AMOUNT         FLOAT        NOT NULL,
    LINE_ALLOWED_AMOUNT        FLOAT        NOT NULL,
    LINE_PAID_AMOUNT           FLOAT        NOT NULL,
    CMS_EXPECTED_AMOUNT        FLOAT,
    SERVICE_DATE               DATE         NOT NULL,
    LINE_STATUS                VARCHAR(20)  NOT NULL DEFAULT 'PAID',
    BUNDLED_WITH_LINE_ID       VARCHAR(30),
    SYNTHETIC_ANOMALY_SEED_FLAG BOOLEAN     NOT NULL DEFAULT FALSE,
    ANOMALY_SEED_TYPE          VARCHAR(40),
    CONSTRAINT PK_CLAIM_LINE PRIMARY KEY (CLAIM_LINE_ID)
)
COMMENT = 'Claim line-level detail with procedure codes, drug codes, revenue codes, modifiers, units, and line-level financial amounts. Each claim header has 1-N claim lines.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_DOCUMENT (
    DOCUMENT_ID          VARCHAR(20)  NOT NULL,
    CLAIM_ID             VARCHAR(20)  NOT NULL,
    DOCUMENT_TYPE        VARCHAR(60)  NOT NULL,
    DOCUMENT_SOURCE      VARCHAR(40)  NOT NULL,
    AVAILABILITY_STATUS  VARCHAR(20)  NOT NULL,
    RETRIEVAL_STATUS     VARCHAR(20)  NOT NULL,
    SYNTHETIC_URI        VARCHAR(200),
    EXTRACTION_SUMMARY   VARCHAR(500),
    DOCUMENT_DATE        DATE,
    CONSTRAINT PK_CLAIM_DOC PRIMARY KEY (DOCUMENT_ID)
)
COMMENT = 'Metadata for supporting clinical documents. Document types include Prior Authorization, Clinical Notes, Lab Results, Discharge Summary, Pathology Report.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.RAW.EHR_SUMMARY (
    EHR_SUMMARY_ID           VARCHAR(20)   NOT NULL,
    CLAIM_ID                 VARCHAR(20)   NOT NULL,
    PATIENT_ID               NUMBER(38,0)  NOT NULL,
    ENCOUNTER_ID_SYNTHETIC   VARCHAR(20)   NOT NULL,
    CLINICAL_SUMMARY_TEXT    VARCHAR(2000) NOT NULL,
    ORDERING_PROVIDER_ID     NUMBER(38,0)  NOT NULL,
    TREATMENT_INDICATION     VARCHAR(200)  NOT NULL,
    THERAPY_START_DATE       DATE          NOT NULL,
    THERAPY_END_DATE         DATE,
    CONSTRAINT PK_EHR PRIMARY KEY (EHR_SUMMARY_ID)
)
COMMENT = 'Synthetic EHR summaries linked to claims. Contains clinical narrative text, treatment indications, and therapy date ranges used for medical necessity review.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.RAW.PROVIDER_BILLING_HISTORY_DAILY (
    PROVIDER_ID           NUMBER(38,0) NOT NULL,
    SERVICE_DATE          DATE         NOT NULL,
    THERAPY_CATEGORY      VARCHAR(60)  NOT NULL,
    CLAIM_COUNT           NUMBER(38,0) NOT NULL,
    AVG_CLAIM_AMOUNT      FLOAT        NOT NULL,
    AVG_UNITS_PER_CODE    FLOAT,
    ANOMALY_RATE_BASELINE FLOAT NOT NULL DEFAULT 0,
    PEER_PERCENTILE       FLOAT,
    CONSTRAINT PK_PROVIDER_HIST PRIMARY KEY (PROVIDER_ID, SERVICE_DATE, THERAPY_CATEGORY)
)
COMMENT = 'Daily aggregated billing statistics per provider and therapy category. Used for provider outlier detection.';


-- =============================================================================
-- STEP 5: Create Curated Tables (CURATED Schema)
-- =============================================================================

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_ANOMALY_RESULT (
    RESULT_ID                          VARCHAR(20)   NOT NULL,
    CLAIM_ID                           VARCHAR(20)   NOT NULL,
    RUN_TIMESTAMP                      TIMESTAMP_NTZ NOT NULL,
    ANOMALY_SCORE                      FLOAT         NOT NULL,
    ANOMALY_TYPE                       VARCHAR(40),
    ANOMALY_SUBTYPE                    VARCHAR(60),
    ESTIMATED_OVERPAYMENT_AMOUNT       FLOAT NOT NULL DEFAULT 0,
    CONFIDENCE_SCORE                   FLOAT         NOT NULL,
    REQUIRED_SUPPORTING_DOCUMENTS_JSON VARCHAR(1000),
    RECOMMENDED_ACTION                 VARCHAR(40)   NOT NULL,
    MODEL_VERSION                      VARCHAR(20)   NOT NULL DEFAULT 'v2.4.1-demo',
    EXPLANATION_SUMMARY                VARCHAR(500),
    CONSTRAINT PK_ANOMALY_RESULT PRIMARY KEY (RESULT_ID)
)
COMMENT = 'ML model output with one row per claim. Anomaly scores range 0.0-1.0; scores >= 0.7 are high-priority. ~30 of 300 claims are flagged with non-NULL anomaly types.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_CASE (
    CASE_ID                          VARCHAR(20)  NOT NULL,
    CLAIM_ID                         VARCHAR(20)  NOT NULL,
    RESULT_ID                        VARCHAR(20)  NOT NULL,
    CASE_STATUS                      VARCHAR(20)  NOT NULL DEFAULT 'OPEN',
    PRIORITY                         VARCHAR(10)  NOT NULL,
    ASSIGNED_REVIEWER                VARCHAR(50),
    CASE_OPENED_DATE                 DATE         NOT NULL,
    CASE_TARGET_CLOSE_DATE           DATE,
    CASE_ACTUAL_CLOSE_DATE           DATE,
    DOCUMENTATION_COMPLETENESS_SCORE FLOAT NOT NULL DEFAULT 0,
    OVERPAYMENT_CONFIRMED            BOOLEAN NOT NULL DEFAULT FALSE,
    CONFIRMED_OVERPAYMENT_AMOUNT     FLOAT NOT NULL DEFAULT 0,
    CONSTRAINT PK_CLAIM_CASE PRIMARY KEY (CASE_ID)
)
COMMENT = 'Investigation case management table. Each case corresponds to a flagged anomaly result. Application workflows update CASE_STATUS and ASSIGNED_REVIEWER.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.CURATED.CLINICAL_REVIEW_OUTCOME (
    REVIEW_ID                    VARCHAR(20)  NOT NULL,
    CASE_ID                      VARCHAR(20)  NOT NULL,
    REVIEWER_NAME                VARCHAR(50)  NOT NULL,
    REVIEW_DATE                  DATE         NOT NULL,
    CLINICAL_DECISION            VARCHAR(30)  NOT NULL,
    MEDICAL_NECESSITY_CONFIRMED  BOOLEAN      NOT NULL,
    DOCUMENTATION_ADEQUATE       BOOLEAN      NOT NULL,
    CODING_ACCURACY_CONFIRMED    BOOLEAN      NOT NULL,
    REVIEW_NOTES                 VARCHAR(500),
    CONSTRAINT PK_REVIEW PRIMARY KEY (REVIEW_ID)
)
COMMENT = 'Clinical review decisions. CLINICAL_DECISION values: Upheld, Overturned, Partially Upheld, Pending Additional Info.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.CURATED.RECOVERY_ACTION (
    RECOVERY_ID              VARCHAR(20)  NOT NULL,
    CASE_ID                  VARCHAR(20)  NOT NULL,
    RECOVERY_TYPE            VARCHAR(30)  NOT NULL,
    RECOVERY_AMOUNT_REQUESTED FLOAT       NOT NULL,
    RECOVERY_AMOUNT_RECEIVED FLOAT NOT NULL DEFAULT 0,
    RECOVERY_STATUS          VARCHAR(20)  NOT NULL,
    INITIATED_DATE           DATE         NOT NULL,
    RESOLVED_DATE            DATE,
    PROVIDER_RESPONSE        VARCHAR(200),
    CONSTRAINT PK_RECOVERY PRIMARY KEY (RECOVERY_ID)
)
COMMENT = 'Overpayment recovery tracking. Recovery types: Recoupment, Refund Request, Offset, Provider Adjustment.';

CREATE OR REPLACE TABLE DEMO_HIGH_COST_CLAIMS.CURATED.MODEL_FEEDBACK (
    FEEDBACK_ID                VARCHAR(20)  NOT NULL,
    RESULT_ID                  VARCHAR(20)  NOT NULL,
    REVIEWER_NAME              VARCHAR(50)  NOT NULL,
    FEEDBACK_TYPE              VARCHAR(20)  NOT NULL,
    FEEDBACK_DATE              DATE         NOT NULL,
    IS_TRUE_POSITIVE           BOOLEAN,
    IS_FALSE_POSITIVE          BOOLEAN,
    SUGGESTED_LABEL_CORRECTION VARCHAR(60),
    COMMENTS                   VARCHAR(300),
    CONSTRAINT PK_FEEDBACK PRIMARY KEY (FEEDBACK_ID)
)
COMMENT = 'Analyst feedback on anomaly detections for model retraining. Tracks true/false positive assessments.';


-- =============================================================================
-- STEP 6: Create Analytics Views (ANALYTICS Schema)
-- =============================================================================

CREATE OR REPLACE VIEW DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_HIGH_COST_THERAPY_CLAIMS AS
SELECT
    h.claim_id,
    h.therapy_category,
    h.diagnosis_primary,
    d.diagnosis_description,
    d.diagnosis_category,
    p.provider_name_synthetic      AS provider_name,
    p.specialty                    AS provider_specialty,
    p.organization_name_synthetic  AS provider_org,
    p.risk_tier                    AS provider_risk_tier,
    pt.age_band                    AS patient_age_band,
    pt.payer_type,
    pt.risk_group                  AS patient_risk_group,
    h.service_from_date,
    h.service_to_date,
    h.claim_received_date,
    h.claim_paid_date,
    h.total_billed_amount,
    h.total_allowed_amount,
    h.total_paid_amount,
    h.total_billed_amount - h.total_allowed_amount AS billed_allowed_variance,
    h.high_cost_flag,
    h.place_of_service,
    COUNT(cl.claim_line_id)        AS line_count,
    SUM(cl.units)                  AS total_units,
    SUM(cl.cms_expected_amount)    AS total_cms_expected,
    h.total_billed_amount - COALESCE(SUM(cl.cms_expected_amount), 0) AS cms_variance
FROM DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER h
JOIN DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_LINE cl ON h.claim_id = cl.claim_id
JOIN DEMO_HIGH_COST_CLAIMS.REF.REF_DIAGNOSIS_CODE d ON h.diagnosis_primary = d.diagnosis_code
JOIN DEMO_HIGH_COST_CLAIMS.REF.REF_PROVIDER p ON h.provider_id = p.provider_id
JOIN DEMO_HIGH_COST_CLAIMS.REF.REF_PATIENT pt ON h.patient_id = pt.patient_id
WHERE h.high_cost_flag = TRUE
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22;

CREATE OR REPLACE VIEW DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_SUSPECTED_OVERPAYMENT_CASES AS
SELECT
    cc.case_id,
    cc.claim_id,
    h.therapy_category,
    h.total_billed_amount,
    h.total_paid_amount,
    ar.anomaly_score,
    ar.anomaly_type,
    ar.anomaly_subtype,
    ar.estimated_overpayment_amount   AS ai_estimated_overpayment,
    ar.confidence_score,
    ar.recommended_action,
    ar.explanation_summary,
    cc.case_status,
    cc.priority,
    cc.assigned_reviewer,
    cc.documentation_completeness_score,
    ro.clinical_decision              AS review_outcome,
    ro.review_notes                   AS review_notes_summary,
    cc.confirmed_overpayment_amount,
    ra.recovery_status,
    ra.recovery_type                  AS recovery_method,
    ra.recovery_amount_requested      AS amount_sought,
    ra.recovery_amount_received       AS amount_recovered,
    p.provider_name_synthetic         AS provider_name,
    p.specialty                       AS provider_specialty,
    p.risk_tier                       AS provider_risk_tier,
    h.diagnosis_primary,
    h.service_from_date
FROM DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_CASE cc
JOIN DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_ANOMALY_RESULT ar ON cc.result_id = ar.result_id
JOIN DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER h ON cc.claim_id = h.claim_id
JOIN DEMO_HIGH_COST_CLAIMS.REF.REF_PROVIDER p ON h.provider_id = p.provider_id
LEFT JOIN DEMO_HIGH_COST_CLAIMS.CURATED.CLINICAL_REVIEW_OUTCOME ro ON cc.case_id = ro.case_id
LEFT JOIN DEMO_HIGH_COST_CLAIMS.CURATED.RECOVERY_ACTION ra ON cc.case_id = ra.case_id;

CREATE OR REPLACE VIEW DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_PROVIDER_OUTLIER_SUMMARY AS
SELECT
    p.provider_id,
    p.provider_name_synthetic      AS provider_name,
    p.specialty,
    p.organization_name_synthetic  AS provider_org,
    p.risk_tier,
    p.historical_billing_pattern_score,
    p.state,
    COUNT(DISTINCT h.claim_id)     AS total_claims,
    SUM(h.total_billed_amount)     AS total_billed,
    AVG(h.total_billed_amount)     AS avg_claim_amount,
    COUNT(DISTINCT CASE WHEN ar.anomaly_type IS NOT NULL THEN h.claim_id END) AS flagged_claims,
    ROUND(COUNT(DISTINCT CASE WHEN ar.anomaly_type IS NOT NULL THEN h.claim_id END)::FLOAT
          / NULLIF(COUNT(DISTINCT h.claim_id), 0), 4) AS anomaly_rate,
    SUM(CASE WHEN ar.anomaly_type IS NOT NULL THEN ar.estimated_overpayment_amount ELSE 0 END) AS total_estimated_overpayment,
    AVG(CASE WHEN ar.anomaly_type IS NOT NULL THEN ar.anomaly_score END) AS avg_anomaly_score,
    PERCENT_RANK() OVER (ORDER BY
        COUNT(DISTINCT CASE WHEN ar.anomaly_type IS NOT NULL THEN h.claim_id END)::FLOAT
        / NULLIF(COUNT(DISTINCT h.claim_id), 0)
    ) AS peer_anomaly_percentile
FROM DEMO_HIGH_COST_CLAIMS.REF.REF_PROVIDER p
LEFT JOIN DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER h ON p.provider_id = h.provider_id
LEFT JOIN DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_ANOMALY_RESULT ar ON h.claim_id = ar.claim_id
GROUP BY 1,2,3,4,5,6,7;

CREATE OR REPLACE VIEW DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_DOCUMENT_COMPLETENESS AS
SELECT
    h.claim_id,
    h.therapy_category,
    ar.anomaly_type,
    ar.anomaly_score,
    COUNT(DISTINCT cd.document_id)  AS total_documents,
    COUNT(DISTINCT CASE WHEN cd.availability_status = 'AVAILABLE' THEN cd.document_id END)  AS available_documents,
    COUNT(DISTINCT CASE WHEN cd.availability_status = 'MISSING' THEN cd.document_id END)    AS missing_documents,
    COUNT(DISTINCT CASE WHEN cd.availability_status = 'DELAYED' THEN cd.document_id END)    AS delayed_documents,
    COUNT(DISTINCT CASE WHEN cd.availability_status = 'INCOMPLETE' THEN cd.document_id END) AS incomplete_documents,
    ROUND(COUNT(DISTINCT CASE WHEN cd.availability_status = 'AVAILABLE' THEN cd.document_id END)::FLOAT
          / NULLIF(COUNT(DISTINCT cd.document_id), 0), 4) AS completeness_ratio,
    COUNT(DISTINCT rdr.rule_id) AS required_doc_types,
    LISTAGG(DISTINCT CASE
        WHEN rdr.required_document_type IS NOT NULL
         AND NOT EXISTS (
             SELECT 1 FROM DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_DOCUMENT cd2
             WHERE cd2.claim_id = h.claim_id
               AND cd2.document_type = rdr.required_document_type
               AND cd2.availability_status = 'AVAILABLE')
        THEN rdr.required_document_type
    END, ', ') AS missing_required_docs
FROM DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER h
JOIN DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_ANOMALY_RESULT ar ON h.claim_id = ar.claim_id
LEFT JOIN DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_DOCUMENT cd ON h.claim_id = cd.claim_id
LEFT JOIN DEMO_HIGH_COST_CLAIMS.REF.REF_REQUIRED_DOCUMENT_RULE rdr
    ON h.therapy_category = rdr.therapy_category
   AND (rdr.anomaly_type = '*' OR rdr.anomaly_type = ar.anomaly_type)
WHERE ar.anomaly_type IS NOT NULL
GROUP BY 1,2,3,4;

CREATE OR REPLACE VIEW DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_CLAIM_LINE_BUNDLING_EXCEPTIONS AS
SELECT
    cl1.claim_id,
    cl1.claim_line_id              AS line_1_id,
    cl1.procedure_code             AS line_1_procedure,
    cl2.claim_line_id              AS line_2_id,
    cl2.procedure_code             AS line_2_procedure,
    br.rule_type,
    br.description                 AS rule_description,
    br.severity_weight,
    br.allowed_together_flag,
    br.bundle_expected_flag,
    cl1.line_billed_amount         AS line_1_billed,
    cl2.line_billed_amount         AS line_2_billed,
    cl1.line_billed_amount + cl2.line_billed_amount AS combined_billed,
    h.therapy_category,
    h.total_billed_amount          AS claim_total_billed
FROM DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_LINE cl1
JOIN DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_LINE cl2
    ON cl1.claim_id = cl2.claim_id AND cl1.line_number < cl2.line_number
JOIN DEMO_HIGH_COST_CLAIMS.REF.REF_BUNDLING_RULE br
    ON (cl1.procedure_code = br.primary_code AND cl2.procedure_code = br.secondary_code)
    OR (cl2.procedure_code = br.primary_code AND cl1.procedure_code = br.secondary_code)
JOIN DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER h ON cl1.claim_id = h.claim_id
WHERE br.allowed_together_flag = FALSE
   OR (br.bundle_expected_flag = TRUE AND cl2.line_billed_amount > 0);

CREATE OR REPLACE VIEW DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_CLINICAL_SEARCH_CORPUS AS
SELECT
    e.ehr_summary_id AS document_id, e.claim_id,
    'EHR_SUMMARY' AS document_source, h.therapy_category,
    CONCAT('Clinical Summary for claim ', e.claim_id, '. ',
           'Treatment indication: ', COALESCE(e.treatment_indication, 'N/A'), '. ',
           COALESCE(e.clinical_summary_text, '')) AS search_text,
    e.therapy_start_date AS document_date
FROM DEMO_HIGH_COST_CLAIMS.RAW.EHR_SUMMARY e
JOIN DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER h ON e.claim_id = h.claim_id
UNION ALL
SELECT
    d.document_id, d.claim_id, d.document_type AS document_source, h.therapy_category,
    CONCAT(d.document_type, ' document for claim ', d.claim_id, '. ',
           'Source: ', COALESCE(d.document_source, 'Unknown'), '. ',
           'Status: ', COALESCE(d.availability_status, 'Unknown'), '. ',
           COALESCE(d.extraction_summary, '')) AS search_text,
    d.document_date
FROM DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_DOCUMENT d
JOIN DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER h ON d.claim_id = h.claim_id
UNION ALL
SELECT
    ar.result_id AS document_id, ar.claim_id,
    CONCAT('ANOMALY_', COALESCE(ar.anomaly_type, 'NONE')) AS document_source, h.therapy_category,
    CONCAT('Anomaly detection result for claim ', ar.claim_id, '. ',
           'Type: ', COALESCE(ar.anomaly_type, 'No anomaly detected'), '. ',
           'Score: ', ROUND(ar.anomaly_score, 3)::VARCHAR, '. ',
           'Recommended action: ', COALESCE(ar.recommended_action, 'None'), '. ',
           COALESCE(ar.explanation_summary, '')) AS search_text,
    ar.run_timestamp::DATE AS document_date
FROM DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_ANOMALY_RESULT ar
JOIN DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER h ON ar.claim_id = h.claim_id
UNION ALL
SELECT
    cr.review_id AS document_id, cc.claim_id,
    'CLINICAL_REVIEW' AS document_source, h.therapy_category,
    CONCAT('Clinical review for case ', cr.case_id, ' (claim ', cc.claim_id, '). ',
           'Decision: ', COALESCE(cr.clinical_decision, 'Pending'), '. ',
           'Medical necessity confirmed: ', cr.medical_necessity_confirmed::VARCHAR, '. ',
           'Documentation adequate: ', cr.documentation_adequate::VARCHAR, '. ',
           COALESCE(cr.review_notes, '')) AS search_text,
    cr.review_date AS document_date
FROM DEMO_HIGH_COST_CLAIMS.CURATED.CLINICAL_REVIEW_OUTCOME cr
JOIN DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_CASE cc ON cr.case_id = cc.case_id
JOIN DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER h ON cc.claim_id = h.claim_id;

CREATE OR REPLACE VIEW DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_MODEL_FEEDBACK_SUMMARY AS
SELECT
    mf.feedback_type AS final_outcome_label,
    COUNT(*) AS claim_count,
    AVG(ar.anomaly_score) AS avg_anomaly_score,
    MIN(ar.anomaly_score) AS min_anomaly_score,
    MAX(ar.anomaly_score) AS max_anomaly_score,
    SUM(CASE WHEN mf.feedback_type = 'TRUE_POSITIVE' THEN 1 ELSE 0 END) OVER () AS total_true_positives,
    SUM(CASE WHEN mf.feedback_type = 'FALSE_POSITIVE' THEN 1 ELSE 0 END) OVER () AS total_false_positives,
    SUM(CASE WHEN mf.feedback_type = 'INDETERMINATE' THEN 1 ELSE 0 END) OVER () AS total_indeterminate,
    ROUND(SUM(CASE WHEN mf.feedback_type = 'TRUE_POSITIVE' THEN 1 ELSE 0 END) OVER ()::FLOAT
        / NULLIF(SUM(CASE WHEN mf.feedback_type IN ('TRUE_POSITIVE','FALSE_POSITIVE') THEN 1 ELSE 0 END) OVER (), 0), 4) AS precision_score,
    ROUND(SUM(CASE WHEN mf.feedback_type = 'FALSE_POSITIVE' THEN 1 ELSE 0 END) OVER ()::FLOAT
        / NULLIF(COUNT(*) OVER (), 0), 4) AS false_positive_rate
FROM DEMO_HIGH_COST_CLAIMS.CURATED.MODEL_FEEDBACK mf
JOIN DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_ANOMALY_RESULT ar ON mf.result_id = ar.result_id
GROUP BY 1;

CREATE OR REPLACE VIEW DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_MODEL_FEEDBACK_GROUPED AS
SELECT
    ar.anomaly_type,
    mf.feedback_type,
    COUNT(*) AS feedback_count,
    AVG(ar.anomaly_score) AS avg_anomaly_score,
    AVG(ar.estimated_overpayment_amount) AS avg_estimated_overpayment
FROM DEMO_HIGH_COST_CLAIMS.CURATED.MODEL_FEEDBACK mf
JOIN DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_ANOMALY_RESULT ar ON mf.result_id = ar.result_id
GROUP BY 1, 2;


-- =============================================================================
-- STEP 7: Grant APP_HCA_SVC_ROLE Access
-- =============================================================================
-- APP_HCA_SVC_ROLE is the role your application service account should use.
-- It gets full read on all schemas plus selective write on CURATED tables
-- that the application needs to update during case management workflows.

USE ROLE ACCOUNTADMIN;

GRANT USAGE ON DATABASE DEMO_HIGH_COST_CLAIMS TO ROLE APP_HCA_SVC_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE DEMO_HIGH_COST_CLAIMS TO ROLE APP_HCA_SVC_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA DEMO_HIGH_COST_CLAIMS.RAW TO ROLE APP_HCA_SVC_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA DEMO_HIGH_COST_CLAIMS.REF TO ROLE APP_HCA_SVC_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA DEMO_HIGH_COST_CLAIMS.CURATED TO ROLE APP_HCA_SVC_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA DEMO_HIGH_COST_CLAIMS.ANALYTICS TO ROLE APP_HCA_SVC_ROLE;

GRANT INSERT, UPDATE ON TABLE DEMO_HIGH_COST_CLAIMS.CURATED.CLAIM_CASE TO ROLE APP_HCA_SVC_ROLE;
GRANT INSERT ON TABLE DEMO_HIGH_COST_CLAIMS.CURATED.CLINICAL_REVIEW_OUTCOME TO ROLE APP_HCA_SVC_ROLE;
GRANT INSERT, UPDATE ON TABLE DEMO_HIGH_COST_CLAIMS.CURATED.RECOVERY_ACTION TO ROLE APP_HCA_SVC_ROLE;
GRANT INSERT ON TABLE DEMO_HIGH_COST_CLAIMS.CURATED.MODEL_FEEDBACK TO ROLE APP_HCA_SVC_ROLE;

GRANT ROLE APP_HCA_ADMIN_ROLE TO ROLE APP_HCA_SVC_ROLE;


-- =============================================================================
-- DONE!
-- =============================================================================
-- All objects have been created. The tables are empty and ready for data loading.
--
-- NEXT STEPS:
--   1. Load synthetic data into the tables (via COPY INTO, INSERT, or a data generator)
--   2. Create your application service account user and grant APP_HCA_SVC_ROLE to it:
--        CREATE USER app_service_user PASSWORD = '...' DEFAULT_ROLE = APP_HCA_SVC_ROLE;
--        GRANT ROLE APP_HCA_SVC_ROLE TO USER app_service_user;
--   3. Query the ANALYTICS views to verify joins work once data is loaded
--
-- QUICK VERIFICATION (run after data is loaded):
--   USE ROLE APP_HCA_SVC_ROLE;
--   SELECT COUNT(*) FROM DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER;
--   SELECT * FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_SUSPECTED_OVERPAYMENT_CASES LIMIT 10;
-- =============================================================================
