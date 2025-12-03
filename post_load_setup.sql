-- Post-load SQL setup script
-- This script creates helper functions and views after data is loaded
-- Run this automatically at the end of load.py

-- =============================================
-- HELPER FUNCTION: safe_num
-- Converts text fields to numeric, handling nulls and non-numeric data
-- =============================================
CREATE OR REPLACE FUNCTION safe_num(v text) RETURNS numeric AS $$
    SELECT CASE
        WHEN v IS NULL OR TRIM(v) = '' THEN NULL
        ELSE NULLIF(REGEXP_REPLACE(v, '[^0-9.]', '', 'g'), '')::numeric
    END;
$$ LANGUAGE SQL IMMUTABLE;

-- =============================================
-- PROPERTY FEATURES VIEW - normalize and aggregate features for analysis
-- =============================================
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
    COALESCE(STRING_AGG(DISTINCT o.name, '; '), '') AS owners,
    safe_num(ra.tot_mkt_val) AS tot_mkt_val_num,
    safe_num(ra.tot_appr_val) AS tot_appr_val_num,
    safe_num(ra.land_val) AS land_val_num,
    safe_num(ra.land_ar) AS lot_sqft,
    COALESCE(
        safe_num(br.heat_ar),
        safe_num(br.im_sq_ft),
        safe_num(ra.bld_ar)
    ) AS heated_area_sqft,
    br.date_erected AS bld_date_erected,
    br.yr_remodel AS bld_year_remodel,
    br.structure_dscr AS building_type,
    br.dscr AS building_description,
    br.qa_cd AS building_quality,
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
    COALESCE((SELECT COUNT(*) FROM extra_features ef WHERE ef.acct = ra.acct), 0) AS extra_feature_count,
    COALESCE((
        SELECT BOOL_OR(
            ef.dscr ILIKE '%pool%' OR ef.l_dscr ILIKE '%pool%' OR ef.s_dscr ILIKE '%pool%'
        )
        FROM extra_features ef
        WHERE ef.acct = ra.acct
    ), FALSE) AS has_pool,
    COALESCE((
        SELECT COUNT(*) FROM permits p
        WHERE p.acct = ra.acct
          AND p.issue_date IS NOT NULL
          AND p.issue_date <> ''
          AND to_date(p.issue_date, 'MM/DD/YYYY') >= (CURRENT_DATE - INTERVAL '5 years')
    ), 0) AS permits_last_5yr,
    COALESCE((
        SELECT COUNT(*) FROM deeds d
        WHERE d.acct = ra.acct
          AND d.dos IS NOT NULL
          AND d.dos <> ''
          AND to_date(d.dos, 'MM/DD/YYYY') >= (CURRENT_DATE - INTERVAL '5 years')
    ), 0) AS sales_last_5yr,
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
-- PROPERTY FEATURES V2 - with anomaly detection
-- =============================================
CREATE OR REPLACE VIEW property_features_v2 AS
SELECT
    pf.*,
    pf.bedrooms::numeric AS bedrooms_raw,
    CASE WHEN pf.bedrooms::numeric BETWEEN 1 AND 8 THEN pf.bedrooms::int ELSE NULL END AS bedrooms_valid,
    (pf.bedrooms::numeric < 1 OR pf.bedrooms::numeric > 8) AS bedrooms_anomaly,
    (pf.bedrooms::numeric > 12 OR pf.bedrooms::numeric < 0 OR (pf.bedrooms::numeric = 0 AND COALESCE(pf.heated_area_sqft,0) > 5000)) AS bedrooms_suspect,
    CASE WHEN pf.bedrooms::numeric > 0 THEN LEAST(pf.bedrooms::numeric::int, 8) ELSE NULL END AS bedrooms_capped,
    pf.full_baths::numeric AS full_baths_raw,
    CASE WHEN pf.full_baths::numeric BETWEEN 0 AND 6 THEN pf.full_baths::int ELSE NULL END AS full_baths_valid,
    (pf.full_baths::numeric < 0 OR pf.full_baths::numeric > 6) AS full_baths_anomaly,
    pf.half_baths::numeric AS half_baths_raw,
    CASE WHEN pf.half_baths::numeric BETWEEN 0 AND 4 THEN pf.half_baths::int ELSE NULL END AS half_baths_valid,
    (pf.half_baths::numeric < 0 OR pf.half_baths::numeric > 4) AS half_baths_anomaly,
    (COALESCE(pf.heated_area_sqft, 0) = 0 AND COALESCE(pf.heated_area_sqft, 0) < COALESCE(safe_num(ra.bld_ar), 0) AND COALESCE(safe_num(ra.bld_ar), 0) > 0) AS heated_area_anomaly,
    ABS(COALESCE(pf.tot_mkt_val_num, 0) - COALESCE(pf.jur_appraised_val_sum, 0)) > 1000000 AS large_value_anomaly
FROM property_features pf
LEFT JOIN real_acct ra ON pf.acct = ra.acct;

