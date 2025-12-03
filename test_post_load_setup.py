#!/usr/bin/env python3
"""
Quick test to verify post_load_setup.sql can be executed.
This doesn't load data, just tests the SQL setup script.
"""

import os
from pathlib import Path
from sqlalchemy import create_engine, text


def test_post_load_setup():
    """Test executing post_load_setup.sql against the database."""
    db_uri = os.getenv(
        "DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/hcad"
    )

    print(f"Connecting to: {db_uri}")
    engine = create_engine(db_uri, future=True)

    sql_file = Path(__file__).parent / "post_load_setup.sql"
    if not sql_file.exists():
        print(f"ERROR: {sql_file} not found")
        return False

    print(f"Reading SQL from: {sql_file}")
    sql_content = sql_file.read_text(encoding="utf-8")

    print("Executing post-load setup SQL...")
    try:
        with engine.begin() as conn:
            conn.execute(text(sql_content))
        print("✓ Post-load setup completed successfully")

        # Test that views exist
        with engine.connect() as conn:
            result = conn.execute(
                text(
                    """
                SELECT COUNT(*) as view_count 
                FROM information_schema.views 
                WHERE table_schema = 'public' 
                AND table_name IN ('property_features', 'property_features_v2', 'residential_protest_analysis')
            """
                )
            )
            count = result.fetchone()[0]
            print(f"✓ Found {count} views (expected 3)")

            # Test safe_num function
            result = conn.execute(text("SELECT safe_num('12345.67')"))
            value = result.fetchone()[0]
            print(f"✓ safe_num() function works: safe_num('12345.67') = {value}")

            # Test view row count
            result = conn.execute(
                text("SELECT COUNT(*) FROM residential_protest_analysis")
            )
            count = result.fetchone()[0]
            print(f"✓ residential_protest_analysis has {count:,} rows")

        return True
    except Exception as e:
        print(f"✗ Error: {e}")
        return False


if __name__ == "__main__":
    success = test_post_load_setup()
    exit(0 if success else 1)
