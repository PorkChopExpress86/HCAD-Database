-- HCAD Database Schema - Sample Queries
-- Based on hcad_data_schema.md structure
-- These queries demonstrate common use cases for the HCAD property database

-- =============================================
-- 1. PROPERTY SEARCH AND BASIC INFORMATION
-- =============================================

-- Get basic property information for a specific account
SELECT 
    ra.acct,
    ra.mailto AS owner_name,
    ra.site_addr_1 || ' ' || COALESCE(ra.site_addr_2, '') AS site_address,
    ra.state_class,
    ra.tot_mkt_val AS market_value,
    ra.tot_appr_val AS appraised_value,
    ra.land_val,
    ra.bld_val AS building_value,
    ra.school_dist,
    ra.Neighborhood_Code
FROM real_acct ra
WHERE ra.acct = '1234567890123';

-- =============================================
-- FEATURE VALIDATION: Sanity checks and anomalies
-- =============================================

-- Helper: Safely convert text-like numeric fields to numeric
CREATE OR REPLACE FUNCTION safe_num(v text) RETURNS numeric AS $$
    SELECT CASE
        WHEN v IS NULL OR TRIM(v) = '' THEN NULL
        ELSE NULLIF(REGEXP_REPLACE(v, '[^0-9.]', '', 'g'), '')::numeric
    END;
$$ LANGUAGE SQL IMMUTABLE;

-- 1) Properties with missing numeric market value after sanitization
SELECT
        ra.acct,
        ra.site_addr_1,
        ra.tot_mkt_val,
        pf.tot_mkt_val_num
FROM real_acct ra
LEFT JOIN property_features pf ON ra.acct = pf.acct
WHERE ra.tot_mkt_val IS NOT NULL
    AND ra.tot_mkt_val <> ''
    AND pf.tot_mkt_val_num IS NULL
LIMIT 50;

-- 2) Properties with suspicious bedroom counts (>10)
SELECT acct, site_addr_1, bedrooms FROM property_features WHERE bedrooms::int > 10 ORDER BY bedrooms DESC LIMIT 50;

-- 3) Properties with heated area = 0 but building area > 0
SELECT pf.acct, pf.site_addr_1, pf.heated_area_sqft, ra.bld_ar
FROM property_features pf
JOIN real_acct ra ON pf.acct = ra.acct
WHERE COALESCE(pf.heated_area_sqft, 0) = 0
    AND COALESCE(safe_num(ra.bld_ar), 0) > 0
LIMIT 50;

-- 4) Simple numeric consistency check: market value vs sum of jur appraised values
SELECT
        pf.acct,
        pf.site_addr_1,
        pf.tot_mkt_val_num,
        pf.jur_appraised_val_sum,
        pf.tot_mkt_val_num - pf.jur_appraised_val_sum AS diff
FROM property_features pf
WHERE ABS(COALESCE(pf.tot_mkt_val_num, 0) - COALESCE(pf.jur_appraised_val_sum, 0)) > 1000000
ORDER BY diff DESC
LIMIT 20;

-- =============================================
-- PROPERTY FEATURES (VALIDATED) - property_features_v2
-- This view includes corrected/capped bedroom/bath values and anomaly flags
-- =============================================
CREATE OR REPLACE VIEW property_features_v2 AS
SELECT
    pf.*, -- reuse columns from property_features
    -- Normalize bedrooms and mark anomalies
    pf.bedrooms::numeric AS bedrooms_raw,
    CASE WHEN pf.bedrooms::numeric BETWEEN 1 AND 8 THEN pf.bedrooms::int ELSE NULL END AS bedrooms_valid,
    (pf.bedrooms::numeric < 1 OR pf.bedrooms::numeric > 8) AS bedrooms_anomaly,
    -- Suspect bedrooms if extreme counts or 0 but very large heated area
    (pf.bedrooms::numeric > 12 OR pf.bedrooms::numeric < 0 OR (pf.bedrooms::numeric = 0 AND COALESCE(pf.heated_area_sqft,0) > 5000)) AS bedrooms_suspect,
    -- Capped version useful for some analysis (min of bedrooms and 8)
    CASE WHEN pf.bedrooms::numeric > 0 THEN LEAST(pf.bedrooms::numeric::int, 8) ELSE NULL END AS bedrooms_capped,
    -- Normalize full baths and half baths and anomalies
    pf.full_baths::numeric AS full_baths_raw,
    CASE WHEN pf.full_baths::numeric BETWEEN 0 AND 6 THEN pf.full_baths::int ELSE NULL END AS full_baths_valid,
    (pf.full_baths::numeric < 0 OR pf.full_baths::numeric > 6) AS full_baths_anomaly,
    pf.half_baths::numeric AS half_baths_raw,
    CASE WHEN pf.half_baths::numeric BETWEEN 0 AND 4 THEN pf.half_baths::int ELSE NULL END AS half_baths_valid,
    (pf.half_baths::numeric < 0 OR pf.half_baths::numeric > 4) AS half_baths_anomaly,
    -- Flag when heated area is 0 but building area exists
    (COALESCE(pf.heated_area_sqft, 0) = 0 AND COALESCE(pf.heated_area_sqft, 0) < COALESCE(safe_num(ra.bld_ar), 0) AND COALESCE(safe_num(ra.bld_ar), 0) > 0) AS heated_area_anomaly,
    -- Large discrepancy between tot_mkt_val and summed jur appraised values
    ABS(COALESCE(pf.tot_mkt_val_num, 0) - COALESCE(pf.jur_appraised_val_sum, 0)) > 1000000 AS large_value_anomaly
FROM property_features pf
LEFT JOIN real_acct ra ON pf.acct = ra.acct;

