/*
================================================================================
  Semantic View — High Cost Claims Analytics
================================================================================

  PURPOSE:
    Creates a Semantic View that Cortex Analyst uses to translate natural language
    questions into SQL against the ANALYTICS and CURATED schema objects.

  HOW TO RUN:
    1. Run setup.sql, then seed_data.sql, then cortex_search.sql
    2. Run this script:
         USE ROLE APP_HCA_ADMIN_ROLE;
         USE WAREHOUSE <your_warehouse>;
         -- Then paste and execute this script

  PREREQUISITES:
    - All tables and views must exist (run setup.sql first)
    - The SNOWFLAKE.CORTEX_USER database role must be granted to APP_HCA_ADMIN_ROLE

  NOTES:
    - This semantic view covers the ANALYTICS views and key CURATED tables
    - The agent references this as DEMO_HIGH_COST_CLAIMS.ANALYTICS.HCA_SEMANTIC_VIEW

================================================================================
*/

USE ROLE APP_HCA_ADMIN_ROLE;
USE DATABASE DEMO_HIGH_COST_CLAIMS;
USE SCHEMA ANALYTICS;

CREATE OR REPLACE SEMANTIC VIEW DEMO_HIGH_COST_CLAIMS.ANALYTICS.HCA_SEMANTIC_VIEW
  COMMENT = 'Semantic view for high-cost therapy anomaly investigation. Covers claims, anomalies, cases, providers, documents, recoveries, and model feedback.'
  AS SEMANTIC MODEL
    TABLES (
      DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_SUSPECTED_OVERPAYMENT_CASES
        AS overpayment_cases
        WITH COLUMNS (
          case_id DESCRIPTION 'Unique case identifier',
          claim_id DESCRIPTION 'Claim identifier linked to this case',
          therapy_category DESCRIPTION 'High-cost therapy type: Gene Therapy, CAR-T Cell Therapy, Oncology Infusion, Enzyme Replacement, Hemophilia Factor, Orphan Biologics, or Transplant Support',
          total_billed_amount DESCRIPTION 'Total amount billed on the claim in dollars',
          total_paid_amount DESCRIPTION 'Total amount paid on the claim in dollars',
          anomaly_score DESCRIPTION 'ML anomaly score from 0.0 to 1.0. Scores >= 0.7 are high priority',
          anomaly_type DESCRIPTION 'Type of anomaly detected: DUPLICATE_BILLING, UNBUNDLING, EXCESSIVE_UNITS, FEE_SCHEDULE_VARIANCE, CODING_INCONSISTENCY, DRUG_DIAG_MISMATCH, INCORRECT_PROCEDURE_COMBO, or PROVIDER_OUTLIER',
          anomaly_subtype DESCRIPTION 'More specific description of the anomaly',
          ai_estimated_overpayment DESCRIPTION 'Dollar amount the ML model estimates was overpaid',
          confidence_score DESCRIPTION 'Model confidence in the anomaly detection from 0.0 to 1.0',
          recommended_action DESCRIPTION 'Recommended next step: INVESTIGATE, ESCALATE, or MONITOR',
          explanation_summary DESCRIPTION 'Plain-language explanation of why the anomaly was flagged',
          case_status DESCRIPTION 'Current case status: OPEN, IN_REVIEW, CLOSED',
          priority DESCRIPTION 'Case priority: HIGH, MEDIUM, or LOW',
          assigned_reviewer DESCRIPTION 'Name of the reviewer assigned to this case, NULL if unassigned',
          documentation_completeness_score DESCRIPTION 'Score from 0.0 to 1.0 indicating how complete the supporting documentation is',
          review_outcome DESCRIPTION 'Clinical review decision: Upheld, Overturned, Partially Upheld, or Pending Additional Info',
          review_notes_summary DESCRIPTION 'Reviewer notes summarizing the clinical decision',
          confirmed_overpayment_amount DESCRIPTION 'Dollar amount confirmed as overpaid after review',
          recovery_status DESCRIPTION 'Status of recovery effort: RESOLVED, IN_PROGRESS, or NULL if not started',
          recovery_method DESCRIPTION 'How recovery is being pursued: Recoupment, Offset, Refund Request, or Provider Adjustment',
          amount_sought DESCRIPTION 'Dollar amount requested for recovery',
          amount_recovered DESCRIPTION 'Dollar amount actually recovered so far',
          provider_name DESCRIPTION 'Synthetic provider name',
          provider_specialty DESCRIPTION 'Provider medical specialty',
          provider_risk_tier DESCRIPTION 'Provider risk classification: HIGH, MEDIUM, or LOW',
          diagnosis_primary DESCRIPTION 'Primary ICD-10 diagnosis code on the claim',
          service_from_date DESCRIPTION 'Date when service was rendered'
        ),

      DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_PROVIDER_OUTLIER_SUMMARY
        AS provider_outliers
        WITH COLUMNS (
          provider_id DESCRIPTION 'Unique provider identifier',
          provider_name DESCRIPTION 'Synthetic provider name',
          specialty DESCRIPTION 'Provider medical specialty',
          provider_org DESCRIPTION 'Organization the provider belongs to',
          risk_tier DESCRIPTION 'Provider risk tier: HIGH, MEDIUM, or LOW',
          historical_billing_pattern_score DESCRIPTION 'Historical billing pattern score from 0.0 to 1.0. Higher means more anomalous billing history',
          state DESCRIPTION 'US state where provider is located (2-letter code)',
          total_claims DESCRIPTION 'Total number of claims submitted by this provider',
          total_billed DESCRIPTION 'Sum of all billed amounts across all claims for this provider',
          avg_claim_amount DESCRIPTION 'Average dollar amount per claim for this provider',
          flagged_claims DESCRIPTION 'Number of claims that were flagged with an anomaly',
          anomaly_rate DESCRIPTION 'Fraction of claims flagged as anomalous (0.0 to 1.0)',
          total_estimated_overpayment DESCRIPTION 'Sum of estimated overpayment amounts across all flagged claims',
          avg_anomaly_score DESCRIPTION 'Average anomaly score across flagged claims',
          peer_anomaly_percentile DESCRIPTION 'Percentile rank of this provider anomaly rate compared to peers (0.0 to 1.0)'
        ),

      DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_HIGH_COST_THERAPY_CLAIMS
        AS high_cost_claims
        WITH COLUMNS (
          claim_id DESCRIPTION 'Unique claim identifier',
          therapy_category DESCRIPTION 'High-cost therapy category',
          diagnosis_primary DESCRIPTION 'Primary ICD-10 diagnosis code',
          diagnosis_description DESCRIPTION 'Human-readable diagnosis description',
          diagnosis_category DESCRIPTION 'Broader diagnosis grouping',
          provider_name DESCRIPTION 'Synthetic provider name',
          provider_specialty DESCRIPTION 'Provider medical specialty',
          provider_org DESCRIPTION 'Provider organization name',
          provider_risk_tier DESCRIPTION 'Provider risk tier',
          patient_age_band DESCRIPTION 'Patient age range (e.g., 55-64)',
          payer_type DESCRIPTION 'Insurance payer type: Medicare Advantage, Commercial, Medicare FFS, or Medicaid',
          patient_risk_group DESCRIPTION 'Patient risk classification: HIGH, MEDIUM, or LOW',
          service_from_date DESCRIPTION 'Start date of service',
          service_to_date DESCRIPTION 'End date of service',
          claim_received_date DESCRIPTION 'Date claim was received by payer',
          claim_paid_date DESCRIPTION 'Date claim was paid (NULL if not yet paid)',
          total_billed_amount DESCRIPTION 'Total billed amount in dollars',
          total_allowed_amount DESCRIPTION 'Total allowed amount in dollars',
          total_paid_amount DESCRIPTION 'Total paid amount in dollars',
          billed_allowed_variance DESCRIPTION 'Difference between billed and allowed amounts',
          high_cost_flag DESCRIPTION 'Always TRUE in this view (pre-filtered)',
          place_of_service DESCRIPTION 'Where service was rendered: Hospital Outpatient, Academic Medical Center, Specialty Clinic, or Hospital Inpatient',
          line_count DESCRIPTION 'Number of claim lines on this claim',
          total_units DESCRIPTION 'Total units billed across all lines',
          total_cms_expected DESCRIPTION 'Total CMS fee schedule expected amount',
          cms_variance DESCRIPTION 'Difference between total billed and CMS expected amount'
        ),

      DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_DOCUMENT_COMPLETENESS
        AS document_completeness
        WITH COLUMNS (
          claim_id DESCRIPTION 'Claim identifier',
          therapy_category DESCRIPTION 'Therapy category of the claim',
          anomaly_type DESCRIPTION 'Type of anomaly detected on this claim',
          anomaly_score DESCRIPTION 'Anomaly score for this claim',
          total_documents DESCRIPTION 'Total number of documents associated with this claim',
          available_documents DESCRIPTION 'Number of documents that are available and retrieved',
          missing_documents DESCRIPTION 'Number of documents that are missing',
          delayed_documents DESCRIPTION 'Number of documents that are delayed',
          incomplete_documents DESCRIPTION 'Number of documents that are incomplete',
          completeness_ratio DESCRIPTION 'Ratio of available documents to total documents (0.0 to 1.0)',
          required_doc_types DESCRIPTION 'Number of document types required by rules',
          missing_required_docs DESCRIPTION 'Comma-separated list of required document types that are missing'
        ),

      DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_MODEL_FEEDBACK_SUMMARY
        AS model_feedback
        WITH COLUMNS (
          final_outcome_label DESCRIPTION 'Feedback classification: TRUE_POSITIVE, FALSE_POSITIVE, or INDETERMINATE',
          claim_count DESCRIPTION 'Number of claims with this feedback label',
          avg_anomaly_score DESCRIPTION 'Average anomaly score for claims with this label',
          min_anomaly_score DESCRIPTION 'Minimum anomaly score for claims with this label',
          max_anomaly_score DESCRIPTION 'Maximum anomaly score for claims with this label',
          total_true_positives DESCRIPTION 'Total count of true positive feedback records across all types',
          total_false_positives DESCRIPTION 'Total count of false positive feedback records across all types',
          total_indeterminate DESCRIPTION 'Total count of indeterminate feedback records across all types',
          precision_score DESCRIPTION 'Model precision: true positives / (true positives + false positives)',
          false_positive_rate DESCRIPTION 'Rate of false positives across all feedback'
        ),

      DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_CLAIM_LINE_BUNDLING_EXCEPTIONS
        AS bundling_exceptions
        WITH COLUMNS (
          claim_id DESCRIPTION 'Claim with bundling violation',
          line_1_id DESCRIPTION 'First claim line involved in the violation',
          line_1_procedure DESCRIPTION 'Procedure code on first line',
          line_2_id DESCRIPTION 'Second claim line involved in the violation',
          line_2_procedure DESCRIPTION 'Procedure code on second line',
          rule_type DESCRIPTION 'Type of bundling rule violated: CCI_COLUMN_1, CCI_COLUMN_2, or SEQUENTIAL',
          rule_description DESCRIPTION 'Description of the bundling rule',
          severity_weight DESCRIPTION 'Severity weight of the violation from 0.0 to 1.0',
          allowed_together_flag DESCRIPTION 'Whether these procedures are allowed together (FALSE = violation)',
          bundle_expected_flag DESCRIPTION 'Whether these procedures should be bundled (TRUE = should be billed together)',
          line_1_billed DESCRIPTION 'Amount billed on first line',
          line_2_billed DESCRIPTION 'Amount billed on second line',
          combined_billed DESCRIPTION 'Sum of both lines billed amounts',
          therapy_category DESCRIPTION 'Therapy category of the claim',
          claim_total_billed DESCRIPTION 'Total billed amount for the entire claim'
        )
    )

    RELATIONSHIPS (
      overpayment_cases.claim_id REFERENCES high_cost_claims.claim_id,
      overpayment_cases.provider_name REFERENCES provider_outliers.provider_name,
      document_completeness.claim_id REFERENCES high_cost_claims.claim_id,
      bundling_exceptions.claim_id REFERENCES high_cost_claims.claim_id
    )

    VERIFIED QUERIES (
      QUERY "What are the top 5 highest anomaly score cases?"
        AS 'SELECT case_id, claim_id, anomaly_score, anomaly_type, ai_estimated_overpayment, case_status, priority
            FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_SUSPECTED_OVERPAYMENT_CASES
            ORDER BY anomaly_score DESC LIMIT 5',

      QUERY "Show all open cases that need a reviewer assigned"
        AS 'SELECT case_id, claim_id, therapy_category, anomaly_type, priority, anomaly_score, ai_estimated_overpayment
            FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_SUSPECTED_OVERPAYMENT_CASES
            WHERE case_status = ''OPEN'' AND assigned_reviewer IS NULL
            ORDER BY priority DESC, anomaly_score DESC',

      QUERY "What is the total estimated overpayment?"
        AS 'SELECT SUM(ai_estimated_overpayment) AS total_estimated_overpayment,
                   COUNT(*) AS flagged_case_count,
                   AVG(anomaly_score) AS avg_anomaly_score
            FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_SUSPECTED_OVERPAYMENT_CASES
            WHERE anomaly_type IS NOT NULL',

      QUERY "Which providers have the highest anomaly rates?"
        AS 'SELECT provider_name, specialty, risk_tier, total_claims, flagged_claims,
                   anomaly_rate, total_estimated_overpayment, avg_anomaly_score, peer_anomaly_percentile
            FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_PROVIDER_OUTLIER_SUMMARY
            WHERE flagged_claims > 0
            ORDER BY anomaly_rate DESC',

      QUERY "Show recovery status and amounts"
        AS 'SELECT case_id, claim_id, recovery_status, recovery_method, amount_sought, amount_recovered,
                   confirmed_overpayment_amount
            FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_SUSPECTED_OVERPAYMENT_CASES
            WHERE recovery_status IS NOT NULL',

      QUERY "What is the model precision?"
        AS 'SELECT final_outcome_label, claim_count, avg_anomaly_score, precision_score, false_positive_rate
            FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_MODEL_FEEDBACK_SUMMARY',

      QUERY "Which claims have missing documentation?"
        AS 'SELECT claim_id, therapy_category, anomaly_type, total_documents, missing_documents,
                   completeness_ratio, missing_required_docs
            FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_DOCUMENT_COMPLETENESS
            WHERE missing_documents > 0 OR missing_required_docs IS NOT NULL
            ORDER BY completeness_ratio ASC',

      QUERY "Show all CAR-T therapy claims"
        AS 'SELECT claim_id, provider_name, total_billed_amount, total_paid_amount,
                   diagnosis_description, service_from_date, line_count, total_units, cms_variance
            FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_HIGH_COST_THERAPY_CLAIMS
            WHERE therapy_category = ''CAR-T Cell Therapy''',

      QUERY "What bundling violations exist?"
        AS 'SELECT claim_id, line_1_procedure, line_2_procedure, rule_type, rule_description,
                   severity_weight, line_1_billed, line_2_billed, combined_billed, therapy_category
            FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_CLAIM_LINE_BUNDLING_EXCEPTIONS
            ORDER BY severity_weight DESC',

      QUERY "Summarize cases by therapy category"
        AS 'SELECT therapy_category, COUNT(*) AS case_count,
                   SUM(ai_estimated_overpayment) AS total_est_overpayment,
                   AVG(anomaly_score) AS avg_score,
                   SUM(CASE WHEN case_status = ''OPEN'' THEN 1 ELSE 0 END) AS open_cases,
                   SUM(CASE WHEN case_status = ''CLOSED'' THEN 1 ELSE 0 END) AS closed_cases
            FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_SUSPECTED_OVERPAYMENT_CASES
            GROUP BY therapy_category
            ORDER BY total_est_overpayment DESC'
    )

    SQL GENERATION INSTRUCTIONS (
      'If no date filter is specified, include all available data.',
      'When asked about "flagged" or "anomalous" claims, filter where anomaly_type IS NOT NULL.',
      'When asked about overpayment, use the ai_estimated_overpayment column for ML estimates or confirmed_overpayment_amount for confirmed amounts.',
      'Priority values are HIGH, MEDIUM, LOW. Case statuses are OPEN, IN_REVIEW, CLOSED.',
      'Anomaly scores range from 0.0 to 1.0. Scores >= 0.7 are considered high-priority.',
      'The 7 therapy categories are: Gene Therapy, CAR-T Cell Therapy, Oncology Infusion, Enzyme Replacement, Hemophilia Factor, Orphan Biologics, Transplant Support.',
      'When asked about recovery, distinguish between amount_sought (requested) and amount_recovered (actually received).',
      'For provider comparisons, use the peer_anomaly_percentile to rank against peers.'
    );

-- Grant access
USE ROLE ACCOUNTADMIN;
GRANT SELECT ON SEMANTIC VIEW DEMO_HIGH_COST_CLAIMS.ANALYTICS.HCA_SEMANTIC_VIEW TO ROLE APP_HCA_SVC_ROLE;
