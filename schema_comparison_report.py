"""
Comparison report: Old vs New schema_config.py

This report shows the differences between the conceptual schema (old)
and the actual source file columns (new) for key tables.
"""

# Key findings from verify_schema_columns.py:

CRITICAL_FIXES = {
    # CORE ANALYTICAL TABLES (HIGH PRIORITY)
    "jur_value": {
        "old_pk": ["acct", "jur_cd"],
        "new_pk": ["acct", "tax_district"],
        "impact": "14M+ rows - tax jurisdiction values",
        "fix": "Replace 'jur_cd' with 'tax_district'",
    },
    "jur_exempt": {
        "old_pk": ["acct", "jur_cd", "exempt_cd"],
        "new_pk": ["acct", "tax_district", "exempt_cat"],
        "impact": "14M+ rows - tax exemptions",
        "fix": "Replace 'jur_cd' with 'tax_district', 'exempt_cd' with 'exempt_cat'",
    },
    "land": {
        "old_pk": ["acct", "land_seq"],
        "new_pk": ["acct", "num"],
        "impact": "Land parcels",
        "fix": "Replace 'land_seq' with 'num'",
    },
    "land_ag": {
        "old_pk": ["acct", "land_seq"],
        "new_pk": ["acct", "num"],
        "impact": "Agricultural land",
        "fix": "Replace 'land_seq' with 'num'",
    },
    "owners": {
        "old_pk": ["acct", "own_seq"],
        "new_pk": ["acct", "ln_num"],
        "impact": "Property ownership",
        "fix": "Replace 'own_seq' with 'ln_num'",
    },
    "deeds": {
        "old_pk": ["acct", "deed_num"],
        "new_pk": ["acct", "deed_id"],
        "impact": "Deed records",
        "fix": "Replace 'deed_num' with 'deed_id'",
    },
    "ownership_history": {
        "old_pk": ["acct", "deed_num"],
        "new_pk": ["acct"],
        "impact": "Ownership history - PK is just acct (no deed_num column)",
        "fix": "Change PK to just ['acct']",
    },
    # BUILDING DETAIL TABLES
    "fixtures": {
        "old_pk": ["acct", "bld_num", "fixture_type"],
        "new_pk": ["acct", "bld_num", "type"],
        "impact": "Building fixtures",
        "fix": "Replace 'fixture_type' with 'type'",
    },
    "exterior": {
        "old_pk": ["acct", "bld_num", "subarea_type", "subarea_seq"],
        "new_pk": ["acct", "bld_num", "sar_cd", "area"],
        "impact": "Building exterior (subarea)",
        "fix": "Replace 'subarea_type' with 'sar_cd', 'subarea_seq' with 'area'",
    },
    "structural_elem1": {
        "old_pk": ["acct", "bld_num", "struct_elem"],
        "new_pk": ["acct", "bld_num", "code"],
        "impact": "8.7M rows - structural elements",
        "fix": "Replace 'struct_elem' with 'code'",
    },
    "structural_elem2": {
        "old_pk": ["acct", "bld_num", "struct_elem"],
        "new_pk": ["acct", "bld_num", "code"],
        "impact": "Structural elements (secondary)",
        "fix": "Replace 'struct_elem' with 'code'",
    },
    "extra_features": {
        "old_pk": ["acct", "xf_num"],
        "new_pk": ["acct"],  # No xf_num in file, just acct
        "impact": "Extra features - no xf_num column",
        "fix": "Change PK to just ['acct'] or add more columns",
    },
    # PERSONAL PROPERTY TABLES
    "t_jur_value": {
        "old_pk": ["acct", "jur_cd"],
        "new_pk": ["acct", "tax_dist"],
        "impact": "Personal property tax values",
        "fix": "Replace 'jur_cd' with 'tax_dist'",
    },
    "t_jur_exempt": {
        "old_pk": ["acct", "jur_cd", "exempt_cd"],
        "new_pk": ["acct", "tax_dist", "exempt_cat"],
        "impact": "Personal property exemptions",
        "fix": "Replace 'jur_cd' with 'tax_dist', 'exempt_cd' with 'exempt_cat'",
    },
    "t_business_detail": {
        "old_pk": ["acct", "line_num"],
        "new_pk": ["acct", "ln_num"],
        "impact": "Business detail lines",
        "fix": "Replace 'line_num' with 'ln_num'",
    },
    # HEARING/PROTEST TABLES
    "arb_hearings_real": {
        "old_pk": ["acct", "Tax_Year", "Hearing_Num"],
        "new_pk": ["acct", "Tax_Year"],  # No Hearing_Num in file
        "impact": "ARB hearings - no Hearing_Num column",
        "fix": "Change PK to ['acct', 'Tax_Year'] or find unique combination",
    },
    "arb_protest_real": {
        "old_pk": ["acct", "Tax_Year", "protest_id"],
        "new_pk": ["acct"],  # No Tax_Year or protest_id
        "impact": "Protests - no Tax_Year/protest_id columns",
        "fix": "Change PK to just ['acct']",
    },
    "arb_protest_pp": {
        "old_pk": ["acct", "Tax_Year"],
        "new_pk": ["acct"],  # No Tax_Year column
        "impact": "PP protests - no Tax_Year column",
        "fix": "Change PK to just ['acct']",
    },
    # LOOKUP TABLES (ALL NEED FIXES)
    "desc_r_01_state_class": {
        "old_pk": ["state_class"],
        "new_pk": ["Code"],
        "fix": "Column is named 'Code' not 'state_class'",
    },
    "desc_r_12_real_jurisdictions": {
        "old_pk": ["jur_cd"],
        "new_pk": ["Code"],
        "fix": "Column is named 'Code' not 'jur_cd'",
    },
    # ... (ALL desc_* tables have similar issues - using conceptual names vs actual 'Code', 'Type', 'Category', etc.)
}

