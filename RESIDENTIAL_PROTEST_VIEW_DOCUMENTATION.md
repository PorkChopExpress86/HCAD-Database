# RESIDENTIAL PROTEST ANALYSIS VIEW

## Overview
The `residential_protest_analysis` view provides comprehensive information for protesting property tax assessments and comparing residential properties. It covers **all residential state classes**:
- **A1-A4**: Single-family, mobile homes, auxiliary buildings, half-duplex
- **B1-B4**: Multi-family, two-family, three-family, four-or-more-family

The view includes properties with multiple buildings.

## View Statistics
- **Total Properties**: 1,185,083 residential properties
  - Single-family (A1): 1,142,787 (96.4%)
  - Mobile homes (A2): 11,921 (1.0%)
  - Auxiliary buildings (A3): 10,986 (0.9%)
  - Half-duplex (A4): 3,892 (0.3%)
  - Multi-family (B1): 5,807 (0.5%)
  - Two-family (B2): 8,901 (0.8%)
  - Three-family (B3): 501 (<0.1%)
  - Four+ family (B4): 288 (<0.1%)

### Wall Street (ZIP 77040) Example
- 87 properties
- 44 have protest history (50.6%)
- 17 successful protests (38.6% success rate)
- Average reduction: 1.22%
- Average market value: $383,220
- Average value per sqft: $161.61

## Automatic Setup
This view is automatically created after data loading via `post_load_setup.sql`, which includes:
1. `safe_num()` helper function
2. `property_features` view
3. `property_features_v2` view (with anomaly detection)
4. `residential_protest_analysis` view (this comprehensive view)

## Key Features

### 1. Property Identification
- `acct` - Property account number
- `address`, `address_line_2`, `zip_code` - Full address
- `street_number`, `street_name`, `street_suffix` - Parsed address components
- `owner_name` - Current owner
- `state_class` - Property classification (A1, A2)
- `neighborhood_code`, `neighborhood_name` - Neighborhood information

### 2. Assessment Values
- `current_market_value` - Current market value
- `current_appraised_value` - Current appraised value
- `land_value` - Land value only
- `building_value` - Building value only
- `extra_features_value` - Value of extra features (pools, etc.)
- `improvement_value` - Total improvement value (market - land)

### 3. Building Details
**Primary Building (bld_num = '1'):**
- `primary_year_built` - Year constructed
- `primary_year_remodel` - Last remodel year
- `primary_structure_type` - Structure type description
- `primary_quality_code` - Quality code
- `primary_quality_desc` - Quality description (Good, Average, etc.)
- `primary_heated_sqft` - Heated square footage
- `primary_gross_sqft` - Gross square footage
- `primary_replacement_cost` - CAMA replacement cost
- `primary_depreciation_pct` - Depreciation percentage

**All Buildings:**
- `building_count` - Total number of buildings
- `total_heated_sqft` - Sum of all building heated areas
- `total_replacement_cost` - Sum of all replacement costs
- `additional_buildings` - Details of buildings beyond primary

### 4. Property Features
- `bedrooms` - Number of bedrooms (validated, 1-8)
- `full_baths` - Number of full bathrooms (validated, 0-6)
- `half_baths` - Number of half bathrooms (validated, 0-4)
- `has_pool` - Boolean indicating pool presence
- `extra_feature_count` - Count of extra features
- `bedrooms_suspect` - Flag for questionable bedroom counts
- `has_feature_anomaly` - Flag for any feature anomalies

### 5. Protest History
- `total_protests` - Total number of protests filed
- `last_protest_date` - Date of most recent protest
- `protest_agents` - Names of agents who filed protests

### 6. Hearing History (Last 5 Years)
- `hearing_count` - Number of hearings
- `last_hearing_year` - Most recent hearing year
- `last_hearing_date` - Most recent hearing date
- `last_initial_appraised` - Initial value in last hearing
- `last_final_appraised` - Final value in last hearing
- `last_hearing_reduction` - Dollar amount reduced
- `last_hearing_reduction_pct` - Percentage reduced
- `avg_hearing_reduction` - Average reduction across all hearings
- `successful_protests` - Count of protests that reduced value
- `protest_success_rate` - Percentage of successful protests

