"""
Verify that schema_config.py column names match actual source file headers.
"""

import os
from pathlib import Path
import schema_config


def get_file_header(file_path):
    """Read the first line of a file and return column names."""
    try:
        with open(file_path, "r", encoding="utf-8", errors="replace") as f:
            header = f.readline().strip()
            return header.split("\t")
    except Exception as e:
        return None


def find_data_file(indir, table_name):
    """Find the data file for a given table name."""
    search_dirs = [
        indir,
        os.path.join(indir, "pdata"),
        os.path.join(indir, "pdata", "Code_description_real"),
        os.path.join(indir, "pdata", "Code_description_pp"),
        os.path.join(indir, "pdata", "Hearing_files"),
        os.path.join(indir, "Real_acct_owner"),
        os.path.join(indir, "Real_acct_ownership_history"),
        os.path.join(indir, "Real_building_land"),
        os.path.join(indir, "Real_jur_exempt"),
        os.path.join(indir, "PP_files"),
    ]

    for search_dir in search_dirs:
        if not os.path.exists(search_dir):
            continue
        for root, dirs, files in os.walk(search_dir):
            for file in files:
                if file.lower() == f"{table_name}.txt":
                    return os.path.join(root, file)
    return None


def main():
    indir = "extracted"

    # Get all tables from schema_config
    tables = schema_config.SCHEMA_MAP.keys()

    mismatches = []

    for table_name in tables:
        pk_cols = schema_config.get_primary_key(table_name)
        if not pk_cols:
            continue  # skip tables without PKs

        # Find the source file
        file_path = find_data_file(indir, table_name)
        if not file_path:
            print(f"WARNING: No file found for table '{table_name}'")
            continue

        # Get the header columns
        header_cols = get_file_header(file_path)
        if not header_cols:
            print(f"WARNING: Could not read header from '{file_path}'")
            continue

        # Check if all PK columns exist in the header
        missing_cols = [col for col in pk_cols if col not in header_cols]
        if missing_cols:
            mismatches.append(
                {
                    "table": table_name,
                    "missing_pk_cols": missing_cols,
                    "actual_header": header_cols,
                    "expected_pk": pk_cols,
                    "file": file_path,
                }
            )

    if mismatches:
        print(f"\nFound {len(mismatches)} tables with PK column name mismatches:\n")
        for mismatch in mismatches:
            print(f"Table: {mismatch['table']}")
            print(f"  Missing PK columns: {mismatch['missing_pk_cols']}")
            print(f"  Expected PK: {mismatch['expected_pk']}")
            print(f"  Actual header: {mismatch['actual_header']}")
            print(f"  File: {mismatch['file']}")
            print()
    else:
        print(
            "\nNo PK column mismatches found! All schema_config PKs match source file headers."
        )


if __name__ == "__main__":
    main()