-- Quick-probe: inspect anomalies for Wall St
SELECT * FROM property_features_v2 WHERE zip = '77040' AND (site_addr_1 ILIKE '%WALL ST%' OR UPPER(street_name) = 'WALL') AND (bedrooms_anomaly OR full_baths_anomaly OR half_baths_anomaly OR heated_area_anomaly OR large_value_anomaly) ORDER BY site_addr_1 LIMIT 100;



-- Search properties by address
SELECT 
    acct,
    mailto AS owner,
    site_addr_1,
    site_addr_2,
    site_addr_3,
    tot_mkt_val
FROM real_acct
WHERE site_addr_1 ILIKE '%MAIN ST%'
ORDER BY site_addr_1;

-- =============================================
-- 2. COMPARABLE PROPERTIES (COMPS) ANALYSIS
-- =============================================

-- Find comparable residential properties in same neighborhood
-- Similar square footage, bedrooms, bathrooms, and year built
SELECT 
    ra.acct,
    ra.site_addr_1,
    ra.neighborhood_code,
    br.yr_blt AS year_built,
    br.heat_ar AS living_sqft,
    fx_bed.fixture_units AS bedrooms,
    fx_bath.fixture_units AS bathrooms,
    safe_num(ra.land_ar) AS lot_sqft,
    ra.tot_mkt_val AS market_value,
    ra.tot_appr_val AS appraised_value
FROM real_acct ra
LEFT JOIN building_res br ON ra.acct = br.acct AND br.bld_num = '1'
LEFT JOIN fixtures fx_bed ON ra.acct = fx_bed.acct AND fx_bed.bld_num = '1' AND fx_bed.type = 'BED'
LEFT JOIN fixtures fx_bath ON ra.acct = fx_bath.acct AND fx_bath.bld_num = '1' AND fx_bath.type = 'BTH'
LEFT JOIN land ln ON ra.acct = ln.acct AND ln.num = '1'
WHERE ra.Neighborhood_Code = '1234.50'
  AND br.heat_ar BETWEEN 1800 AND 2200
  AND br.yr_blt BETWEEN 2000 AND 2010
    AND fx_bed.units BETWEEN 3 AND 4
ORDER BY ABS(br.heat_ar - 2000), ra.tot_mkt_val;

-- =============================================
-- 3. PROPERTY DETAILS - COMPREHENSIVE VIEW
-- =============================================

-- Get full property detail with buildings, land, and improvements
SELECT 
    ra.acct,
    ra.mailto AS owner,
    ra.site_addr_1,
    -- Building details
    br.bld_num,
    br.yr_blt,
    br.yr_remodel,
    br.bld_ar AS building_area,
    br.heat_ar AS heated_area,
    bt.Description AS building_type,
    -- bs (building style) removed because building_res does not store a style code; use br.structure_dscr instead if needed
    bq.Description AS quality,
    -- Fixtures/features
    STRING_AGG(DISTINCT fx.type || ': ' || fx.units, ', ') AS fixtures,
    -- Land
    l.land_ar AS land_area,
    l.units AS land_units,
    lu.description AS land_use,
    -- Values
    ra.land_val,
    ra.bld_val,
    ra.tot_mkt_val
FROM real_acct ra
LEFT JOIN building_res br ON ra.acct = br.acct AND br.bld_num = '1'
LEFT JOIN desc_r_02_building_type_code bt ON br.structure = bt."Type"
-- skipped desc_r_03_building_style join (building_res does not contain style code column)
LEFT JOIN desc_r_07_quality_code bq ON br.qa_cd = bq."Code"
LEFT JOIN fixtures fx ON ra.acct = fx.acct AND fx.bld_num = '1'
LEFT JOIN land l ON ra.acct = l.acct AND l.num = '1'
LEFT JOIN desc_r_15_land_usecode lu ON l.land_use_cd = lu.land_use_cd
WHERE ra.acct = '1234567890123'
GROUP BY ra.acct, ra.mailto, ra.site_addr_1, br.bld_num, br.yr_blt, br.yr_remodel, 
         br.bld_ar, br.heat_ar, bt."Description", bq."Description",
         l.land_ar, l.units, lu.description, ra.land_val, ra.bld_val, ra.tot_mkt_val;

-- =============================================
-- 4. OWNERSHIP AND DEED HISTORY
-- =============================================

-- Get ownership history for a property
SELECT 
    oh.acct,
    oh.name AS owner_name,
    oh.purchase_date AS deed_date,
    oh.site_address
FROM ownership_history oh
WHERE oh.acct = '1234567890123'
ORDER BY oh.purchase_date DESC;

-- Get current owners with ownership percentages
SELECT 
    o.acct,
    ra.site_addr_1,
    o.name AS owner_name,
    o.pct_own AS ownership_percent,
    o.aka AS owner_type
FROM owners o
JOIN real_acct ra ON o.acct = ra.acct
WHERE o.acct = '1234567890123'
ORDER BY o.ln_num;

-- =============================================
-- 5. EXEMPTIONS AND TAX JURISDICTIONS
-- =============================================

-- Get all exemptions for a property by jurisdiction
SELECT 
    je.acct,
    ra.mailto AS owner,
    ra.site_addr_1,
    jd.Description AS jurisdiction,
    je.exempt_cd,
    jed.description AS exemption_description,
    je.exempt_val AS exemption_value
FROM jur_exempt je
JOIN real_acct ra ON je.acct = ra.acct
LEFT JOIN desc_r_12_real_jurisdictions jd ON je.tax_district = jd."Code"
LEFT JOIN jur_exemption_dscr jed ON je.tax_district = jed.tax_district AND je.exempt_cat = jed.exempt_cat
WHERE je.acct = '1234567890123'
ORDER BY jd.Description, je.exempt_cd;

