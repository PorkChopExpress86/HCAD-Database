-- =============================================
-- TEST QUERIES FOR RESIDENTIAL_PROTEST_ANALYSIS VIEW
-- Sample queries to demonstrate the comprehensive data available
-- =============================================

-- 1) Wall Street (ZIP 77040) - Full protest-ready analysis
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
    additional_buildings,
    has_pool,
    total_protests,
    successful_protests,
    protest_success_rate,
    last_hearing_reduction_pct,
    last_sale_date,
    sales_last_5yr,
    has_homestead,
    exemption_codes
FROM residential_protest_analysis
WHERE zip_code = '77040'
    AND (address ILIKE '%WALL%' OR street_name = 'WALL')
ORDER BY street_number;

-- 2) Properties with multiple buildings on Wall Street
SELECT 
    acct,
    address,
    building_count,
    primary_structure_type,
    additional_buildings,
    total_heated_sqft,
    current_market_value,
    market_value_per_sqft
FROM residential_protest_analysis
WHERE zip_code = '77040'
    AND (address ILIKE '%WALL%' OR street_name = 'WALL')
    AND building_count > 1
ORDER BY building_count DESC;

-- 3) Protest success analysis for Wall Street
SELECT 
    COUNT(*) as total_properties,
    COUNT(CASE WHEN total_protests > 0 THEN 1 END) as properties_with_protests,
    SUM(total_protests) as total_protest_count,
    SUM(successful_protests) as total_successful,
    ROUND(AVG(CASE WHEN hearing_count > 0 THEN protest_success_rate END), 2) as avg_success_rate,
    ROUND(AVG(last_hearing_reduction_pct), 2) as avg_reduction_pct,
    MIN(current_market_value) as min_value,
    MAX(current_market_value) as max_value,
    ROUND(AVG(current_market_value), 0) as avg_value,
    ROUND(AVG(market_value_per_sqft), 2) as avg_per_sqft
FROM residential_protest_analysis
WHERE zip_code = '77040'
    AND (address ILIKE '%WALL%' OR street_name = 'WALL');

-- 4) Value distribution by year built
SELECT 
    CASE 
        WHEN primary_year_built::int < 1980 THEN 'Pre-1980'
        WHEN primary_year_built::int BETWEEN 1980 AND 1989 THEN '1980s'
        WHEN primary_year_built::int BETWEEN 1990 AND 1999 THEN '1990s'
        WHEN primary_year_built::int BETWEEN 2000 AND 2009 THEN '2000s'
        ELSE '2010+' 
    END as decade,
    COUNT(*) as property_count,
    ROUND(AVG(current_market_value), 0) as avg_value,
    ROUND(AVG(market_value_per_sqft), 2) as avg_per_sqft,
    ROUND(AVG(primary_heated_sqft), 0) as avg_sqft
FROM residential_protest_analysis
WHERE zip_code = '77040'
    AND (address ILIKE '%WALL%' OR street_name = 'WALL')
GROUP BY decade
ORDER BY decade;

-- 5) Properties with anomalies that might need review
SELECT 
    acct,
    address,
    current_market_value,
    bedrooms,
    full_baths,
    half_baths,
    primary_heated_sqft,
    bedrooms_suspect,
    has_feature_anomaly
FROM residential_protest_analysis
WHERE zip_code = '77040'
    AND (address ILIKE '%WALL%' OR street_name = 'WALL')
    AND (bedrooms_suspect OR has_feature_anomaly)
ORDER BY acct;

-- 6) Homestead exemption analysis
SELECT 
    has_homestead,
    COUNT(*) as property_count,
    ROUND(AVG(current_market_value), 0) as avg_value,
    COUNT(CASE WHEN total_protests > 0 THEN 1 END) as with_protests
FROM residential_protest_analysis
WHERE zip_code = '77040'
    AND (address ILIKE '%WALL%' OR street_name = 'WALL')
GROUP BY has_homestead;