### 7. Sales History (Last 5 Years)
- `sales_last_5yr` - Number of sales in last 5 years
- `last_sale_date` - Most recent sale date
- `last_sale_price` - Most recent sale price (NULL - not in deeds table)
- `value_change_since_sale` - Change in value since last sale
- `value_change_pct_since_sale` - Percentage change since sale

### 8. Exemptions
- `exemption_count` - Number of exemptions
- `total_exemption_value` - Total exemption value
- `exemption_codes` - List of exemption codes
- `has_homestead` - Homestead exemption flag
- `has_over_65` - Over 65 exemption flag
- `has_disabled_veteran` - Disabled veteran exemption flag

### 9. Comparable Analysis Helpers
- `market_value_per_sqft` - Market value / total heated sqft
- `building_value_per_sqft` - Building value / total heated sqft
- `land_value_per_sqft` - Land value / lot sqft
- `lot_sqft` - Lot square footage
- `school_dist`, `school_district_name` - School district info

## Common Use Cases

### 1. Get Full Protest-Ready Profile
```sql
SELECT * 
FROM residential_protest_analysis
WHERE acct = '1234567890123';
```

### 2. Find Comparable Properties
```sql
SELECT 
    acct, address, neighborhood_name,
    primary_year_built, primary_heated_sqft,
    bedrooms, full_baths, primary_quality_desc,
    current_market_value, market_value_per_sqft
FROM residential_protest_analysis
WHERE neighborhood_code = '1234.50'
    AND primary_heated_sqft BETWEEN 1800 AND 2200
    AND primary_year_built BETWEEN 2000 AND 2010
    AND bedrooms BETWEEN 3 AND 4
ORDER BY ABS(primary_heated_sqft - 2000);
```

### 3. Analyze Protest Success in Neighborhood
```sql
SELECT 
    acct, address, current_market_value,
    total_protests, successful_protests,
    protest_success_rate,
    avg_hearing_reduction,
    last_hearing_reduction_pct
FROM residential_protest_analysis
WHERE neighborhood_code LIKE '1234%'
    AND successful_protests > 0
ORDER BY protest_success_rate DESC;
```

### 4. Properties with Multiple Buildings
```sql
SELECT 
    acct, address,
    building_count,
    primary_structure_type,
    additional_buildings,
    total_heated_sqft,
    current_market_value,
    building_value_per_sqft
FROM residential_protest_analysis
WHERE building_count > 1
ORDER BY building_count DESC;
```

### 5. Neighborhood Comparison
```sql
SELECT 
    neighborhood_code, neighborhood_name,
    COUNT(*) AS property_count,
    ROUND(AVG(current_market_value), 0) AS avg_market_value,
    ROUND(AVG(market_value_per_sqft), 2) AS avg_value_per_sqft,
    SUM(total_protests) AS total_protests,
    ROUND(AVG(CASE WHEN hearing_count > 0 THEN protest_success_rate END), 2) AS avg_success_rate
FROM residential_protest_analysis
WHERE neighborhood_code LIKE '1234%'
GROUP BY neighborhood_code, neighborhood_name
ORDER BY avg_success_rate DESC;
```

## Data Quality Notes

1. **Sale Prices**: The `deeds` table does not contain sale prices, so `last_sale_price` is always NULL
2. **Validated Features**: Bedroom/bath counts are validated and capped at reasonable ranges
3. **Anomaly Flags**: Use `bedrooms_suspect` and `has_feature_anomaly` to identify properties that may need data review
4. **Multiple Buildings**: Properties with `building_count` > 1 may have complex valuation scenarios

## Files

- `create_residential_protest_view.sql` - Complete view definition
- `test_residential_protest_view.sql` - Sample test queries
- This documentation file

## Dependencies

This view requires:
- `safe_num()` function (for text-to-numeric conversion)
- `property_features_v2` view (for validated features)
- Base tables: `real_acct`, `building_res`, `arb_protest_real`, `arb_hearings_real`, `deeds`, `jur_exempt`
- Description tables: `desc_r_01_state_class`, `desc_r_15_land_usecode`, `desc_r_20_school_district`, `real_neighborhood_code`
