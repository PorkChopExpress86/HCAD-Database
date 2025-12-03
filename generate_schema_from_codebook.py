"""
Generate schema_config.py by reading the actual codebook CSV files.
"""

import os
import csv
from collections import defaultdict


def read_codebook_csv(csv_path):
    """Read a codebook CSV and extract column information."""
    columns = []
    pk_cols = []

    try:
        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                col_name = row.get("Column Name", "").strip()
                allow_null = row.get("Allow Null", "YES").strip().upper()

                if col_name:
                    columns.append(col_name)
                    # If Allow Null is NO, it's likely a PK column
                    if allow_null == "NO":
                        pk_cols.append(col_name)
    except Exception as e:
        print(f"Error reading {csv_path}: {e}")
        return None, None

    return columns, pk_cols


def find_foreign_keys(table_name, columns, all_tables):
    """Infer foreign keys based on column names and table relationships."""
    foreign_keys = []

    # Common FK patterns
    if "acct" in columns:
        if table_name not in ["real_acct", "t_business_acct"]:
            # Most tables with 'acct' reference real_acct
            if table_name.startswith("t_"):
                # Personal property tables reference t_business_acct
                foreign_keys.append((["acct"], "t_business_acct", ["acct"]))
            else:
                # Real property tables reference real_acct
                foreign_keys.append((["acct"], "real_acct", ["acct"]))

    # Building tables reference their parent
    if "bld_num" in columns and table_name not in ["building_res", "building_other"]:
        if "acct" in columns:
            # Determine which building table (res or other) - assume res for now
            foreign_keys.append(
                (["acct", "bld_num"], "building_res", ["acct", "bld_num"])
            )

    return foreign_keys


def suggest_indexes(table_name, columns, pk_cols):
    """Suggest useful indexes based on common query patterns."""
    indexes = []

    # Common index patterns
    index_candidates = [
        "tax_district",
        "tax_dist",
        "neighborhood_code",
        "neighborhood",
        "school_dist",
        "school_district",
        "state_class",
        "yr_blt",
        "tot_use_cd",
        "exempt_cat",
        "exempt_cd",
        "sic",
        "sched_cd",
        "Tax_Year",
        "tax_year",
    ]

    for col in columns:
        if col in index_candidates and col not in pk_cols:
            indexes.append([col])

    return indexes


def main():
    codebook_dir = "database_info/codebook_tables"

    if not os.path.exists(codebook_dir):
        print(f"Error: {codebook_dir} not found")
        return

    schema_map = {}

    # Read all codebook CSVs
    for filename in sorted(os.listdir(codebook_dir)):
        if not filename.endswith("_columns.csv"):
            continue

        # Extract table name from filename
        table_name = filename.replace("_columns.csv", "")
        csv_path = os.path.join(codebook_dir, filename)

        columns, pk_cols = read_codebook_csv(csv_path)

        if columns is None:
            continue

        # Infer foreign keys
        foreign_keys = find_foreign_keys(table_name, columns, schema_map.keys())

        # Suggest indexes
        indexes = suggest_indexes(table_name, columns, pk_cols)

        schema_map[table_name] = {
            "primary_key": pk_cols,
            "foreign_keys": foreign_keys,
            "indexes": indexes,
        }

        print(f"Processed {table_name}: {len(columns)} columns, PK={pk_cols}")

    # Write the new schema_config.py
    output_file = "schema_config_generated.py"
    with open(output_file, "w", encoding="utf-8") as f:
        f.write('"""\n')
        f.write("Auto-generated schema configuration from codebook CSV files.\n")
        f.write(
            "Maps HCAD table names to their primary keys, foreign keys, and indexes.\n"
        )
        f.write('"""\n\n')

        f.write("SCHEMA_MAP = {\n")

        for table_name in sorted(schema_map.keys()):
            config = schema_map[table_name]
            f.write(f'    "{table_name}": {{\n')
            f.write(f'        "primary_key": {config["primary_key"]},\n')
            f.write(f'        "foreign_keys": [\n')
            for fk in config["foreign_keys"]:
                f.write(f'            ({fk[0]}, "{fk[1]}", {fk[2]}),\n')
            f.write(f"        ],\n")
            if config["indexes"]:
                f.write(f'        "indexes": {config["indexes"]},\n')
            f.write(f"    }},\n")

        f.write("}\n\n")

        # Add helper functions
        f.write(
            '''
def get_primary_key(table_name):
    """Return the primary key columns for a table, or empty list if none."""
    return SCHEMA_MAP.get(table_name, {}).get("primary_key", [])

def get_foreign_keys(table_name):
    """Return the foreign key definitions for a table."""
    return SCHEMA_MAP.get(table_name, {}).get("foreign_keys", [])

def get_indexes(table_name):
    """Return the index definitions for a table."""
    return SCHEMA_MAP.get(table_name, {}).get("indexes", [])
'''
        )

    print(f"\nGenerated {output_file}")
    print(f"Total tables: {len(schema_map)}")


if __name__ == "__main__":
    main()
