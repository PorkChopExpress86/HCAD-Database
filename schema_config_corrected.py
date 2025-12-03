"""
Corrected schema configuration with actual column names from source files.
Primary keys manually verified against data patterns and codebook.
"""

SCHEMA_MAP = {
    # ========== CORE REAL PROPERTY TABLE ==========
    "real_acct": {
        "primary_key": ["acct"],
        "foreign_keys": [],
        "indexes": [["neighborhood_code"], ["school_dist"], ["state_class"]],
    },
    # ========== BUILDING TABLES ==========
    "building_res": {
        "primary_key": ["acct", "bld_num"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
        "indexes": [["yr_blt"], ["tot_use_cd"]],
    },
    "building_other": {
        "primary_key": ["acct", "bld_num"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    # ========== BUILDING DETAIL TABLES ==========
    "fixtures": {
        "primary_key": ["acct", "bld_num", "type"],
        "foreign_keys": [
            (["acct", "bld_num"], "building_res", ["acct", "bld_num"]),
        ],
    },
    "exterior": {
        "primary_key": ["acct", "bld_num", "sar_cd"],
        "foreign_keys": [
            (["acct", "bld_num"], "building_res", ["acct", "bld_num"]),
        ],
    },
    "structural_elem1": {
        "primary_key": ["acct", "bld_num", "code"],
        "foreign_keys": [
            (["acct", "bld_num"], "building_res", ["acct", "bld_num"]),
        ],
    },
    "structural_elem2": {
        "primary_key": ["acct", "bld_num", "code"],
        "foreign_keys": [
            (["acct", "bld_num"], "building_res", ["acct", "bld_num"]),
        ],
    },
    "extra_features": {
        "primary_key": ["acct", "cd"],  # cd is the feature code
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    "extra_features_detail1": {
        "primary_key": ["acct", "cd", "bld_num"],
        "foreign_keys": [
            (["acct", "cd"], "extra_features", ["acct", "cd"]),
        ],
    },
    "extra_features_detail2": {
        "primary_key": ["acct", "cd", "bld_num"],
        "foreign_keys": [
            (["acct", "cd"], "extra_features", ["acct", "cd"]),
        ],
    },
    # ========== LAND TABLES ==========
    "land": {
        "primary_key": ["acct", "num"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    "land_ag": {
        "primary_key": ["acct", "num"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    # ========== TAX JURISDICTION TABLES ==========
    "jur_value": {
        "primary_key": ["acct", "tax_district"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
        "indexes": [["appraised_val"], ["taxable_val"]],
    },
    "jur_exempt": {
        "primary_key": ["acct", "tax_district", "exempt_cat"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    "jur_exempt_cd": {
        "primary_key": ["acct", "exempt_cat"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    "jur_exemption_dscr": {
        "primary_key": ["exempt_cat"],
        "foreign_keys": [],
    },
    "jur_tax_dist_exempt_value_rate": {
        "primary_key": [],  # No suitable unique key
        "foreign_keys": [],
    },
    # ========== OWNERSHIP TABLES ==========
    "owners": {
        "primary_key": ["acct", "ln_num"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    "deeds": {
        "primary_key": ["acct", "deed_id"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    "ownership_history": {
        "primary_key": ["acct", "purchase_date"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    "permits": {
        "primary_key": ["acct", "id"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    "parcel_tieback": {
        "primary_key": ["acct", "related_acct"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    "real_mnrl": {
        "primary_key": ["acct"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    "real_neighborhood_code": {
        "primary_key": ["cd"],
        "foreign_keys": [],
    },
    # ========== PERSONAL PROPERTY TABLES ==========
    "t_business_acct": {
        "primary_key": ["acct"],
        "foreign_keys": [],
        "indexes": [["sic"], ["sched_cd"]],
    },
    "t_business_detail": {
        "primary_key": ["acct", "ln_num"],
        "foreign_keys": [
            (["acct"], "t_business_acct", ["acct"]),
        ],
    },
    "t_jur_value": {
        "primary_key": ["acct", "tax_dist"],
        "foreign_keys": [
            (["acct"], "t_business_acct", ["acct"]),
        ],
    },
    "t_jur_exempt": {
        "primary_key": ["acct", "tax_dist", "exempt_cat"],
        "foreign_keys": [
            (["acct"], "t_business_acct", ["acct"]),
        ],
    },
    "t_jur_tax_dist_exempt_value_rate": {
        "primary_key": [],  # No suitable unique key
        "foreign_keys": [],
    },
    "t_pp_e": {
        "primary_key": [],  # No suitable unique key from codebook
        "foreign_keys": [],
    },
    "t_pp_l": {
        "primary_key": ["acct"],
        "foreign_keys": [
            (["acct"], "t_business_acct", ["acct"]),
        ],
    },
    # ========== HEARING/PROTEST TABLES ==========
    "arb_hearings_pp": {
        "primary_key": ["acct", "Tax_Year", "Personal"],
        "foreign_keys": [
            (["acct"], "t_business_acct", ["acct"]),
        ],
        "indexes": [["Tax_Year"]],
    },
    "arb_hearings_real": {
        "primary_key": ["acct", "Tax_Year", "Real_Personal_Property"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
        "indexes": [["Tax_Year"]],
    },
    "arb_protest_pp": {
        "primary_key": ["acct", "protested_dt"],
        "foreign_keys": [
            (["acct"], "t_business_acct", ["acct"]),
        ],
    },
    "arb_protest_real": {
        "primary_key": ["acct", "protested_dt"],
        "foreign_keys": [
            (["acct"], "real_acct", ["acct"]),
        ],
    },
    # ========== CODE DESCRIPTION TABLES (REAL PROPERTY) ==========
    "desc_r_01_state_class": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_02_building_type_code": {
        "primary_key": ["Type"],
        "foreign_keys": [],
    },
    "desc_r_03_building_style": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_04_building_class": {
        "primary_key": ["Class"],
        "foreign_keys": [],
    },
    "desc_r_05_building_data_elements": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_06_structural_element_type": {
        "primary_key": ["Type"],
        "foreign_keys": [],
    },
    "desc_r_07_quality_code": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_08_pgi_category": {
        "primary_key": ["Category"],
        "foreign_keys": [],
    },
    "desc_r_09_subarea_type": {
        "primary_key": ["Type"],
        "foreign_keys": [],
    },
    "desc_r_10_extra_features": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_11_extra_feature_category": {
        "primary_key": ["Category"],
        "foreign_keys": [],
    },
    "desc_r_12_real_jurisdictions": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_13_real_jurisdiction_type": {
        "primary_key": ["Type"],
        "foreign_keys": [],
    },
    "desc_r_14_exemption_category": {
        "primary_key": ["Category"],
        "foreign_keys": [],
    },
    "desc_r_15_land_usecode": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_16_influence_factors": {
        "primary_key": ["UseCd", "InfCd"],
        "foreign_keys": [],
    },
    "desc_r_17_relationship_type": {
        "primary_key": ["Type"],
        "foreign_keys": [],
    },
    "desc_r_18_permit_status": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_19_permit_code": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_20_school_district": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_21_market_area": {
        "primary_key": ["MktArea"],
        "foreign_keys": [],
    },
    "desc_r_22_hisd_section": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_23_special_codes": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_24_agent_roles": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_25_conclusion_code": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_r_26_neighborhood_num_adjust": {
        "primary_key": ["Neighborhood", "Class"],
        "foreign_keys": [],
    },
    # ========== CODE DESCRIPTION TABLES (PERSONAL PROPERTY) ==========
    "desc_t_01_state_class": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_t_02_schedule_code": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_t_03_sic_code": {
        "primary_key": ["Type"],
        "foreign_keys": [],
    },
    "desc_t_04_department_group": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_t_05_jurisdictions": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
    "desc_t_06_jurisdiction_type": {
        "primary_key": ["Code"],
        "foreign_keys": [],
    },
}


def get_primary_key(table_name):
    """Return the primary key columns for a table, or empty list if none."""
    return SCHEMA_MAP.get(table_name, {}).get("primary_key", [])


def get_foreign_keys(table_name):
    """Return the foreign key definitions for a table."""
    return SCHEMA_MAP.get(table_name, {}).get("foreign_keys", [])


def get_indexes(table_name):
    """Return the index definitions for a table."""
    return SCHEMA_MAP.get(table_name, {}).get("indexes", [])
