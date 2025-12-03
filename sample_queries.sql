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
    ra.site_addr_3 AS city_zip,
    ra.state_class,
    ra.tot_mkt_val AS market_value,
    ra.tot_appr_val AS appraised_value,
    ra.land_val,
    ra.bld_val AS building_value,
    ra.school_dist,
    ra.neighborhood_code
FROM real_acct ra
WHERE ra.acct = '1234567890123';

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
    ln.units AS lot_sqft,
    ra.tot_mkt_val AS market_value,
    ra.tot_appr_val AS appraised_value
FROM real_acct ra
LEFT JOIN building_res br ON ra.acct = br.acct AND br.bld_num = '1'
LEFT JOIN fixtures fx_bed ON ra.acct = fx_bed.acct AND fx_bed.bld_num = '1' AND fx_bed.fixture_type = 'BED'
LEFT JOIN fixtures fx_bath ON ra.acct = fx_bath.acct AND fx_bath.bld_num = '1' AND fx_bath.fixture_type = 'BTH'
LEFT JOIN land ln ON ra.acct = ln.acct AND ln.land_seq = '1'
WHERE ra.neighborhood_code = '1234.50'
  AND br.heat_ar BETWEEN 1800 AND 2200
  AND br.yr_blt BETWEEN 2000 AND 2010
  AND fx_bed.fixture_units BETWEEN 3 AND 4
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
    bt.description AS building_type,
    bs.description AS building_style,
    bq.description AS quality,
    -- Fixtures/features
    STRING_AGG(DISTINCT fx.fixture_type || ': ' || fx.fixture_units, ', ') AS fixtures,
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
LEFT JOIN desc_r_02_building_type_code bt ON br.bld_type_cd = bt.bld_type_cd
LEFT JOIN desc_r_03_building_style bs ON br.bld_style_cd = bs.bld_style_cd
LEFT JOIN desc_r_07_quality_code bq ON br.quality_cd = bq.quality_cd
LEFT JOIN fixtures fx ON ra.acct = fx.acct AND fx.bld_num = '1'
LEFT JOIN land l ON ra.acct = l.acct AND l.land_seq = '1'
LEFT JOIN desc_r_15_land_usecode lu ON l.land_use_cd = lu.land_use_cd
WHERE ra.acct = '1234567890123'
GROUP BY ra.acct, ra.mailto, ra.site_addr_1, br.bld_num, br.yr_blt, br.yr_remodel, 
         br.bld_ar, br.heat_ar, bt.description, bs.description, bq.description,
         l.land_ar, l.units, lu.description, ra.land_val, ra.bld_val, ra.tot_mkt_val;

-- =============================================
-- 4. OWNERSHIP AND DEED HISTORY
-- =============================================

-- Get ownership history for a property
SELECT 
    oh.acct,
    oh.owner_name,
    oh.inst_date AS deed_date,
    oh.deed_type,
    oh.grantor,
    oh.vol_page AS volume_page
FROM ownership_history oh
WHERE oh.acct = '1234567890123'
ORDER BY oh.inst_date DESC;

-- Get current owners with ownership percentages
SELECT 
    o.acct,
    ra.site_addr_1,
    o.own_name AS owner_name,
    o.own_pct AS ownership_percent,
    o.own_type AS owner_type
FROM owners o
JOIN real_acct ra ON o.acct = ra.acct
WHERE o.acct = '1234567890123'
ORDER BY o.own_seq;

-- =============================================
-- 5. EXEMPTIONS AND TAX JURISDICTIONS
-- =============================================

-- Get all exemptions for a property by jurisdiction
SELECT 
    je.acct,
    ra.mailto AS owner,
    ra.site_addr_1,
    jd.description AS jurisdiction,
    je.exempt_cd,
    jed.description AS exemption_description,
    je.exempt_val AS exemption_value
FROM jur_exempt je
JOIN real_acct ra ON je.acct = ra.acct
LEFT JOIN desc_r_12_real_jurisdictions jd ON je.jur_cd = jd.jur_cd
LEFT JOIN jur_exemption_dscr jed ON je.jur_cd = jed.jur_cd AND je.exempt_cd = jed.exempt_cd
WHERE je.acct = '1234567890123'
ORDER BY jd.description, je.exempt_cd;

-- Get property values by taxing jurisdiction
SELECT 
    jv.acct,
    ra.mailto AS owner,
    jd.description AS jurisdiction,
    jv.appraised_val,
    jv.assessed_val,
    jv.taxable_val,
    jv.tax_rate
FROM jur_value jv
JOIN real_acct ra ON jv.acct = ra.acct
LEFT JOIN desc_r_12_real_jurisdictions jd ON jv.jur_cd = jd.jur_cd
WHERE jv.acct = '1234567890123'
ORDER BY jd.description;

-- =============================================
-- 6. NEIGHBORHOOD AND MARKET ANALYSIS
-- =============================================