-- Get property values by taxing jurisdiction
SELECT 
    jv.acct,
    ra.mailto AS owner,
    jd.Description AS jurisdiction,
    jv.appraised_val,
    jv.assessed_val,
    jv.taxable_val,
    jv.tax_rate
FROM jur_value jv
JOIN real_acct ra ON jv.acct = ra.acct
LEFT JOIN desc_r_12_real_jurisdictions jd ON jv.tax_district = jd."Code"
WHERE jv.acct = '1234567890123'
ORDER BY jd.Description;

-- =============================================
-- 6. NEIGHBORHOOD AND MARKET ANALYSIS
-- =============================================

-- Get neighborhood statistics (median values, avg sqft, etc.)
SELECT 
    ra."Neighborhood_Code",
    nc."Description" AS neighborhood_name,
    COUNT(*) AS property_count,
    ROUND(AVG(ra.tot_mkt_val), 0) AS avg_market_value,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ra.tot_mkt_val) AS median_market_value,
    ROUND(AVG(br.heat_ar), 0) AS avg_living_sqft,
    ROUND(AVG(ra.land_ar), 0) AS avg_lot_sqft,
    
    MIN(br.yr_blt) AS oldest_year_built,
    MAX(br.yr_blt) AS newest_year_built
FROM real_acct ra
LEFT JOIN building_res br ON ra.acct = br.acct AND br.bld_num = '1'
LEFT JOIN real_neighborhood_code nc ON ra.Neighborhood_Code = nc.cd
WHERE ra.Neighborhood_Code LIKE '1234%'
  AND ra.state_class = 'A1'  -- Single-family residential
GROUP BY ra."Neighborhood_Code", nc."Description"
ORDER BY ra."Neighborhood_Code";

-- Market area property counts and values
SELECT 
    ma."MktArea" AS market_area_cd,
    ma."Description" AS market_area,
    COUNT(DISTINCT ra.acct) AS property_count,
    ROUND(AVG(ra.tot_mkt_val), 0) AS avg_value,
    SUM(ra.tot_mkt_val) AS total_value
FROM real_acct ra
JOIN desc_r_21_market_area ma ON ra."Market_Area_1" = ma."MktArea"
GROUP BY ma."MktArea", ma."Description"
ORDER BY property_count DESC
LIMIT 20;

-- =============================================
-- 7. SALES AND DEED ANALYSIS
-- =============================================

-- Recent sales in a neighborhood
SELECT 
    d.acct,
    ra.site_addr_1,
    d.dos AS sale_date,
    d.deed_id,
    d.clerk_yr,
    d.clerk_id,
    ra.tot_mkt_val AS current_market_value,
    br.heat_ar AS living_sqft
FROM deeds d
JOIN real_acct ra ON d.acct = ra.acct
LEFT JOIN building_res br ON d.acct = br.acct AND br.bld_num = '1'
WHERE ra.Neighborhood_Code = '1234.50'
    AND to_date(NULLIF(d.dos, ''), 'MM/DD/YYYY') >= CURRENT_DATE - INTERVAL '1 year'
  AND d.sale_price > 0
ORDER BY to_date(NULLIF(d.dos, ''), 'MM/DD/YYYY') DESC;

-- =============================================
-- 8. PROTEST AND HEARING ANALYSIS
-- =============================================

-- Properties with ARB protests
SELECT 
    ap.acct,
    ra.mailto AS owner,
    ra.site_addr_1,
    ap.protested_by,
    ap.protested_dt AS protest_date
FROM arb_protest_real ap
JOIN real_acct ra ON ap.acct = ra.acct
WHERE EXTRACT(YEAR FROM to_date(NULLIF(ap.protested_dt, ''), 'MM/DD/YYYY')) = 2025
ORDER BY ap.protested_dt DESC;

-- ARB hearing results
SELECT 
    ah.acct,
    ra.mailto AS owner,
    ah."Tax_Year" AS tax_year,
    ah."Actual_Hearing_Date" AS actual_hearing_date,
    ah."Initial_Appraised_Value" AS initial_appraised_value,
    ah."Final_Appraised_Value" AS final_appraised_value,
    ah."Initial_Appraised_Value" - ah."Final_Appraised_Value" AS value_reduction,
    cc.Description AS conclusion
FROM arb_hearings_real ah
JOIN real_acct ra ON ah.acct = ra.acct
LEFT JOIN desc_r_25_conclusion_code cc ON ah."Letter_Type" = cc."Code"
WHERE ah."Tax_Year" = '2025'
  AND ah.final_value IS NOT NULL
ORDER BY ah.actual_hearing_date DESC;

-- =============================================
-- 9. PROPERTY IMPROVEMENTS AND PERMITS
-- =============================================

-- Recent permits for properties
SELECT 
    p.acct,
    ra.site_addr_1,
    p.id AS permit_id,
    p.permit_type,
    pc.description AS permit_description,
    p.issue_date AS issued_date,
    p.final_dt AS final_date,
    p.valuation AS permit_value,
    ps.Description AS status
FROM permits p
JOIN real_acct ra ON p.acct = ra.acct
LEFT JOIN desc_r_19_permit_code pc ON p.permit_type = pc."Code"
LEFT JOIN desc_r_18_permit_status ps ON p.status = ps.permit_status_cd
WHERE to_date(NULLIF(p.issue_date, ''), 'MM/DD/YYYY') >= CURRENT_DATE - INTERVAL '2 years'
ORDER BY to_date(NULLIF(p.issue_date, ''), 'MM/DD/YYYY') DESC
LIMIT 100;

-- =============================================
-- 10. AGGREGATE REPORTS
-- =============================================