-- =============================================
-- COMPREHENSIVE RESIDENTIAL PROPERTY VIEW FOR PROTESTS
-- Covers all residential state classes: A1-A4, B1-B4
-- =============================================
CREATE OR REPLACE VIEW residential_protest_analysis AS
WITH 
building_summary AS (
    SELECT 
        br.acct,
        COUNT(DISTINCT br.bld_num) AS building_count,
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
        SUM(safe_num(br.heat_ar)) AS total_heated_sqft,
        SUM(safe_num(br.gross_ar)) AS total_gross_sqft,
        SUM(safe_num(br.cama_replacement_cost)) AS total_replacement_cost,
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
hearing_history AS (
    SELECT 
        ah.acct,
        COUNT(*) AS hearing_count,
        MAX(ah."Tax_Year") AS last_hearing_year,
        MAX(ah."Actual_Hearing_Date") AS last_hearing_date,
        MAX(CASE WHEN ah."Tax_Year" = (SELECT MAX(ah2."Tax_Year") FROM arb_hearings_real ah2 WHERE ah2.acct = ah.acct)
            THEN safe_num(ah."Initial_Appraised_Value") END) AS last_initial_appraised,
        MAX(CASE WHEN ah."Tax_Year" = (SELECT MAX(ah2."Tax_Year") FROM arb_hearings_real ah2 WHERE ah2.acct = ah.acct)
            THEN safe_num(ah."Final_Appraised_Value") END) AS last_final_appraised,
        AVG(safe_num(ah."Initial_Appraised_Value") - safe_num(ah."Final_Appraised_Value")) AS avg_value_reduction,
        SUM(CASE WHEN safe_num(ah."Final_Appraised_Value") < safe_num(ah."Initial_Appraised_Value") THEN 1 ELSE 0 END) AS successful_protests
    FROM arb_hearings_real ah
    WHERE ah."Tax_Year" IS NOT NULL 
        AND CAST(ah."Tax_Year" AS INTEGER) >= EXTRACT(YEAR FROM CURRENT_DATE) - 5
    GROUP BY ah.acct
),
recent_sales AS (
    SELECT 
        d.acct,
        COUNT(*) AS sale_count,
        MAX(to_date(NULLIF(d.dos, ''), 'MM/DD/YYYY')) AS last_sale_date,
        NULL::numeric AS last_sale_price
    FROM deeds d
    WHERE d.dos IS NOT NULL 
        AND d.dos <> ''
        AND to_date(NULLIF(d.dos, ''), 'MM/DD/YYYY') >= CURRENT_DATE - INTERVAL '5 years'
    GROUP BY d.acct
),
exemption_summary AS (
    SELECT 
        je.acct,
        COUNT(DISTINCT je.exempt_cat) AS exemption_count,
        SUM(safe_num(je.exempt_val)) AS total_exemption_value,
        STRING_AGG(DISTINCT je.exempt_cat, ', ') AS exemption_codes,
        BOOL_OR(je.exempt_cat LIKE 'HS%') AS has_homestead,
        BOOL_OR(je.exempt_cat LIKE 'OA%') AS has_over_65,
        BOOL_OR(je.exempt_cat LIKE 'DV%') AS has_disabled_veteran
    FROM jur_exempt je
    WHERE je.exempt_val IS NOT NULL AND je.exempt_val <> ''
    GROUP BY je.acct
)
SELECT 
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
    nc.dscr AS neighborhood_name,
    safe_num(ra.tot_mkt_val) AS current_market_value,
    safe_num(ra.tot_appr_val) AS current_appraised_value,
    safe_num(ra.land_val) AS land_value,
    safe_num(ra.bld_val) AS building_value,
    safe_num(ra.x_features_val) AS extra_features_value,
    safe_num(ra.ag_val) AS ag_value,
    safe_num(ra.tot_mkt_val) - COALESCE(safe_num(ra.land_val), 0) AS improvement_value,
    safe_num(ra.land_ar) AS lot_sqft,
    lu."Description" AS land_use_desc,
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
    bs.primary_replacement_cost,
    bs.total_replacement_cost,
    bs.primary_depreciation_pct,
    CASE 
        WHEN bs.total_heated_sqft > 0 
        THEN ROUND(safe_num(ra.bld_val) / bs.total_heated_sqft, 2)
        ELSE NULL 
    END AS building_value_per_sqft,
    pf2.bedrooms_valid AS bedrooms,
    pf2.full_baths_valid AS full_baths,
    pf2.half_baths_valid AS half_baths,
    pf2.has_pool,
    pf2.extra_feature_count,
    pf2.bedrooms_suspect,
    pf2.bedrooms_anomaly OR pf2.full_baths_anomaly OR pf2.half_baths_anomaly AS has_feature_anomaly,
    ph.total_protests,
    ph.last_protest_date,
    ph.protest_agents,
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
    es.exemption_count,
    es.total_exemption_value,
    es.exemption_codes,
    es.has_homestead,
    es.has_over_65,
    es.has_disabled_veteran,
    ra.school_dist,
    sd."Description" AS school_district_name,
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
LEFT JOIN desc_r_01_state_class sc ON ra.state_class = sc."Code"
LEFT JOIN real_neighborhood_code nc ON ra."Neighborhood_Code" = nc.cd
LEFT JOIN land l ON ra.acct = l.acct AND l.num = '1'
LEFT JOIN desc_r_15_land_usecode lu ON l.use_cd = lu."Code"
LEFT JOIN desc_r_20_school_district sd ON ra.school_dist = sd."Code"
LEFT JOIN building_summary bs ON ra.acct = bs.acct
LEFT JOIN property_features_v2 pf2 ON ra.acct = pf2.acct
LEFT JOIN protest_history ph ON ra.acct = ph.acct
LEFT JOIN hearing_history hh ON ra.acct = hh.acct
LEFT JOIN recent_sales rs ON ra.acct = rs.acct
LEFT JOIN exemption_summary es ON ra.acct = es.acct
WHERE ra.state_class IN ('A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3', 'B4')
ORDER BY ra.acct;