-- Get neighborhood statistics (median values, avg sqft, etc.)
SELECT 
    ra.neighborhood_code,
    nc.description AS neighborhood_name,
    COUNT(*) AS property_count,
    ROUND(AVG(ra.tot_mkt_val), 0) AS avg_market_value,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ra.tot_mkt_val) AS median_market_value,
    ROUND(AVG(br.heat_ar), 0) AS avg_living_sqft,
    ROUND(AVG(ra.land_ar), 0) AS avg_lot_sqft,
    MIN(br.yr_blt) AS oldest_year_built,
    MAX(br.yr_blt) AS newest_year_built
FROM real_acct ra
LEFT JOIN building_res br ON ra.acct = br.acct AND br.bld_num = '1'
LEFT JOIN real_neighborhood_code nc ON ra.neighborhood_code = nc.neighborhood_code
WHERE ra.neighborhood_code LIKE '1234%'
  AND ra.state_class = 'A1'  -- Single-family residential
GROUP BY ra.neighborhood_code, nc.description
ORDER BY ra.neighborhood_code;

-- Market area property counts and values
SELECT 
    ma.market_area_cd,
    ma.description AS market_area,
    COUNT(DISTINCT ra.acct) AS property_count,
    ROUND(AVG(ra.tot_mkt_val), 0) AS avg_value,
    SUM(ra.tot_mkt_val) AS total_value
FROM real_acct ra
JOIN desc_r_21_market_area ma ON ra.market_area_1 = ma.market_area_cd
GROUP BY ma.market_area_cd, ma.description
ORDER BY property_count DESC
LIMIT 20;

-- =============================================
-- 7. SALES AND DEED ANALYSIS
-- =============================================

-- Recent sales in a neighborhood
SELECT 
    d.acct,
    ra.site_addr_1,
    d.inst_date AS sale_date,
    d.deed_type,
    d.sale_price,
    ra.tot_mkt_val AS current_market_value,
    br.heat_ar AS living_sqft,
    ROUND(d.sale_price::numeric / NULLIF(br.heat_ar, 0), 2) AS price_per_sqft
FROM deeds d
JOIN real_acct ra ON d.acct = ra.acct
LEFT JOIN building_res br ON d.acct = br.acct AND br.bld_num = '1'
WHERE ra.neighborhood_code = '1234.50'
  AND d.inst_date >= CURRENT_DATE - INTERVAL '1 year'
  AND d.sale_price > 0
ORDER BY d.inst_date DESC;

-- =============================================
-- 8. PROTEST AND HEARING ANALYSIS
-- =============================================

-- Properties with ARB protests
SELECT 
    ap.acct,
    ra.mailto AS owner,
    ra.site_addr_1,
    ap.tax_year,
    ap.protested_by,
    ap.protested_dt AS protest_date,
    ap.initial_value,
    ap.protest_value,
    ap.initial_value - ap.protest_value AS reduction_requested
FROM arb_protest_real ap
JOIN real_acct ra ON ap.acct = ra.acct
WHERE ap.tax_year = '2025'
ORDER BY ap.protested_dt DESC;

-- ARB hearing results
SELECT 
    ah.acct,
    ra.mailto AS owner,
    ah.tax_year,
    ah.actual_hearing_date,
    ah.initial_value AS noticed_value,
    ah.final_value AS hearing_result,
    ah.initial_value - ah.final_value AS value_reduction,
    cc.description AS conclusion
FROM arb_hearings_real ah
JOIN real_acct ra ON ah.acct = ra.acct
LEFT JOIN desc_r_25_conclusion_code cc ON ah.letter_type = cc.conclusion_cd
WHERE ah.tax_year = '2025'
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
    p.issued_dt AS issued_date,
    p.final_dt AS final_date,
    p.valuation AS permit_value,
    ps.description AS status
FROM permits p
JOIN real_acct ra ON p.acct = ra.acct
LEFT JOIN desc_r_19_permit_code pc ON p.permit_type = pc.permit_cd
LEFT JOIN desc_r_18_permit_status ps ON p.status = ps.permit_status_cd
WHERE p.issued_dt >= CURRENT_DATE - INTERVAL '2 years'
ORDER BY p.issued_dt DESC
LIMIT 100;

-- =============================================
-- 10. AGGREGATE REPORTS
-- =============================================

-- Total property values by school district
SELECT 
    sd.school_dist_cd,
    sd.description AS school_district,
    COUNT(ra.acct) AS property_count,
    SUM(ra.tot_mkt_val) AS total_market_value,
    SUM(ra.tot_appr_val) AS total_appraised_value,
    ROUND(AVG(ra.tot_mkt_val), 0) AS avg_market_value
FROM real_acct ra
JOIN desc_r_20_school_district sd ON ra.school_dist = sd.school_dist_cd
WHERE ra.state_class IN ('A1', 'A2', 'A3')  -- Residential
GROUP BY sd.school_dist_cd, sd.description
ORDER BY total_market_value DESC;

-- Property state class distribution
SELECT 
    sc.state_class,
    sc.description AS property_type,
    COUNT(ra.acct) AS property_count,
    SUM(ra.tot_mkt_val) AS total_value,
    ROUND(AVG(ra.tot_mkt_val), 0) AS avg_value
FROM real_acct ra
JOIN desc_r_01_state_class sc ON ra.state_class = sc.state_class
GROUP BY sc.state_class, sc.description
ORDER BY property_count DESC;