-- Total property values by school district
SELECT 
    sd."Code" AS school_dist_cd,
    sd.Description AS school_district,
    COUNT(ra.acct) AS property_count,
    SUM(ra.tot_mkt_val) AS total_market_value,
    SUM(ra.tot_appr_val) AS total_appraised_value,
    ROUND(AVG(ra.tot_mkt_val), 0) AS avg_market_value
FROM real_acct ra
JOIN desc_r_20_school_district sd ON ra.school_dist = sd."Code"
WHERE ra.state_class IN ('A1', 'A2', 'A3')  -- Residential
GROUP BY sd.Code, sd.Description
ORDER BY total_market_value DESC;

-- Property state class distribution
SELECT 
    sc."Code" AS state_class,
    sc."Description" AS property_type,
    COUNT(ra.acct) AS property_count,
    SUM(ra.tot_mkt_val) AS total_value,
    ROUND(AVG(ra.tot_mkt_val), 0) AS avg_value
FROM real_acct ra
JOIN desc_r_01_state_class sc ON ra.state_class = sc."Code"
GROUP BY sc."Code", sc."Description"
ORDER BY property_count DESC;

-- =============================================
-- WALL ST (ZIP 77040) - TARGETED QUERIES
-- =============================================

-- 1) Basic list of properties on Wall St in ZIP 77040
SELECT
        ra.acct,
        ra.str_num,
        ra.str || COALESCE(' ' || ra.str_sfx, '') AS street_full,
        ra.str_unit,
        ra.site_addr_1,
        ra.site_addr_2,
        ra.site_addr_3 AS zip,
        ra.mailto AS owner,
        ra.tot_mkt_val
FROM real_acct ra
WHERE ra.site_addr_3 = '77040'
    AND (
            ra.site_addr_1 ILIKE '%WALL ST%'
            OR UPPER(ra.str) = 'WALL'
            OR UPPER(ra.str) ILIKE '%WALL%'
    )
ORDER BY ra.str_num, ra.str_sfx, ra.str;

-- 2) More precise match using street name + suffix (ST/Street)
SELECT
        ra.acct,
        ra.str_num,
        ra.str,
        ra.str_sfx,
        ra.site_addr_1,
        ra.site_addr_2,
        ra.site_addr_3,
        ra.mailto AS owner,
        ra.tot_mkt_val
FROM real_acct ra
WHERE ra.site_addr_3 = '77040'
    AND UPPER(ra.str) = 'WALL'
    AND UPPER(COALESCE(ra.str_sfx, '')) IN ('ST', 'ST.', 'STREET')
ORDER BY ra.str_num;

-- 3) Owners for properties on Wall St (ZIP 77040)
SELECT
        ra.acct,
        ra.site_addr_1,
    o.name AS owner_name,
    o.pct_own::text AS ownership_percent
FROM real_acct ra
JOIN owners o ON ra.acct = o.acct
WHERE ra.site_addr_3 = '77040'
    AND (
            ra.site_addr_1 ILIKE '%WALL ST%'
            OR UPPER(ra.str) = 'WALL'
    )
ORDER BY ra.site_addr_1, o.ln_num;

-- 4) Aggregate summary for Wall St in ZIP 77040 (count, total market value)
SELECT
        COUNT(DISTINCT ra.acct) AS property_count,
        SUM(safe_num(ra.tot_mkt_val)) AS total_market_value,
        AVG(safe_num(ra.tot_mkt_val)) AS avg_market_value
FROM real_acct ra
WHERE ra.site_addr_3 = '77040'
    AND (
            ra.site_addr_1 ILIKE '%WALL ST%'
            OR UPPER(ra.str) = 'WALL'
    );

-- 5) Recent deed records for Wall St properties in ZIP 77040 (deed id + sale date)
SELECT
        d.acct,
        ra.site_addr_1,
        d.dos AS sale_date,
        d.deed_id,
        d.clerk_yr,
        d.clerk_id
FROM deeds d
JOIN real_acct ra ON d.acct = ra.acct
WHERE ra.site_addr_3 = '77040'
    AND (
            ra.site_addr_1 ILIKE '%WALL ST%'
            OR UPPER(ra.str) = 'WALL'
    )
ORDER BY COALESCE(NULLIF(d.dos, ''), '01/01/1900')::date DESC
LIMIT 100;

