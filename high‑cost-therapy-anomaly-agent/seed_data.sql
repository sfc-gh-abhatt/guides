/*
================================================================================
  DEMO_HIGH_COST_CLAIMS — Sample Data Seed Script
================================================================================

  PURPOSE:
    Populates all tables with synthetic sample data so that the ANALYTICS and
    CURATED views return meaningful results for a Cortex Agent to query.

  HOW TO RUN:
    1. Run setup.sql FIRST to create the database, schemas, tables, and views.
    2. Log in to Snowflake and open a SQL Worksheet.
    3. Set your role and warehouse:
         USE ROLE APP_HCA_ADMIN_ROLE;
         USE WAREHOUSE <your_warehouse>;
    4. Paste this entire script and click "Run All" (Ctrl+Shift+Enter).
    5. Verify with:
         SELECT COUNT(*) FROM DEMO_HIGH_COST_CLAIMS.RAW.CLAIM_HEADER;
         SELECT * FROM DEMO_HIGH_COST_CLAIMS.ANALYTICS.VW_SUSPECTED_OVERPAYMENT_CASES LIMIT 5;

  DATA VOLUME:
    This script inserts a representative subset designed for demo/testing:
      - 10 patients, 5 providers, 8 procedure codes, 5 drugs, 7 diagnoses
      - 15 claims with ~60 claim lines, ~45 documents, 8 EHR summaries
      - 15 anomaly results (~8 flagged), 6 cases, 4 reviews, 2 recoveries
      - 5 model feedback records
    All IDs are cross-referenced so every ANALYTICS view returns rows.

  NOTES:
    - All data is entirely synthetic/fictional.
    - Dates are set in Q1-Q2 2026 for freshness.
    - Run this script only ONCE after setup.sql. Re-running will cause
      duplicate key errors. To re-seed, re-run setup.sql first (which
      drops and recreates all tables).

================================================================================
*/

USE ROLE APP_HCA_ADMIN_ROLE;
USE DATABASE DEMO_HIGH_COST_CLAIMS;

-- =============================================================================
-- REF Tables
-- =============================================================================

INSERT INTO REF.REF_PATIENT VALUES
(1001, '55-64', 'M', 'CA', 'Medicare Advantage', 'Gold HMO Plus', 'HIGH', 'Urban Chronic'),
(1002, '45-54', 'F', 'TX', 'Commercial', 'PPO Standard', 'MEDIUM', 'Suburban Family'),
(1003, '65-74', 'M', 'NY', 'Medicare FFS', 'Original Medicare', 'HIGH', 'Urban Elderly'),
(1004, '35-44', 'F', 'FL', 'Medicaid', 'Managed Medicaid', 'LOW', 'Rural Access'),
(1005, '55-64', 'F', 'PA', 'Commercial', 'EPO Select', 'HIGH', 'Urban Chronic'),
(1006, '25-34', 'M', 'IL', 'Commercial', 'HSA Bronze', 'LOW', 'Young Professional'),
(1007, '65-74', 'F', 'OH', 'Medicare Advantage', 'Silver PPO', 'MEDIUM', 'Suburban Elderly'),
(1008, '45-54', 'M', 'WA', 'Commercial', 'Platinum PPO', 'MEDIUM', 'Suburban Family'),
(1009, '55-64', 'F', 'GA', 'Medicare FFS', 'Original Medicare', 'HIGH', 'Urban Chronic'),
(1010, '35-44', 'M', 'AZ', 'Commercial', 'Gold HMO Plus', 'LOW', 'Rural Access');

INSERT INTO REF.REF_PROVIDER VALUES
(2001, 'Dr. Sarah Chen', '1234567890', 'Hematology/Oncology', 'Pacific Cancer Institute', 'Hospital Outpatient', 'CA', 'HIGH', 0.82, '2024-01-15 00:00:00'),
(2002, 'Dr. Michael Torres', '2345678901', 'Medical Genetics', 'GeneTech Medical Center', 'Academic Medical Center', 'TX', 'MEDIUM', 0.45, '2024-03-01 00:00:00'),
(2003, 'Dr. Jennifer Walsh', '3456789012', 'Neurology', 'Northeast Neuro Associates', 'Specialty Clinic', 'NY', 'LOW', 0.28, '2024-06-10 00:00:00'),
(2004, 'Dr. Robert Kim', '4567890123', 'Transplant Surgery', 'Southeast Transplant Center', 'Hospital Inpatient', 'FL', 'MEDIUM', 0.55, '2024-02-20 00:00:00'),
(2005, 'Dr. Amanda Patel', '5678901234', 'Hematology/Oncology', 'Midwest Blood Disorders Clinic', 'Specialty Clinic', 'OH', 'HIGH', 0.91, '2024-04-05 00:00:00');

INSERT INTO REF.REF_PROCEDURE_CODE VALUES
('96413', 'CPT', 'Chemotherapy IV infusion, first hour', 'Oncology Infusion', 'Hospital Outpatient', 1, 4, 287.50, 'CHEMO_INF', TRUE, FALSE),
('96415', 'CPT', 'Chemotherapy IV infusion, each additional hour', 'Oncology Infusion', 'Hospital Outpatient', 1, 6, 143.75, 'CHEMO_INF', FALSE, TRUE),
('96401', 'CPT', 'Chemotherapy subcutaneous/intramuscular', 'Oncology Infusion', 'Specialty Clinic', 1, 2, 195.00, 'CHEMO_SC', TRUE, FALSE),
('0537T', 'CPT', 'CAR-T cell therapy, harvesting', 'CAR-T Cell Therapy', 'Academic Medical Center', 1, 1, 5400.00, 'CART', TRUE, FALSE),
('0540T', 'CPT', 'CAR-T cell therapy, infusion', 'CAR-T Cell Therapy', 'Hospital Inpatient', 1, 1, 89000.00, 'CART', TRUE, FALSE),
('96365', 'CPT', 'IV infusion therapy, first hour', 'Enzyme Replacement', 'Hospital Outpatient', 1, 8, 215.00, 'ENZ_INF', TRUE, FALSE),
('96366', 'CPT', 'IV infusion therapy, each additional hour', 'Enzyme Replacement', 'Hospital Outpatient', 1, 12, 107.50, 'ENZ_INF', FALSE, TRUE),
('38241', 'CPT', 'Hematopoietic stem cell transplant', 'Transplant Support', 'Hospital Inpatient', 1, 1, 42000.00, 'TRANSPLANT', TRUE, FALSE);