# Summary statistics:
print("=" * 80)
print("SCHEMA MISMATCH REPORT")
print("=" * 80)
print()
print(f"Total tables with mismatches: 57 out of 67")
print(f"Tables loading correctly: 10")
print()
print("ROOT CAUSE:")
print("  - Original schema used conceptual/normalized column names")
print("  - Actual HCAD files use abbreviated column names")
print("  - Example: 'jur_cd' (concept) vs 'tax_district' (actual)")
print()
print("IMPACT:")
print("  - 57 tables have 0 rows loaded (all rows skipped by PK NULL check)")
print("  - Only 10 tables loaded: real_acct, t_business_acct, building_res,")
print("    building_other, permits, arb_hearings_pp, real_mnrl, t_pp_l")
print()
print("SOLUTION OPTIONS:")
print()
print("1. COMPREHENSIVE FIX (Recommended)")
print("   - Manually create corrected schema_config.py with actual column names")
print("   - Based on actual file headers from extracted/ files")
print("   - Estimated time: 30-45 minutes for all 67 tables")
print("   - Result: Complete, accurate schema for all tables")
print()
print("2. TARGETED FIX (Quick)")
print("   - Fix only the 10-15 most important analytical tables")
print("   - jur_value, jur_exempt, land, owners, deeds, structural_elem1")
print("   - Estimated time: 10 minutes")
print("   - Result: Core queries work, some tables still at 0 rows")
print()
print("3. HYBRID APPROACH (Pragmatic)")
print("   - Auto-generate from file headers (not codebook)")
print("   - Manually verify/fix PKs for complex tables")
print("   - Estimated time: 20 minutes")
print("   - Result: Good coverage with high confidence")
print()
print("=" * 80)
print()

# Print detailed fixes for top 10 tables
print("TOP 10 CRITICAL FIXES:")
print("-" * 80)
priority_tables = [
    "jur_value",
    "jur_exempt",
    "land",
    "owners",
    "deeds",
    "structural_elem1",
    "fixtures",
    "t_jur_value",
    "t_jur_exempt",
    "exterior",
]

for table in priority_tables:
    if table in CRITICAL_FIXES:
        fix = CRITICAL_FIXES[table]
        print(f"\n{table}:")
        print(f"  Old PK: {fix['old_pk']}")
        print(f"  New PK: {fix['new_pk']}")
        print(f"  Fix: {fix['fix']}")
        if "impact" in fix:
            print(f"  Impact: {fix['impact']}")