-- =============================================
-- PROPERTY FEATURES VIEW - normalize and aggregate features for analysis
-- =============================================
-- Create a view that aggregates relevant features per property (acct)
-- NOTE: This uses text->numeric casting with REGEXP_REPLACE sanitization.
CREATE OR REPLACE VIEW property_features AS
SELECT
    ra.acct,
    ra.yr AS tax_year,
    ra.site_addr_1,
    ra.site_addr_2,
    ra.site_addr_3 AS zip,
    ra.str_num,
    ra.str AS street_name,
    ra.str_sfx,
    ra.str_unit,
    -- Owner(s) as a single string
    COALESCE(STRING_AGG(DISTINCT o.name, '; '), '') AS owners,
    -- Values and numeric casts
    safe_num(ra.tot_mkt_val) AS tot_mkt_val_num,
    safe_num(ra.tot_appr_val) AS tot_appr_val_num,
    safe_num(ra.land_val) AS land_val_num,
    -- Lot area and building area
    safe_num(ra.land_ar) AS lot_sqft,
    -- Building heated area (prefers res table then main acct column)
    COALESCE(
        safe_num(br.heat_ar),
        safe_num(br.im_sq_ft),
        safe_num(ra.bld_ar)
    ) AS heated_area_sqft,
    -- Building attributes
    br.date_erected AS bld_date_erected,
    br.yr_remodel AS bld_year_remodel,
    br.structure_dscr AS building_type,
    br.dscr AS building_description,
    br.qa_cd AS building_quality,
    -- Bedrooms, full baths, half baths (aggregated from fixtures)
    COALESCE((
        SELECT SUM(COALESCE(safe_num(f.units), 0))
        FROM fixtures f
        WHERE f.acct = ra.acct AND (f.type_dscr ILIKE '%Bedroom%' OR f.type ILIKE 'RMB')
    ), 0) AS bedrooms,
    COALESCE((
        SELECT SUM(COALESCE(safe_num(f.units), 0))
        FROM fixtures f
        WHERE f.acct = ra.acct AND (f.type_dscr ILIKE '%Full Bath%' OR f.type ILIKE 'RMF')
    ), 0) AS full_baths,
    COALESCE((
        SELECT SUM(COALESCE(safe_num(f.units), 0))
        FROM fixtures f
        WHERE f.acct = ra.acct AND (f.type_dscr ILIKE '%Half Bath%' OR f.type ILIKE 'RMH')
    ), 0) AS half_baths,
    -- Feature counts and presence
    COALESCE((SELECT COUNT(*) FROM extra_features ef WHERE ef.acct = ra.acct), 0) AS extra_feature_count,
    COALESCE((
        SELECT BOOL_OR(
            ef.dscr ILIKE '%pool%' OR ef.l_dscr ILIKE '%pool%' OR ef.s_dscr ILIKE '%pool%'
        )
        FROM extra_features ef
        WHERE ef.acct = ra.acct
    ), FALSE) AS has_pool,
    -- Permit counts in last 5 years
    COALESCE((
        SELECT COUNT(*) FROM permits p
        WHERE p.acct = ra.acct
          AND p.issue_date IS NOT NULL
          AND p.issue_date <> ''
          AND to_date(p.issue_date, 'MM/DD/YYYY') >= (CURRENT_DATE - INTERVAL '5 years')
    ), 0) AS permits_last_5yr,
    -- Sales in last 5 years
    COALESCE((
        SELECT COUNT(*) FROM deeds d
        WHERE d.acct = ra.acct
          AND d.dos IS NOT NULL
          AND d.dos <> ''
          AND to_date(d.dos, 'MM/DD/YYYY') >= (CURRENT_DATE - INTERVAL '5 years')
    ), 0) AS sales_last_5yr,
    -- Jurisdiction tax aggregate (sum appraised val across jurisdictions)
    COALESCE((
        SELECT SUM(COALESCE(safe_num(jv.appraised_val), 0))
        FROM jur_value jv
        WHERE jv.acct = ra.acct
    ), 0) AS jur_appraised_val_sum
FROM real_acct ra
LEFT JOIN building_res br ON ra.acct = br.acct AND br.bld_num = '1'
LEFT JOIN owners o ON ra.acct = o.acct
GROUP BY ra.acct, ra.yr, ra.site_addr_1, ra.site_addr_2, ra.site_addr_3, ra.str_num, ra.str, ra.str_sfx, ra.str_unit,
         ra.tot_mkt_val, ra.tot_appr_val, ra.land_val, ra.land_ar, br.heat_ar, br.im_sq_ft, ra.bld_ar,
         br.date_erected, br.yr_remodel, br.structure_dscr, br.dscr, br.qa_cd;

-- =============================================
-- TREND & FEATURE ANALYSIS QUERIES
-- =============================================

-- 1) Sample property_features for Wall St in 77040
SELECT *
FROM property_features pf
WHERE pf.zip = '77040'
  AND (pf.site_addr_1 ILIKE '%WALL ST%' OR UPPER(pf.street_name) = 'WALL')
ORDER BY pf.str_num
LIMIT 50;

-- 2) Aggregated median and average market values by bedrooms for Wall St (zip 77040)
SELECT
    pf.bedrooms::int AS bedrooms,
    COUNT(*) AS properties,
    ROUND(AVG(pf.tot_mkt_val_num), 0) AS avg_market_value,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY pf.tot_mkt_val_num) AS median_market_value
FROM property_features pf
WHERE pf.zip = '77040'
  AND (pf.site_addr_1 ILIKE '%WALL ST%' OR UPPER(pf.street_name) = 'WALL')
GROUP BY pf.bedrooms
ORDER BY pf.bedrooms;

-- 3) Compare average market value by building quality on Wall St
SELECT
    pf.building_quality,
    COUNT(*) AS properties,
    ROUND(AVG(pf.tot_mkt_val_num), 0) AS avg_market_value
FROM property_features pf
WHERE pf.zip = '77040'
  AND (pf.site_addr_1 ILIKE '%WALL ST%' OR UPPER(pf.street_name) = 'WALL')
GROUP BY pf.building_quality
ORDER BY avg_market_value DESC;

-- 4) Market value vs pool presence
SELECT
    pf.has_pool,
    COUNT(*) AS properties,
    ROUND(AVG(pf.tot_mkt_val_num), 0) AS avg_market_value
FROM property_features pf
WHERE pf.zip = '77040'
  AND (pf.site_addr_1 ILIKE '%WALL ST%' OR UPPER(pf.street_name) = 'WALL')
GROUP BY pf.has_pool
ORDER BY pf.has_pool DESC;

-- =============================================
-- QA CHECKS: quick validation queries for the views and expected values
-- 1) Wall St property count sanity check (should be 97 for ZIP 77040)
SELECT COUNT(DISTINCT acct) AS wall_st_property_count
FROM property_features
WHERE zip = '77040' AND (site_addr_1 ILIKE '%WALL ST%' OR UPPER(street_name) = 'WALL');

