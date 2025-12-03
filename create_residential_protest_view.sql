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
        NULL::numeric AS last_sale_price  -- deeds table doesn't have sale_price column
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
    nc.dscr AS neighborhood_name,
    
    -- Assessment values
    safe_num(ra.tot_mkt_val) AS current_market_value,
    safe_num(ra.tot_appr_val) AS current_appraised_value,
    safe_num(ra.land_val) AS land_value,
    safe_num(ra.bld_val) AS building_value,
    safe_num(ra.x_features_val) AS extra_features_value,
    safe_num(ra.ag_val) AS ag_value,
    safe_num(ra.tot_mkt_val) - COALESCE(safe_num(ra.land_val), 0) AS improvement_value,
    
    -- Land details
    safe_num(ra.land_ar) AS lot_sqft,
    lu."Description" AS land_use_desc,
    
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
    sd."Description" AS school_district_name,
    
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