INSERT INTO REF.REF_DRUG VALUES
('DRG001', '1234567890123', 'Zynteglo (betibeglogene)', 'Gene Therapy', 'Hemoglobinopathies', 178000.00, 'IV Infusion'),
('DRG002', '2345678901234', 'Kymriah (tisagenlecleucel)', 'CAR-T Cell Therapy', 'Lymphoma/Leukemia', 475000.00, 'IV Infusion'),
('DRG003', '3456789012345', 'Cerezyme (imiglucerase)', 'Enzyme Replacement', 'Lysosomal Storage Disorders', 3200.00, 'IV Infusion'),
('DRG004', '4567890123456', 'Hemlibra (emicizumab)', 'Hemophilia Factor', 'Hemophilia A', 6800.00, 'Subcutaneous'),
('DRG005', '5678901234567', 'Keytruda (pembrolizumab)', 'Oncology Infusion', 'Solid Tumors', 11200.00, 'IV Infusion');

INSERT INTO REF.REF_DIAGNOSIS_CODE VALUES
('C83.30', 'Diffuse large B-cell lymphoma, unspecified site', 'Lymphoma/Leukemia', FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
('C91.00', 'Acute lymphoblastic leukemia not in remission', 'Lymphoma/Leukemia', FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE),
('D66', 'Hereditary factor VIII deficiency (Hemophilia A)', 'Hemophilia', FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE),
('E75.22', 'Gaucher disease', 'Lysosomal Storage Disorders', FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE),
('D57.1', 'Sickle-cell disease without crisis', 'Hemoglobinopathies', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
('C34.90', 'Malignant neoplasm of unspecified lung', 'Solid Tumors', FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE),
('T86.00', 'Unspecified complication of bone marrow transplant', 'Transplant Complications', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE);

INSERT INTO REF.REF_ANOMALY_TYPE_CONFIG VALUES
('DUPLICATE_BILLING', 'Duplicate Billing', 'Same service billed multiple times for same date/patient', 0.7, TRUE, TRUE),
('UNBUNDLING', 'Unbundling', 'Separately billing services that should be bundled per CCI rules', 0.6, FALSE, TRUE),
('EXCESSIVE_UNITS', 'Excessive Units', 'Units billed exceed typical clinical range for the procedure', 0.65, FALSE, TRUE),
('FEE_SCHEDULE_VARIANCE', 'Fee Schedule Variance', 'Billed amount significantly exceeds Medicare fee schedule', 0.5, FALSE, TRUE),
('CODING_INCONSISTENCY', 'Coding Inconsistency', 'Procedure code does not match diagnosis or clinical setting', 0.6, FALSE, TRUE),
('DRUG_DIAG_MISMATCH', 'Drug-Diagnosis Mismatch', 'Drug not clinically appropriate for the billed diagnosis', 0.7, TRUE, TRUE),
('INCORRECT_PROCEDURE_COMBO', 'Incorrect Procedure Combination', 'Invalid combination of procedure codes on same claim', 0.55, FALSE, TRUE),
('PROVIDER_OUTLIER', 'Provider Outlier', 'Provider billing pattern deviates significantly from specialty peers', 0.75, TRUE, TRUE);

INSERT INTO REF.REF_BUNDLING_RULE VALUES
(1, '96413', '96415', 'CCI_COLUMN_1', 'Chemo infusion first hour bundles with additional hours', TRUE, TRUE, 0.6, '2026-01-01', NULL),
(2, '96413', '96401', 'CCI_COLUMN_2', 'IV chemo and SC chemo on same date - mutually exclusive', FALSE, FALSE, 0.8, '2026-01-01', NULL),
(3, '96365', '96366', 'CCI_COLUMN_1', 'Enzyme infusion first hour bundles with additional hours', TRUE, TRUE, 0.5, '2026-01-01', NULL),
(4, '0537T', '0540T', 'SEQUENTIAL', 'CAR-T harvest must precede infusion by 14+ days', TRUE, FALSE, 0.9, '2026-01-01', NULL),
(5, '96413', '96365', 'CCI_COLUMN_2', 'Chemo infusion and enzyme infusion same day - review required', FALSE, FALSE, 0.7, '2026-01-01', NULL);

INSERT INTO REF.REF_CMS_2026_FEE_SCHEDULE VALUES
('96413', 2026, 287.50, 'G', 1.0, '0', '0', 'XXX', 'synthetic_demo_based_on_2026_structure'),
('96415', 2026, 143.75, 'G', 1.0, '0', '5', 'ZZZ', 'synthetic_demo_based_on_2026_structure'),
('96401', 2026, 195.00, 'G', 1.0, '0', '0', 'XXX', 'synthetic_demo_based_on_2026_structure'),
('0537T', 2026, 5400.00, 'G', 1.0, '0', '0', 'XXX', 'synthetic_demo_based_on_2026_structure'),
('0540T', 2026, 89000.00, 'G', 1.0, '0', '0', 'XXX', 'synthetic_demo_based_on_2026_structure'),
('96365', 2026, 215.00, 'G', 1.0, '0', '0', 'XXX', 'synthetic_demo_based_on_2026_structure'),
('96366', 2026, 107.50, 'G', 1.0, '0', '5', 'ZZZ', 'synthetic_demo_based_on_2026_structure'),
('38241', 2026, 42000.00, 'G', 1.0, '0', '0', 'XXX', 'synthetic_demo_based_on_2026_structure');

INSERT INTO REF.REF_REQUIRED_DOCUMENT_RULE VALUES
(1, 'CAR-T Cell Therapy', '*', 'Prior Authorization', 1),
(2, 'CAR-T Cell Therapy', '*', 'Pathology Report', 2),
(3, 'CAR-T Cell Therapy', '*', 'Clinical Notes', 3),
(4, 'Gene Therapy', '*', 'Prior Authorization', 1),
(5, 'Gene Therapy', '*', 'Lab Results', 2),
(6, 'Oncology Infusion', '*', 'Clinical Notes', 1),
(7, 'Oncology Infusion', 'EXCESSIVE_UNITS', 'Treatment Protocol', 2),
(8, 'Enzyme Replacement', '*', 'Prior Authorization', 1),
(9, 'Enzyme Replacement', '*', 'Lab Results', 2),
(10, 'Hemophilia Factor', '*', 'Clinical Notes', 1),
(11, 'Transplant Support', '*', 'Prior Authorization', 1),
(12, 'Transplant Support', '*', 'Discharge Summary', 2);

-- =============================================================================
-- RAW Tables
-- =============================================================================

INSERT INTO RAW.CLAIM_HEADER VALUES
('CLM-2026-0001', 1001, 2001, 'Professional', '131', 'Hospital Outpatient', NULL, NULL, '2026-01-15', '2026-01-15', '2026-01-20', '2026-02-01', 'C34.90', NULL, NULL, 'Oncology Infusion', 45800.00, 38500.00, 36000.00, 'PAID', TRUE, 25000.00, 'DEMO_GENERATOR'),
('CLM-2026-0002', 1002, 2002, 'Professional', '131', 'Academic Medical Center', NULL, NULL, '2026-01-22', '2026-01-22', '2026-01-25', '2026-02-10', 'C83.30', NULL, NULL, 'CAR-T Cell Therapy', 520000.00, 490000.00, 475000.00, 'PAID', TRUE, 100000.00, 'DEMO_GENERATOR'),
('CLM-2026-0003', 1003, 2003, 'Professional', '131', 'Specialty Clinic', NULL, NULL, '2026-02-03', '2026-02-03', '2026-02-05', '2026-02-20', 'E75.22', NULL, NULL, 'Enzyme Replacement', 28500.00, 24000.00, 22800.00, 'PAID', TRUE, 20000.00, 'DEMO_GENERATOR'),
('CLM-2026-0004', 1004, 2004, 'Institutional', '111', 'Hospital Inpatient', '2026-02-10', '2026-02-25', '2026-02-10', '2026-02-25', '2026-03-01', '2026-03-15', 'T86.00', 'D57.1', NULL, 'Transplant Support', 385000.00, 350000.00, 340000.00, 'PAID', TRUE, 200000.00, 'DEMO_GENERATOR'),
('CLM-2026-0005', 1005, 2005, 'Professional', '131', 'Specialty Clinic', NULL, NULL, '2026-02-15', '2026-02-15', '2026-02-18', '2026-03-01', 'D66', NULL, NULL, 'Hemophilia Factor', 68000.00, 62000.00, 58000.00, 'PAID', TRUE, 50000.00, 'DEMO_GENERATOR'),
('CLM-2026-0006', 1006, 2001, 'Professional', '131', 'Hospital Outpatient', NULL, NULL, '2026-03-01', '2026-03-01', '2026-03-03', '2026-03-18', 'C91.00', NULL, NULL, 'Oncology Infusion', 52300.00, 44000.00, 41500.00, 'PAID', TRUE, 25000.00, 'DEMO_GENERATOR'),
('CLM-2026-0007', 1007, 2002, 'Professional', '131', 'Academic Medical Center', NULL, NULL, '2026-03-05', '2026-03-05', '2026-03-08', NULL, 'D57.1', NULL, NULL, 'Gene Therapy', 890000.00, 820000.00, 0.00, 'PENDING', TRUE, 500000.00, 'DEMO_GENERATOR'),
('CLM-2026-0008', 1008, 2005, 'Professional', '131', 'Specialty Clinic', NULL, NULL, '2026-03-10', '2026-03-10', '2026-03-12', '2026-03-28', 'C34.90', 'C83.30', NULL, 'Oncology Infusion', 38200.00, 33000.00, 31000.00, 'PAID', TRUE, 25000.00, 'DEMO_GENERATOR'),
('CLM-2026-0009', 1009, 2003, 'Professional', '131', 'Specialty Clinic', NULL, NULL, '2026-03-18', '2026-03-18', '2026-03-20', '2026-04-05', 'E75.22', NULL, NULL, 'Enzyme Replacement', 32100.00, 27500.00, 26000.00, 'PAID', TRUE, 20000.00, 'DEMO_GENERATOR'),
('CLM-2026-0010', 1010, 2001, 'Professional', '131', 'Hospital Outpatient', NULL, NULL, '2026-03-25', '2026-03-25', '2026-03-28', '2026-04-12', 'C34.90', NULL, NULL, 'Oncology Infusion', 61500.00, 52000.00, 49000.00, 'PAID', TRUE, 25000.00, 'DEMO_GENERATOR'),
('CLM-2026-0011', 1001, 2005, 'Professional', '131', 'Specialty Clinic', NULL, NULL, '2026-04-02', '2026-04-02', '2026-04-04', '2026-04-20', 'D66', NULL, NULL, 'Hemophilia Factor', 72000.00, 65000.00, 61500.00, 'PAID', TRUE, 50000.00, 'DEMO_GENERATOR'),
('CLM-2026-0012', 1003, 2001, 'Professional', '131', 'Hospital Outpatient', NULL, NULL, '2026-04-10', '2026-04-10', '2026-04-12', '2026-04-28', 'C91.00', NULL, NULL, 'Oncology Infusion', 47900.00, 41000.00, 38500.00, 'PAID', TRUE, 25000.00, 'DEMO_GENERATOR'),
('CLM-2026-0013', 1005, 2002, 'Professional', '131', 'Academic Medical Center', NULL, NULL, '2026-04-15', '2026-04-15', '2026-04-18', NULL, 'C83.30', NULL, NULL, 'CAR-T Cell Therapy', 498000.00, 475000.00, 0.00, 'UNDER REVIEW', TRUE, 100000.00, 'DEMO_GENERATOR'),
('CLM-2026-0014', 1002, 2003, 'Professional', '131', 'Specialty Clinic', NULL, NULL, '2026-04-22', '2026-04-22', '2026-04-24', '2026-05-10', 'E75.22', NULL, NULL, 'Enzyme Replacement', 29800.00, 25500.00, 24000.00, 'PAID', TRUE, 20000.00, 'DEMO_GENERATOR'),
('CLM-2026-0015', 1004, 2004, 'Institutional', '111', 'Hospital Inpatient', '2026-05-01', '2026-05-12', '2026-05-01', '2026-05-12', '2026-05-15', NULL, 'T86.00', NULL, NULL, 'Transplant Support', 410000.00, 375000.00, 0.00, 'PENDING', TRUE, 200000.00, 'DEMO_GENERATOR');

INSERT INTO RAW.CLAIM_LINE VALUES
('CLM-2026-0001-L1', 'CLM-2026-0001', 1, '96413', 'DRG005', '0260', NULL, NULL, '1', 3, 33600.00, 28000.00, 26500.00, 862.50, '2026-01-15', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0001-L2', 'CLM-2026-0001', 2, '96415', NULL, '0260', NULL, NULL, '1', 5, 12200.00, 10500.00, 9500.00, 718.75, '2026-01-15', 'PAID', NULL, TRUE, 'EXCESSIVE_UNITS'),
('CLM-2026-0002-L1', 'CLM-2026-0002', 1, '0537T', 'DRG002', NULL, NULL, NULL, '1', 1, 45000.00, 40000.00, 38000.00, 5400.00, '2026-01-22', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0002-L2', 'CLM-2026-0002', 2, '0540T', 'DRG002', NULL, NULL, NULL, '1', 1, 475000.00, 450000.00, 437000.00, 89000.00, '2026-01-22', 'PAID', NULL, TRUE, 'FEE_SCHEDULE_VARIANCE'),
('CLM-2026-0003-L1', 'CLM-2026-0003', 1, '96365', 'DRG003', '0260', NULL, NULL, '1', 6, 19200.00, 16000.00, 15200.00, 1290.00, '2026-02-03', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0003-L2', 'CLM-2026-0003', 2, '96366', NULL, '0260', NULL, NULL, '1', 8, 9300.00, 8000.00, 7600.00, 860.00, '2026-02-03', 'PAID', NULL, TRUE, 'EXCESSIVE_UNITS'),
('CLM-2026-0004-L1', 'CLM-2026-0004', 1, '38241', NULL, '0362', NULL, NULL, '1', 1, 385000.00, 350000.00, 340000.00, 42000.00, '2026-02-10', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0005-L1', 'CLM-2026-0005', 1, '96401', 'DRG004', NULL, '26', NULL, '1', 10, 68000.00, 62000.00, 58000.00, 1950.00, '2026-02-15', 'PAID', NULL, TRUE, 'EXCESSIVE_UNITS'),
('CLM-2026-0006-L1', 'CLM-2026-0006', 1, '96413', 'DRG005', '0260', NULL, NULL, '1', 2, 22400.00, 19000.00, 18000.00, 575.00, '2026-03-01', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0006-L2', 'CLM-2026-0006', 2, '96415', NULL, '0260', NULL, NULL, '1', 4, 11500.00, 9800.00, 9200.00, 575.00, '2026-03-01', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0006-L3', 'CLM-2026-0006', 3, '96401', NULL, '0260', NULL, NULL, '1', 2, 18400.00, 15200.00, 14300.00, 390.00, '2026-03-01', 'PAID', NULL, TRUE, 'UNBUNDLING'),
('CLM-2026-0007-L1', 'CLM-2026-0007', 1, '96365', 'DRG001', '0260', NULL, NULL, '1', 1, 890000.00, 820000.00, 0.00, 215.00, '2026-03-05', 'PENDING', NULL, FALSE, NULL),
('CLM-2026-0008-L1', 'CLM-2026-0008', 1, '96413', 'DRG005', '0260', NULL, NULL, '1', 2, 22400.00, 19000.00, 18000.00, 575.00, '2026-03-10', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0008-L2', 'CLM-2026-0008', 2, '96415', NULL, '0260', NULL, NULL, '1', 3, 8600.00, 7500.00, 7000.00, 431.25, '2026-03-10', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0008-L3', 'CLM-2026-0008', 3, '96413', 'DRG005', '0260', NULL, NULL, '2', 2, 7200.00, 6500.00, 6000.00, 575.00, '2026-03-10', 'PAID', NULL, TRUE, 'DUPLICATE_BILLING'),
('CLM-2026-0009-L1', 'CLM-2026-0009', 1, '96365', 'DRG003', '0260', NULL, NULL, '1', 7, 22400.00, 19000.00, 18000.00, 1505.00, '2026-03-18', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0009-L2', 'CLM-2026-0009', 2, '96366', NULL, '0260', NULL, NULL, '1', 9, 9700.00, 8500.00, 8000.00, 967.50, '2026-03-18', 'PAID', NULL, TRUE, 'EXCESSIVE_UNITS'),
('CLM-2026-0010-L1', 'CLM-2026-0010', 1, '96413', 'DRG005', '0260', NULL, NULL, '1', 4, 44800.00, 38000.00, 36000.00, 1150.00, '2026-03-25', 'PAID', NULL, TRUE, 'EXCESSIVE_UNITS'),
('CLM-2026-0010-L2', 'CLM-2026-0010', 2, '96415', NULL, '0260', NULL, NULL, '1', 6, 16700.00, 14000.00, 13000.00, 862.50, '2026-03-25', 'PAID', NULL, TRUE, 'EXCESSIVE_UNITS'),
('CLM-2026-0011-L1', 'CLM-2026-0011', 1, '96401', 'DRG004', NULL, '26', NULL, '1', 8, 72000.00, 65000.00, 61500.00, 1560.00, '2026-04-02', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0012-L1', 'CLM-2026-0012', 1, '96413', 'DRG005', '0260', NULL, NULL, '1', 3, 33600.00, 28500.00, 27000.00, 862.50, '2026-04-10', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0012-L2', 'CLM-2026-0012', 2, '96415', NULL, '0260', NULL, NULL, '1', 4, 14300.00, 12500.00, 11500.00, 575.00, '2026-04-10', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0013-L1', 'CLM-2026-0013', 1, '0537T', 'DRG002', NULL, NULL, NULL, '1', 1, 48000.00, 45000.00, 0.00, 5400.00, '2026-04-15', 'UNDER REVIEW', NULL, FALSE, NULL),
('CLM-2026-0013-L2', 'CLM-2026-0013', 2, '0540T', 'DRG002', NULL, NULL, NULL, '1', 1, 450000.00, 430000.00, 0.00, 89000.00, '2026-04-15', 'UNDER REVIEW', NULL, TRUE, 'DRUG_DIAG_MISMATCH'),
('CLM-2026-0014-L1', 'CLM-2026-0014', 1, '96365', 'DRG003', '0260', NULL, NULL, '1', 5, 16000.00, 14000.00, 13200.00, 1075.00, '2026-04-22', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0014-L2', 'CLM-2026-0014', 2, '96366', NULL, '0260', NULL, NULL, '1', 7, 13800.00, 11500.00, 10800.00, 752.50, '2026-04-22', 'PAID', NULL, FALSE, NULL),
('CLM-2026-0015-L1', 'CLM-2026-0015', 1, '38241', NULL, '0362', NULL, NULL, '1', 1, 410000.00, 375000.00, 0.00, 42000.00, '2026-05-01', 'PENDING', NULL, FALSE, NULL);

INSERT INTO RAW.CLAIM_DOCUMENT VALUES
('DOC-001', 'CLM-2026-0001', 'Clinical Notes', 'EHR System', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc001.pdf', 'Oncology treatment plan for lung cancer. Weekly pembrolizumab infusion cycle 3.', '2026-01-14'),
('DOC-002', 'CLM-2026-0001', 'Prior Authorization', 'Payer Portal', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc002.pdf', 'PA approved for 6 cycles of pembrolizumab. Valid through 2026-06-30.', '2026-01-10'),
('DOC-003', 'CLM-2026-0002', 'Prior Authorization', 'Payer Portal', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc003.pdf', 'PA approved for Kymriah CAR-T therapy. Single administration.', '2026-01-18'),
('DOC-004', 'CLM-2026-0002', 'Pathology Report', 'Lab System', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc004.pdf', 'DLBCL confirmed. CD19 positive. Eligible for CAR-T.', '2026-01-15'),
('DOC-005', 'CLM-2026-0002', 'Clinical Notes', 'EHR System', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc005.pdf', 'Failed 2 prior lines of therapy. CAR-T indicated per NCCN guidelines.', '2026-01-20'),
('DOC-006', 'CLM-2026-0003', 'Prior Authorization', 'Payer Portal', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc006.pdf', 'PA for Cerezyme enzyme replacement. Biweekly infusions approved.', '2026-01-28'),
('DOC-007', 'CLM-2026-0003', 'Lab Results', 'Lab System', 'MISSING', 'NOT_ATTEMPTED', NULL, NULL, NULL),
('DOC-008', 'CLM-2026-0004', 'Prior Authorization', 'Payer Portal', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc008.pdf', 'Stem cell transplant approved for sickle cell disease.', '2026-02-05'),
('DOC-009', 'CLM-2026-0004', 'Discharge Summary', 'EHR System', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc009.pdf', 'Post-transplant day 15. Engraftment confirmed. Discharged stable.', '2026-02-25'),
('DOC-010', 'CLM-2026-0005', 'Clinical Notes', 'EHR System', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc010.pdf', 'Hemophilia A severe. Hemlibra prophylaxis dose adjustment.', '2026-02-14'),
('DOC-011', 'CLM-2026-0006', 'Clinical Notes', 'EHR System', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc011.pdf', 'ALL treatment cycle 2. Combination chemo per protocol.', '2026-02-28'),
('DOC-012', 'CLM-2026-0006', 'Treatment Protocol', 'Payer Portal', 'MISSING', 'FAILED', NULL, NULL, NULL),
('DOC-013', 'CLM-2026-0007', 'Prior Authorization', 'Payer Portal', 'DELAYED', 'IN_PROGRESS', NULL, NULL, NULL),
('DOC-014', 'CLM-2026-0007', 'Lab Results', 'Lab System', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc014.pdf', 'Hemoglobin genotype confirmed. Eligible for Zynteglo gene therapy.', '2026-03-01'),
('DOC-015', 'CLM-2026-0008', 'Clinical Notes', 'EHR System', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc015.pdf', 'Lung cancer stage IIIB. Pembrolizumab + carboplatin regimen.', '2026-03-08'),
('DOC-016', 'CLM-2026-0009', 'Prior Authorization', 'Payer Portal', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc016.pdf', 'Cerezyme renewal approved. Dose 60 U/kg biweekly.', '2026-03-15'),
('DOC-017', 'CLM-2026-0009', 'Lab Results', 'Lab System', 'INCOMPLETE', 'RETRIEVED', 's3://demo/doc017.pdf', 'Partial results. Glucocerebrosidase activity pending.', '2026-03-16'),
('DOC-018', 'CLM-2026-0010', 'Clinical Notes', 'EHR System', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc018.pdf', 'Pembrolizumab cycle 5. Tumor response partial. Continuing therapy.', '2026-03-24'),
('DOC-019', 'CLM-2026-0011', 'Clinical Notes', 'EHR System', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc019.pdf', 'Hemophilia A. Factor VIII inhibitor titer negative. Hemlibra maintenance.', '2026-04-01'),
('DOC-020', 'CLM-2026-0013', 'Prior Authorization', 'Payer Portal', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc020.pdf', 'Kymriah approved for relapsed DLBCL. Second CAR-T eligible.', '2026-04-10'),
('DOC-021', 'CLM-2026-0013', 'Pathology Report', 'Lab System', 'MISSING', 'NOT_ATTEMPTED', NULL, NULL, NULL),
('DOC-022', 'CLM-2026-0013', 'Clinical Notes', 'EHR System', 'AVAILABLE', 'RETRIEVED', 's3://demo/doc022.pdf', 'DLBCL relapse after prior CHOP-R. CD19 re-confirmed.', '2026-04-12'),
('DOC-023', 'CLM-2026-0015', 'Prior Authorization', 'Payer Portal', 'DELAYED', 'IN_PROGRESS', NULL, NULL, NULL),
('DOC-024', 'CLM-2026-0015', 'Discharge Summary', 'EHR System', 'MISSING', 'NOT_ATTEMPTED', NULL, NULL, NULL);

INSERT INTO RAW.EHR_SUMMARY VALUES
('EHR-001', 'CLM-2026-0001', 1001, 'ENC-20260115-A', 'Patient presents for cycle 3 of pembrolizumab 200mg IV infusion for stage IIIB non-small cell lung cancer. Prior imaging shows partial response. No immune-related adverse events noted. Continue current regimen per NCCN guidelines.', 2001, 'Non-small cell lung cancer stage IIIB', '2025-11-01', NULL),
('EHR-002', 'CLM-2026-0002', 1002, 'ENC-20260122-B', 'CAR-T cell infusion day. Patient received tisagenlecleucel (Kymriah) for relapsed/refractory DLBCL after 2 prior lines of therapy. Leukapheresis performed 21 days prior. CRS monitoring protocol initiated. Tocilizumab available at bedside.', 2002, 'Diffuse large B-cell lymphoma, relapsed', '2026-01-01', '2026-02-22'),
('EHR-003', 'CLM-2026-0004', 1004, 'ENC-20260210-C', 'Hematopoietic stem cell transplant for sickle cell disease. HLA-matched sibling donor identified. Myeloablative conditioning with busulfan/cyclophosphamide completed. Stem cell infusion day 0. Close monitoring for engraftment and GVHD.', 2004, 'Sickle cell disease - curative transplant', '2026-02-10', '2026-02-25'),
('EHR-004', 'CLM-2026-0005', 1005, 'ENC-20260215-D', 'Hemophilia A patient on emicizumab (Hemlibra) prophylaxis. Current dose 3mg/kg SC every 2 weeks. No breakthrough bleeds in past 6 months. Factor VIII inhibitor titer negative. Annual joint assessment shows no progression.', 2005, 'Hemophilia A with inhibitor history', '2025-08-01', NULL),
('EHR-005', 'CLM-2026-0006', 1006, 'ENC-20260301-E', 'Acute lymphoblastic leukemia induction cycle 2. Receiving combination chemotherapy per institutional protocol. Day 15 bone marrow shows early response. Continue planned therapy. Monitor for tumor lysis.', 2001, 'B-cell ALL, initial treatment', '2026-02-01', NULL),
('EHR-006', 'CLM-2026-0008', 1008, 'ENC-20260310-F', 'Cycle 5 of pembrolizumab plus carboplatin for advanced lung cancer. CT scan shows stable disease. Maintaining performance status ECOG 1. Plan to continue through cycle 6 then reassess.', 2005, 'Non-small cell lung cancer with DLBCL history', '2025-10-15', NULL),
('EHR-007', 'CLM-2026-0010', 1010, 'ENC-20260325-G', 'Pembrolizumab monotherapy cycle 5 for metastatic non-small cell lung cancer. PD-L1 TPS >50%. Partial response maintained. Grade 1 fatigue only adverse event. Continue therapy.', 2001, 'Metastatic NSCLC, PD-L1 high', '2025-11-20', NULL),
('EHR-008', 'CLM-2026-0013', 1005, 'ENC-20260415-H', 'Second CAR-T infusion for relapsed DLBCL. Prior Kymriah administered 14 months ago with initial CR followed by relapse at month 10. CD19 expression confirmed on re-biopsy. Proceeding with re-treatment per compassionate use protocol.', 2002, 'DLBCL relapse post-CAR-T', '2026-04-01', NULL);

INSERT INTO RAW.PROVIDER_BILLING_HISTORY_DAILY VALUES
(2001, '2026-01-15', 'Oncology Infusion', 3, 48500.00, 3.2, 0.12, 0.85),
(2001, '2026-03-01', 'Oncology Infusion', 2, 56900.00, 3.8, 0.15, 0.90),
(2001, '2026-03-25', 'Oncology Infusion', 2, 54700.00, 4.5, 0.18, 0.92),
(2002, '2026-01-22', 'CAR-T Cell Therapy', 1, 520000.00, 1.0, 0.05, 0.60),
(2002, '2026-03-05', 'Gene Therapy', 1, 890000.00, 1.0, 0.08, 0.65),
(2003, '2026-02-03', 'Enzyme Replacement', 2, 30300.00, 7.5, 0.10, 0.70),
(2003, '2026-03-18', 'Enzyme Replacement', 1, 32100.00, 8.0, 0.12, 0.75),
(2004, '2026-02-10', 'Transplant Support', 1, 385000.00, 1.0, 0.03, 0.50),
(2005, '2026-02-15', 'Hemophilia Factor', 2, 70000.00, 9.0, 0.20, 0.95),
(2005, '2026-03-10', 'Oncology Infusion', 1, 38200.00, 2.3, 0.08, 0.55);

-- =============================================================================
-- CURATED Tables
-- =============================================================================

INSERT INTO CURATED.CLAIM_ANOMALY_RESULT VALUES
('RES-001', 'CLM-2026-0001', '2026-01-21 08:30:00', 0.72, 'EXCESSIVE_UNITS', 'Units exceed typical range for 96415', 8200.00, 0.78, '["Clinical Notes","Treatment Protocol"]', 'INVESTIGATE', 'v2.4.1-demo', 'Claim line 2 billed 5 units of 96415 (additional chemo hours); typical max is 6 but combined with high base amount suggests over-treatment or upcoding.'),
('RES-002', 'CLM-2026-0002', '2026-01-26 09:15:00', 0.85, 'FEE_SCHEDULE_VARIANCE', 'CAR-T billed amount exceeds expected by 434%', 31000.00, 0.88, '["Prior Authorization","Pathology Report"]', 'ESCALATE', 'v2.4.1-demo', 'Total CAR-T claim of $520K exceeds CMS expected of $94.4K. Variance driven by drug acquisition cost markup and facility fees beyond standard rates.'),
('RES-003', 'CLM-2026-0003', '2026-02-06 10:00:00', 0.68, 'EXCESSIVE_UNITS', 'Enzyme infusion units exceed typical range', 4500.00, 0.72, '["Lab Results","Prior Authorization"]', 'INVESTIGATE', 'v2.4.1-demo', 'Claim line 2 shows 8 additional infusion hours (96366); typical max is 12 but patient weight-based dosing should require only 4-5 hours.'),
('RES-004', 'CLM-2026-0004', '2026-03-02 11:00:00', 0.45, NULL, NULL, 0.00, 0.82, NULL, 'MONITOR', 'v2.4.1-demo', 'Transplant claim within expected range. Single procedure code, single unit. No anomaly detected.'),
('RES-005', 'CLM-2026-0005', '2026-02-19 08:45:00', 0.78, 'EXCESSIVE_UNITS', 'Hemophilia factor units far exceed typical', 12000.00, 0.81, '["Clinical Notes"]', 'INVESTIGATE', 'v2.4.1-demo', '10 units of 96401 billed for Hemlibra SC injection; typical is 1-2 per administration. Possible unit of measurement confusion (mg vs vials).'),
('RES-006', 'CLM-2026-0006', '2026-03-04 09:30:00', 0.82, 'UNBUNDLING', 'Chemo IV and SC billed separately on same date', 15200.00, 0.85, '["Clinical Notes","Treatment Protocol"]', 'ESCALATE', 'v2.4.1-demo', 'Claim has 96413 (IV chemo) and 96401 (SC chemo) on same date. Per CCI rules these are mutually exclusive administration routes for same therapy session.'),
('RES-007', 'CLM-2026-0007', '2026-03-09 10:30:00', 0.55, NULL, NULL, 0.00, 0.70, NULL, 'MONITOR', 'v2.4.1-demo', 'Gene therapy claim pending. High dollar amount but single administration consistent with Zynteglo protocol. Monitoring for PA completion.'),
('RES-008', 'CLM-2026-0008', '2026-03-13 08:00:00', 0.91, 'DUPLICATE_BILLING', 'Same chemo infusion code billed twice', 6000.00, 0.93, '["Clinical Notes"]', 'ESCALATE', 'v2.4.1-demo', 'Procedure 96413 appears on lines 1 and 3 for same date of service. Line 3 references diagnosis pointer 2 but same drug. Likely duplicate entry.'),
('RES-009', 'CLM-2026-0009', '2026-03-21 09:00:00', 0.64, 'EXCESSIVE_UNITS', 'Additional infusion hours exceed typical', 3800.00, 0.69, '["Lab Results","Prior Authorization"]', 'INVESTIGATE', 'v2.4.1-demo', '9 additional hours (96366) exceeds expected 4-5 for standard Cerezyme infusion at 60 U/kg dosing.'),
('RES-010', 'CLM-2026-0010', '2026-03-29 10:00:00', 0.76, 'EXCESSIVE_UNITS', 'First-hour chemo units exceed typical range', 9500.00, 0.80, '["Clinical Notes"]', 'INVESTIGATE', 'v2.4.1-demo', '4 units of 96413 (first-hour chemo) is unusual; typically 1-2 per session. Combined with 6 additional hours suggests extended treatment beyond protocol.'),
('RES-011', 'CLM-2026-0011', '2026-04-05 08:30:00', 0.42, NULL, NULL, 0.00, 0.75, NULL, 'MONITOR', 'v2.4.1-demo', 'Hemophilia factor claim within expected range for Hemlibra maintenance. 8 units consistent with weight-based dosing.'),
('RES-012', 'CLM-2026-0012', '2026-04-13 09:15:00', 0.38, NULL, NULL, 0.00, 0.80, NULL, 'MONITOR', 'v2.4.1-demo', 'Standard oncology infusion. Units and amounts within normal bounds for pembrolizumab.'),
('RES-013', 'CLM-2026-0013', '2026-04-19 10:30:00', 0.88, 'DRUG_DIAG_MISMATCH', 'Second CAR-T for same diagnosis raises medical necessity concern', 25000.00, 0.86, '["Prior Authorization","Pathology Report","Clinical Notes"]', 'ESCALATE', 'v2.4.1-demo', 'Repeat Kymriah infusion for same DLBCL diagnosis within 14 months. Limited evidence supports re-treatment. Requires enhanced medical necessity review.'),
('RES-014', 'CLM-2026-0014', '2026-04-25 08:00:00', 0.35, NULL, NULL, 0.00, 0.78, NULL, 'MONITOR', 'v2.4.1-demo', 'Enzyme replacement within expected parameters. Standard biweekly Cerezyme infusion.'),
('RES-015', 'CLM-2026-0015', '2026-05-16 09:00:00', 0.52, NULL, NULL, 0.00, 0.72, NULL, 'MONITOR', 'v2.4.1-demo', 'Second transplant claim for same patient. Clinically plausible if graft failure. Pending documentation review.');

INSERT INTO CURATED.CLAIM_CASE VALUES
('CASE-001', 'CLM-2026-0001', 'RES-001', 'IN_REVIEW', 'MEDIUM', 'Dr. Lisa Monroe', '2026-01-22', '2026-02-22', NULL, 0.75, FALSE, 0),
('CASE-002', 'CLM-2026-0002', 'RES-002', 'CLOSED', 'HIGH', 'Dr. James Wright', '2026-01-27', '2026-02-27', '2026-02-15', 1.0, TRUE, 28500.00),
('CASE-003', 'CLM-2026-0005', 'RES-005', 'IN_REVIEW', 'HIGH', 'Dr. Lisa Monroe', '2026-02-20', '2026-03-20', NULL, 0.50, FALSE, 0),
('CASE-004', 'CLM-2026-0006', 'RES-006', 'OPEN', 'HIGH', NULL, '2026-03-05', '2026-04-05', NULL, 0.40, FALSE, 0),
('CASE-005', 'CLM-2026-0008', 'RES-008', 'CLOSED', 'HIGH', 'Dr. James Wright', '2026-03-14', '2026-04-14', '2026-03-28', 1.0, TRUE, 6000.00),
('CASE-006', 'CLM-2026-0013', 'RES-013', 'OPEN', 'HIGH', NULL, '2026-04-20', '2026-05-20', NULL, 0.67, FALSE, 0);

INSERT INTO CURATED.CLINICAL_REVIEW_OUTCOME VALUES
('REV-001', 'CASE-001', 'Dr. Lisa Monroe', '2026-02-10', 'Pending Additional Info', FALSE, FALSE, TRUE, 'Excessive units on line 2 may be justified by extended infusion time for adverse reaction management. Awaiting treatment protocol documentation.'),
('REV-002', 'CASE-002', 'Dr. James Wright', '2026-02-15', 'Upheld', TRUE, TRUE, FALSE, 'Fee schedule variance confirmed. Facility markup of 434% above CMS rate not justified. Drug acquisition cost documentation incomplete. Overpayment of $28,500 confirmed.'),
('REV-003', 'CASE-003', 'Dr. Lisa Monroe', '2026-03-10', 'Pending Additional Info', TRUE, FALSE, FALSE, 'Units appear excessive for standard Hemlibra dosing. Requesting weight-based calculation documentation from provider.'),
('REV-004', 'CASE-005', 'Dr. James Wright', '2026-03-28', 'Upheld', TRUE, TRUE, FALSE, 'Duplicate billing confirmed. Line 3 (96413) is exact duplicate of line 1 with different diagnosis pointer. Provider acknowledged billing error. $6,000 overpayment confirmed.');

INSERT INTO CURATED.RECOVERY_ACTION VALUES
('REC-001', 'CASE-002', 'Recoupment', 28500.00, 28500.00, 'RESOLVED', '2026-02-16', '2026-03-20', 'Provider agreed to full recoupment. Applied to next payment cycle.'),
('REC-002', 'CASE-005', 'Offset', 6000.00, 0.00, 'IN_PROGRESS', '2026-03-29', NULL, 'Offset applied to provider account. Awaiting next remittance cycle for confirmation.');

INSERT INTO CURATED.MODEL_FEEDBACK VALUES
('FB-001', 'RES-002', 'Dr. James Wright', 'TRUE_POSITIVE', '2026-02-15', TRUE, FALSE, NULL, 'Model correctly identified fee schedule variance. Overpayment confirmed at clinical review.'),
('FB-002', 'RES-008', 'Dr. James Wright', 'TRUE_POSITIVE', '2026-03-28', TRUE, FALSE, NULL, 'Duplicate billing correctly detected. Provider confirmed billing error.'),
('FB-003', 'RES-001', 'Dr. Lisa Monroe', 'INDETERMINATE', '2026-02-10', NULL, NULL, NULL, 'Excessive units flagged but clinical justification may exist. Awaiting additional documentation.'),
('FB-004', 'RES-005', 'Dr. Lisa Monroe', 'INDETERMINATE', '2026-03-10', NULL, NULL, 'POSSIBLE_UNIT_CONFUSION', 'May be unit-of-measurement issue rather than true overpayment. Provider uses different unit convention.'),
('FB-005', 'RES-006', 'System Auto', 'TRUE_POSITIVE', '2026-03-06', TRUE, FALSE, NULL, 'CCI bundling rule violation auto-confirmed. 96413 and 96401 are mutually exclusive per Column 2.');


-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================
-- Run these after the inserts to confirm everything is working:

-- SELECT 'CLAIM_HEADER' AS TBL, COUNT(*) AS ROWS FROM RAW.CLAIM_HEADER
-- UNION ALL SELECT 'CLAIM_LINE', COUNT(*) FROM RAW.CLAIM_LINE
-- UNION ALL SELECT 'CLAIM_DOCUMENT', COUNT(*) FROM RAW.CLAIM_DOCUMENT
-- UNION ALL SELECT 'EHR_SUMMARY', COUNT(*) FROM RAW.EHR_SUMMARY
-- UNION ALL SELECT 'CLAIM_ANOMALY_RESULT', COUNT(*) FROM CURATED.CLAIM_ANOMALY_RESULT
-- UNION ALL SELECT 'CLAIM_CASE', COUNT(*) FROM CURATED.CLAIM_CASE
-- UNION ALL SELECT 'VW_SUSPECTED_OVERPAYMENT (view)', COUNT(*) FROM ANALYTICS.VW_SUSPECTED_OVERPAYMENT_CASES
-- UNION ALL SELECT 'VW_HIGH_COST_THERAPY (view)', COUNT(*) FROM ANALYTICS.VW_HIGH_COST_THERAPY_CLAIMS;

-- SELECT * FROM ANALYTICS.VW_SUSPECTED_OVERPAYMENT_CASES LIMIT 5;
-- SELECT * FROM ANALYTICS.VW_PROVIDER_OUTLIER_SUMMARY;
-- SELECT * FROM ANALYTICS.VW_DOCUMENT_COMPLETENESS LIMIT 5;
-- SELECT * FROM ANALYTICS.VW_MODEL_FEEDBACK_SUMMARY;