-- 2) Verify property_features_v2 has added fields (bedrooms_capped, bedrooms_suspect)
SELECT acct, site_addr_1, bedrooms, bedrooms_capped, bedrooms_suspect
FROM property_features_v2
WHERE zip = '77040' AND (site_addr_1 ILIKE '%WALL ST%' OR UPPER(street_name) = 'WALL')
ORDER BY acct
LIMIT 20;

-- 3) Anomaly summary for all properties
SELECT
    SUM(CASE WHEN bedrooms_anomaly THEN 1 ELSE 0 END) AS bedrooms_anomaly_count,
    SUM(CASE WHEN full_baths_anomaly THEN 1 ELSE 0 END) AS full_baths_anomaly_count,
    SUM(CASE WHEN half_baths_anomaly THEN 1 ELSE 0 END) AS half_baths_anomaly_count,
    SUM(CASE WHEN heated_area_anomaly THEN 1 ELSE 0 END) AS heated_area_anomaly_count
FROM property_features_v2;

-- =============================================
-- COMPREHENSIVE RESIDENTIAL PROPERTY VIEW FOR PROTESTS
-- Includes all information needed for protesting assessed values
-- Covers all residential state classes: A1-A4 (single-family, mobile, aux, duplex), B1-B4 (multi-family)
-- Includes properties with multiple buildings
-- =============================================

CREATE OR REPLACE VIEW residential_protest_analysis AS
WITH 
-- Building summary (handles multiple buildings per property)
building_summary AS (
    SELECT 
        br.acct,
        COUNT(DISTINCT br.bld_num) AS building_count,
        -- Primary building (bld_num = '1')
        MAX(CASE WHEN br.bld_num = '1' THEN br.date_erected END) AS primary_year_built,
        MAX(CASE WHEN br.bld_num = '1' THEN br.yr_remodel END) AS primary_year_remodel,
        MAX(CASE WHEN br.bld_num = '1' THEN br.structure_dscr END) AS primary_structure_type,
        MAX(CASE WHEN br.bld_num = '1' THEN br.qa_cd END) AS primary_quality_code,
        MAX(CASE WHEN br.bld_num = '1' THEN br.dscr END) AS primary_quality_desc,
        MAX(CASE WHEN br.bld_num = '1' THEN safe_num(br.heat_ar) END) AS primary_heated_sqft,
        MAX(CASE WHEN br.bld_num = '1' THEN safe_num(br.gross_ar) END) AS primary_gross_sqft,
        MAX(CASE WHEN br.bld_num = '1' THEN safe_num(br.eff_ar) END) AS primary_effective_sqft,
        MAX(CASE WHEN br.bld_num = '1' THEN safe_num(br.cama_replacement_cost) END) AS primary_replacement_cost,
        MAX(CASE WHEN br.bld_num = '1' THEN safe_num(br.accrued_depr_pct) END) AS primary_depreciation_pct,
        -- Total across all buildings
        SUM(safe_num(br.heat_ar)) AS total_heated_sqft,
        SUM(safe_num(br.gross_ar)) AS total_gross_sqft,
        SUM(safe_num(br.cama_replacement_cost)) AS total_replacement_cost,
        -- Additional buildings info
        STRING_AGG(
            CASE WHEN br.bld_num <> '1' THEN 
                'Bldg ' || br.bld_num || ': ' || COALESCE(br.structure_dscr, 'Unknown') || 
                ' (' || COALESCE(br.heat_ar, '0') || ' sqft)'
            END, 
            '; '
        ) AS additional_buildings
    FROM building_res br
    GROUP BY br.acct
),
-- Latest protest/hearing history
protest_history AS (
    SELECT 
        ap.acct,
        COUNT(DISTINCT ap.protested_dt) AS total_protests,
        MAX(ap.protested_dt) AS last_protest_date,
        STRING_AGG(DISTINCT ap.protested_by, ', ') AS protest_agents
    FROM arb_protest_real ap
    WHERE ap.protested_dt IS NOT NULL AND ap.protested_dt <> ''
    GROUP BY ap.acct
),
-- Hearing outcomes (last 5 years)
hearing_history AS (
    SELECT 
        ah.acct,
        COUNT(*) AS hearing_count,
        MAX(ah."Tax_Year") AS last_hearing_year,
        MAX(ah."Actual_Hearing_Date") AS last_hearing_date,
        -- Most recent hearing outcome
        MAX(CASE WHEN ah."Tax_Year" = (SELECT MAX(ah2."Tax_Year") FROM arb_hearings_real ah2 WHERE ah2.acct = ah.acct)
            THEN safe_num(ah."Initial_Appraised_Value") END) AS last_initial_appraised,
        MAX(CASE WHEN ah."Tax_Year" = (SELECT MAX(ah2."Tax_Year") FROM arb_hearings_real ah2 WHERE ah2.acct = ah.acct)
            THEN safe_num(ah."Final_Appraised_Value") END) AS last_final_appraised,
        -- Average reduction from hearings
        AVG(safe_num(ah."Initial_Appraised_Value") - safe_num(ah."Final_Appraised_Value")) AS avg_value_reduction,
        SUM(CASE WHEN safe_num(ah."Final_Appraised_Value") < safe_num(ah."Initial_Appraised_Value") THEN 1 ELSE 0 END) AS successful_protests
    FROM arb_hearings_real ah
    WHERE ah."Tax_Year" IS NOT NULL 
        AND CAST(ah."Tax_Year" AS INTEGER) >= EXTRACT(YEAR FROM CURRENT_DATE) - 5
    GROUP BY ah.acct
),
-- Recent sales (last 5 years)
recent_sales AS (
    SELECT 
        d.acct,
        COUNT(*) AS sale_count,
        MAX(to_date(NULLIF(d.dos, ''), 'MM/DD/YYYY')) AS last_sale_date,
        MAX(CASE WHEN to_date(NULLIF(d.dos, ''), 'MM/DD/YYYY') = 
            (SELECT MAX(to_date(NULLIF(d2.dos, ''), 'MM/DD/YYYY')) FROM deeds d2 WHERE d2.acct = d.acct)
            THEN safe_num(d.sale_price) END) AS last_sale_price
    FROM deeds d
    WHERE d.dos IS NOT NULL 
        AND d.dos <> ''
        AND to_date(NULLIF(d.dos, ''), 'MM/DD/YYYY') >= CURRENT_DATE - INTERVAL '5 years'
    GROUP BY d.acct
),
-- Exemptions summary
exemption_summary AS (
    SELECT 
        je.acct,
        COUNT(DISTINCT je.exempt_cd) AS exemption_count,
        SUM(safe_num(je.exempt_val)) AS total_exemption_value,
        STRING_AGG(DISTINCT je.exempt_cd, ', ') AS exemption_codes,
        BOOL_OR(je.exempt_cd LIKE 'HS%') AS has_homestead,
        BOOL_OR(je.exempt_cd LIKE 'OA%') AS has_over_65,
        BOOL_OR(je.exempt_cd LIKE 'DV%') AS has_disabled_veteran
    FROM jur_exempt je
    WHERE je.exempt_val IS NOT NULL AND je.exempt_val <> ''
    GROUP BY je.acct
)

-- Main query combining all CTEs
SELECT 
    -- Basic identification
    ra.acct,
    ra.site_addr_1 AS address,
    ra.site_addr_2 AS address_line_2,
    ra.site_addr_3 AS zip_code,
    ra.str_num AS street_number,
    ra.str AS street_name,
    ra.str_sfx AS street_suffix,
    ra.mailto AS owner_name,
    ra.state_class,
    sc."Description" AS property_type_desc,
    ra."Neighborhood_Code" AS neighborhood_code,
    nc."Description" AS neighborhood_name,
    
    -- Assessment values
    safe_num(ra.tot_mkt_val) AS current_market_value,
    safe_num(ra.tot_appr_val) AS current_appraised_value,
    safe_num(ra.land_val) AS land_value,
    safe_num(ra.bld_val) AS building_value,
    safe_num(ra.xf_val) AS extra_features_value,
    safe_num(ra.ag_val) AS ag_value,
    safe_num(ra.tot_mkt_val) - COALESCE(safe_num(ra.land_val), 0) AS improvement_value,
    
    -- Land details
    safe_num(ra.land_ar) AS lot_sqft,
    lu.description AS land_use_desc,
    
    -- Building details (primary + all)
    bs.building_count,
    bs.primary_year_built,
    bs.primary_year_remodel,
    bs.primary_structure_type,
    bs.primary_quality_code,
    bs.primary_quality_desc,
    bs.primary_heated_sqft,
    bs.primary_gross_sqft,
    bs.primary_effective_sqft,
    bs.total_heated_sqft,
    bs.total_gross_sqft,
    bs.additional_buildings,
    
    -- Building cost analysis
    bs.primary_replacement_cost,
    bs.total_replacement_cost,
    bs.primary_depreciation_pct,
    CASE 
        WHEN bs.total_heated_sqft > 0 
        THEN ROUND(safe_num(ra.bld_val) / bs.total_heated_sqft, 2)
        ELSE NULL 
    END AS building_value_per_sqft,
    
    -- Features from property_features_v2
    pf2.bedrooms_valid AS bedrooms,
    pf2.full_baths_valid AS full_baths,
    pf2.half_baths_valid AS half_baths,
    pf2.has_pool,
    pf2.extra_feature_count,
    pf2.bedrooms_suspect,
    pf2.bedrooms_anomaly OR pf2.full_baths_anomaly OR pf2.half_baths_anomaly AS has_feature_anomaly,
    
    -- Protest history
    ph.total_protests,
    ph.last_protest_date,
    ph.protest_agents,
    
    -- Hearing history
    hh.hearing_count,
    hh.last_hearing_year,
    hh.last_hearing_date,
    hh.last_initial_appraised,
    hh.last_final_appraised,
    hh.last_initial_appraised - hh.last_final_appraised AS last_hearing_reduction,
    CASE 
        WHEN hh.last_initial_appraised > 0 
        THEN ROUND(((hh.last_initial_appraised - hh.last_final_appraised) / hh.last_initial_appraised) * 100, 2)
        ELSE NULL 
    END AS last_hearing_reduction_pct,
    hh.avg_value_reduction AS avg_hearing_reduction,
    hh.successful_protests,
    CASE 
        WHEN hh.hearing_count > 0 
        THEN ROUND((hh.successful_protests::numeric / hh.hearing_count) * 100, 2)
        ELSE NULL 
    END AS protest_success_rate,
    
    -- Sales history
    rs.sale_count AS sales_last_5yr,
    rs.last_sale_date,
    rs.last_sale_price,
    CASE 
        WHEN rs.last_sale_price > 0 
        THEN safe_num(ra.tot_mkt_val) - rs.last_sale_price
        ELSE NULL 
    END AS value_change_since_sale,
    CASE 
        WHEN rs.last_sale_price > 0 
        THEN ROUND(((safe_num(ra.tot_mkt_val) - rs.last_sale_price) / rs.last_sale_price) * 100, 2)
        ELSE NULL 
    END AS value_change_pct_since_sale,
    
    -- Exemptions
    es.exemption_count,
    es.total_exemption_value,
    es.exemption_codes,
    es.has_homestead,
    es.has_over_65,
    es.has_disabled_veteran,
    
    -- Jurisdictions and tax info
    ra.school_dist,
    sd.Description AS school_district_name,
    
    -- Comparable analysis helpers
    CASE 
        WHEN bs.total_heated_sqft > 0 
        THEN ROUND(safe_num(ra.tot_mkt_val) / bs.total_heated_sqft, 2)
        ELSE NULL 
    END AS market_value_per_sqft,
    CASE 
        WHEN safe_num(ra.land_ar) > 0 
        THEN ROUND(safe_num(ra.land_val) / safe_num(ra.land_ar), 2)
        ELSE NULL 
    END AS land_value_per_sqft

FROM real_acct ra
-- Join state class description
LEFT JOIN desc_r_01_state_class sc ON ra.state_class = sc."Code"
-- Join neighborhood
LEFT JOIN real_neighborhood_code nc ON ra."Neighborhood_Code" = nc.cd
-- Join land use
LEFT JOIN land l ON ra.acct = l.acct AND l.num = '1'
LEFT JOIN desc_r_15_land_usecode lu ON l.use_cd = lu."Code"
-- Join school district
LEFT JOIN desc_r_20_school_district sd ON ra.school_dist = sd."Code"
-- Join building summary
LEFT JOIN building_summary bs ON ra.acct = bs.acct
-- Join property features
LEFT JOIN property_features_v2 pf2 ON ra.acct = pf2.acct
-- Join protest/hearing/sales/exemption CTEs
LEFT JOIN protest_history ph ON ra.acct = ph.acct
LEFT JOIN hearing_history hh ON ra.acct = hh.acct
LEFT JOIN recent_sales rs ON ra.acct = rs.acct
LEFT JOIN exemption_summary es ON ra.acct = es.acct

WHERE ra.state_class IN ('A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3', 'B4')  -- All residential state classes
ORDER BY ra.acct;

-- =============================================
-- SAMPLE QUERIES USING RESIDENTIAL_PROTEST_ANALYSIS
-- =============================================

-- 1) Get full protest-ready profile for a specific property
SELECT * 
FROM residential_protest_analysis
WHERE acct = '1234567890123';

-- 2) Find comparable properties in same neighborhood (similar size, age, quality)
SELECT 
    acct,
    address,
    neighborhood_name,
    primary_year_built,
    primary_heated_sqft,
    bedrooms,
    full_baths,
    primary_quality_code,
    current_market_value,
    market_value_per_sqft,
    last_sale_date,
    last_sale_price,
    total_protests,
    successful_protests
FROM residential_protest_analysis
WHERE neighborhood_code = '1234.50'
    AND primary_heated_sqft BETWEEN 1800 AND 2200
    AND primary_year_built BETWEEN 2000 AND 2010
    AND bedrooms BETWEEN 3 AND 4
ORDER BY ABS(primary_heated_sqft - 2000), current_market_value;

-- 3) Properties with successful protest history in neighborhood
SELECT 
    acct,
    address,
    current_market_value,
    total_protests,
    successful_protests,
    protest_success_rate,
    avg_hearing_reduction,
    last_hearing_reduction_pct
FROM residential_protest_analysis
WHERE neighborhood_code LIKE '1234%'
    AND successful_protests > 0
ORDER BY protest_success_rate DESC, successful_protests DESC;

-- 4) Properties with recent sales vs current valuation (potential over-assessment)
SELECT 
    acct,
    address,
    last_sale_date,
    last_sale_price,
    current_market_value,
    value_change_since_sale,
    value_change_pct_since_sale,
    market_value_per_sqft,
    primary_heated_sqft
FROM residential_protest_analysis
WHERE last_sale_date >= CURRENT_DATE - INTERVAL '2 years'
    AND value_change_pct_since_sale > 20  -- More than 20% increase
ORDER BY value_change_pct_since_sale DESC;

-- 5) Neighborhood comparison for protest targeting
SELECT 
    neighborhood_code,
    neighborhood_name,
    COUNT(*) AS property_count,
    ROUND(AVG(current_market_value), 0) AS avg_market_value,
    ROUND(AVG(market_value_per_sqft), 2) AS avg_value_per_sqft,
    SUM(total_protests) AS total_neighborhood_protests,
    ROUND(AVG(CASE WHEN hearing_count > 0 THEN protest_success_rate ELSE NULL END), 2) AS avg_success_rate,
    COUNT(CASE WHEN successful_protests > 0 THEN 1 END) AS properties_with_success
FROM residential_protest_analysis
WHERE neighborhood_code LIKE '1234%'
GROUP BY neighborhood_code, neighborhood_name
ORDER BY avg_success_rate DESC, total_neighborhood_protests DESC;

-- 6) Properties with multiple buildings (often mis-assessed)
SELECT 
    acct,
    address,
    building_count,
    primary_structure_type,
    additional_buildings,
    total_heated_sqft,
    current_market_value,
    building_value,
    building_value_per_sqft,
    total_protests,
    last_hearing_reduction_pct
FROM residential_protest_analysis
WHERE building_count > 1
ORDER BY building_count DESC, current_market_value DESC;

-- 7) Wall Street (ZIP 77040) full protest analysis
SELECT 
    acct,
    address,
    owner_name,
    current_market_value,
    current_appraised_value,
    land_value,
    building_value,
    primary_year_built,
    primary_heated_sqft,
    bedrooms,
    full_baths,
    primary_quality_desc,
    market_value_per_sqft,
    building_value_per_sqft,
    building_count,
    has_pool,
    total_protests,
    successful_protests,
    last_hearing_reduction_pct,
    last_sale_date,
    last_sale_price,
    value_change_pct_since_sale,
    has_homestead,
    exemption_codes
FROM residential_protest_analysis
WHERE zip_code = '77040'
    AND (address ILIKE '%WALL%' OR street_name = 'WALL')
ORDER BY street_number;



