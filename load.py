"""Dynamic loader for HCAD extracted text files into a relational database.

This script builds table schemas based on the codebook CSVs found under
`database_info/codebook_tables/`. Each CSV describes the columns for a table.

Rules implemented:
 - Table name derived from CSV filename, stripping the `_columns.csv` suffix.
 - Data file expected at `<any subdir>/<table_name>.txt` within the extraction root.
 - Columns with `Allow Null` == 'NO' are treated as part of a composite PRIMARY KEY.
 - Data types are mapped from the `Data Type` + `Size` columns (varchar/char -> String(length)).
 - All values loaded as strings for now to avoid premature type assumptions.
 - Tab-delimited `.txt` input files (header row present) are streamed and batch inserted.

CLI Usage Example:
        python load.py --indir extracted --db-uri postgresql://postgres:postgres@localhost:5432/hcad

Environment fallback:
        If --db-uri not provided, uses DATABASE_URL from `.env`.

Future enhancements (notes):
 - Type inference for numeric columns.
 - Parallel loading via multiprocessing (workers argument currently unused placeholder).
 - Progress reporting / retry strategy.
 - Optional truncation or upsert strategies.
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Sequence

from sqlalchemy import (
    MetaData,
    Table,
    Column as SAColumn,
    String,
    Integer,
    Text,
    create_engine,
    text,
    ForeignKey,
    Index,
)
from sqlalchemy.exc import IntegrityError, DataError

import schema_config

CODEBOOK_DIR_DEFAULT = Path("database_info/codebook_tables")


@dataclass
class ColumnDef:
    name: str
    data_type: str
    size: int | None
    allow_null: bool
    description: str | None = None


def _log(msg: str) -> None:
    print(f"[load] {msg}")


def parse_codebook_csv(path: Path) -> List[ColumnDef]:
    cols: List[ColumnDef] = []
    seen: set[str] = set()
    with path.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row.get("Column Name") or row.get("Column") or row.get("name")
            if not name:
                continue
            dt = (row.get("Data Type") or "varchar").strip().lower()
            size_raw = (row.get("Size") or "").strip()
            size = None
            if size_raw.isdigit():
                size = int(size_raw)
            allow_null_flag = (row.get("Allow Null") or "").strip().upper() != "NO"
            desc = row.get("Description")
            clean_name = name.strip()
            # Skip obvious commentary or duplicate lines
            if clean_name in seen:
                continue
            if clean_name.lower().startswith("all records"):
                continue
            seen.add(clean_name)
            cols.append(
                ColumnDef(
                    name=clean_name,
                    data_type=dt,
                    size=size,
                    allow_null=allow_null_flag,
                    description=desc,
                )
            )
    return cols


def build_table(
    metadata: MetaData, table_name: str, column_defs: Sequence[ColumnDef]
) -> Table:
    """Build a SQLAlchemy Table with proper primary keys, foreign keys, and indexes per schema_config."""
    sqlalchemy_columns: List[SAColumn] = []

    # Get schema metadata for this table
    pk_cols = schema_config.get_primary_key(table_name)
    fk_defs = schema_config.get_foreign_keys(table_name)
    index_defs = schema_config.get_indexes(table_name)

    # Build columns
    for col in column_defs:
        # Map data types; all stored as String for now.
        length = col.size if col.size and col.size > 0 else None
        if length:
            sa_type = String(length)
        else:
            sa_type = String()  # unbounded

        # Determine if this column is part of the primary key
        is_pk = col.name in pk_cols
        # PK columns are non-nullable; others are nullable to handle data quality
        nullable = not is_pk

        # Build the column; add ForeignKey if applicable
        fk_constraint = None
        for local_cols, ref_table, ref_cols in fk_defs:
            if col.name in local_cols:
                # Single-column FK (multi-column FKs handled at table level)
                if len(local_cols) == 1 and len(ref_cols) == 1:
                    fk_constraint = ForeignKey(f"{ref_table}.{ref_cols[0]}")
                break

        if fk_constraint:
            sqlalchemy_columns.append(
                SAColumn(
                    col.name,
                    sa_type,
                    fk_constraint,
                    nullable=nullable,
                    primary_key=is_pk,
                )
            )
        else:
            sqlalchemy_columns.append(
                SAColumn(col.name, sa_type, nullable=nullable, primary_key=is_pk)
            )

    # If no PK columns are defined in schema, add a surrogate row_id
    if not pk_cols:
        _log(
            f"Warning: {table_name} has no PK in schema_config; adding surrogate row_id."
        )
        sqlalchemy_columns.insert(
            0, SAColumn("row_id", Integer, primary_key=True, autoincrement=True)
        )

    # Create the table
    table = Table(table_name, metadata, *sqlalchemy_columns)

    # Add indexes
    for idx_cols in index_defs:
        # Create index name from table and columns
        idx_name = f"ix_{table_name}_{'_'.join(idx_cols)}"
        Index(idx_name, *[table.c[col] for col in idx_cols if col in table.c])

    return table


def discover_codebook_tables(codebook_dir: Path) -> Dict[str, List[ColumnDef]]:
    mapping: Dict[str, List[ColumnDef]] = {}
    for csv_file in sorted(codebook_dir.glob("*_columns.csv")):
        table_name = csv_file.name.replace("_columns.csv", "")
        try:
            mapping[table_name] = parse_codebook_csv(csv_file)
        except Exception as e:  # pragma: no cover - defensive
            _log(f"Failed parsing {csv_file}: {e}")
    return mapping


def find_data_files(indir: Path) -> Dict[str, Path]:
    data_files: Dict[str, Path] = {}
    for root, _dirs, files in os.walk(indir):
        for fn in files:
            if fn.endswith(".txt"):
                base = fn[:-4]  # strip .txt
                data_files[base] = Path(root) / fn
    return data_files


def load_table(engine, table: Table, file_path: Path, batch_size: int = 500) -> int:
    inserted = 0
    # open with replace to avoid decoding failures, but explicitly strip NUL bytes below
    with file_path.open("r", encoding="utf-8", errors="replace") as f:
        header_line = f.readline().rstrip("\n")
        header = header_line.split("\t")
        # Ensure columns exist in table
        valid_cols = [c.name for c in table.columns]
        # Determine which header columns we will map (in-order)
        expected_cols = [h for h in header if h in valid_cols]
        missing = [h for h in header if h not in valid_cols]
        if missing:
            _log(
                f"Warning: {table.name}: {len(missing)} header columns not in schema: {missing[:5]}{'...' if len(missing)>5 else ''}"
            )
        rows_batch: List[Dict[str, str | None]] = []
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            # Start with all expected columns set to None so every row includes the same keys
            row_map: Dict[str, str | None] = {col: None for col in expected_cols}
            for col_name, value in zip(header, parts):
                if col_name in expected_cols:
                    # strip surrounding whitespace
                    value = value.strip()
                    # remove embedded NUL characters which will break PostgreSQL string literals
                    if value is not None:
                        value = value.replace("\x00", "")
                    # empty strings represent NULLs in the source
                    if value == "":
                        value = None  # preserve NULLs
                    # store the cleaned value (may be None)
                    row_map[col_name] = value
            # Skip rows where any primary key column is NULL (data quality issue)
            pk_cols = schema_config.get_primary_key(table.name)
            if pk_cols and any(row_map.get(pk_col) is None for pk_col in pk_cols):
                continue  # skip this row silently
            if row_map:
                rows_batch.append(row_map)
            if len(rows_batch) >= batch_size:
                inserted += _flush_batch(engine, table, rows_batch)
                rows_batch.clear()
        if rows_batch:
            inserted += _flush_batch(engine, table, rows_batch)
    return inserted


def _flush_batch(engine, table: Table, rows: List[Dict[str, str | None]]) -> int:
    """Insert a batch of rows into the table. Use INSERT...ON CONFLICT for tables with PKs to skip duplicates."""
    if not rows:
        return 0
    # Try a single batch insert; if we hit string truncation, convert string columns to TEXT and retry once.
    # For PostgreSQL tables with PKs, use INSERT...ON CONFLICT DO NOTHING to skip duplicate primary keys
    has_pk = any(col.primary_key for col in table.columns)

    try:
        with engine.begin() as conn:
            if has_pk and "postgresql" in str(engine.url):
                # Build INSERT ... ON CONFLICT DO NOTHING for PostgreSQL
                # Get list of all column names (excluding auto-increment surrogate keys with server_default)
                cols_to_insert = [
                    col.name
                    for col in table.columns
                    if not (col.primary_key and col.autoincrement)
                ]
                if not cols_to_insert:
                    cols_to_insert = [col.name for col in table.columns]

                # Use SQLAlchemy insert with ON CONFLICT clause
                from sqlalchemy.dialects.postgresql import insert as pg_insert

                stmt = pg_insert(table).on_conflict_do_nothing()
                conn.execute(stmt, rows)
            else:
                conn.execute(table.insert(), rows)
        return len(rows)
    except IntegrityError as e:
        # Handle FK violations by inserting rows one at a time, skipping orphans
        from psycopg2.errors import ForeignKeyViolation

        err_msg = str(e)
        if "ForeignKeyViolation" in err_msg or "foreign key constraint" in err_msg:
            _log(
                f"FK violation in {table.name}: inserting rows individually to skip orphans."
            )
            inserted_count = 0
            # Insert each row in its own transaction to isolate FK failures
            for row in rows:
                try:
                    with engine.begin() as conn:
                        if has_pk and "postgresql" in str(engine.url):
                            from sqlalchemy.dialects.postgresql import (
                                insert as pg_insert,
                            )

                            stmt = pg_insert(table).on_conflict_do_nothing()
                            conn.execute(stmt, [row])
                        else:
                            conn.execute(table.insert(), [row])
                    inserted_count += 1
                except IntegrityError:
                    # Skip this row - it references a non-existent parent or has other integrity issue
                    pass
            return inserted_count
        # Not a FK violation we can handle; re-raise
        raise
    except DataError as e:
        # Detect truncation errors (psycopg2.errors.StringDataRightTruncation)
        err_msg = str(e)
        if (
            "StringDataRightTruncation" in err_msg
            or "value too long for type" in err_msg
        ):
            _log(
                f"String truncation inserting into {table.name}: upgrading string columns to TEXT and retrying batch."
            )
            _expand_string_columns_to_text(engine, table)
            # Retry once
            with engine.begin() as conn:
                if has_pk and "postgresql" in str(engine.url):
                    from sqlalchemy.dialects.postgresql import insert as pg_insert

                    stmt = pg_insert(table).on_conflict_do_nothing()
                    conn.execute(stmt, rows)
                else:
                    conn.execute(table.insert(), rows)
            return len(rows)
        # Not a truncation we can handle here; re-raise
        raise


def _expand_string_columns_to_text(engine, table: Table) -> None:
    """ALTER TABLE to change String columns to TEXT so long values will fit.
    This is a best-effort operation executed when we encounter truncation errors.
    """
    alter_stmts = []
    for col in table.columns:
        # skip surrogate PK
        if col.primary_key:
            continue
        col_type = col.type
        # Use isinstance check against String
        try:
            is_string = isinstance(col_type, String)
        except Exception:
            is_string = False
        if is_string:
            # Build an ALTER COLUMN statement
            alter_stmts.append(f'ALTER COLUMN "{col.name}" TYPE TEXT')
    if not alter_stmts:
        _log(f"No string columns to alter for {table.name}.")
        return
    stmt = f'ALTER TABLE "{table.name}" ' + ", ".join(alter_stmts)
    with engine.begin() as conn:
        conn.execute(text(stmt))
    _log(f"Upgraded string columns to TEXT for {table.name}.")


def _topological_sort_tables(table_names: List[str]) -> List[str]:
    """Sort tables so that foreign key parent tables are loaded before child tables.
    Uses schema_config to determine dependencies.
    """
    from collections import defaultdict, deque

    # Build dependency graph
    in_degree = {name: 0 for name in table_names}
    graph = defaultdict(list)  # parent -> [children]

    for table_name in table_names:
        fk_defs = schema_config.get_foreign_keys(table_name)
        for _local_cols, ref_table, _ref_cols in fk_defs:
            if ref_table in table_names and ref_table != table_name:
                # table_name depends on ref_table
                graph[ref_table].append(table_name)
                in_degree[table_name] += 1

    # Kahn's algorithm for topological sort
    queue = deque([name for name in table_names if in_degree[name] == 0])
    sorted_tables = []

    while queue:
        current = queue.popleft()
        sorted_tables.append(current)

        for child in graph[current]:
            in_degree[child] -= 1
            if in_degree[child] == 0:
                queue.append(child)

    # If there are cycles or unresolved dependencies, append remaining tables
    for name in table_names:
        if name not in sorted_tables:
            sorted_tables.append(name)

    return sorted_tables


def load_data(
    indir: str = "extracted",
    db_uri: str | None = None,
    workers: int = 1,
    codebook_dir: str | Path = CODEBOOK_DIR_DEFAULT,
) -> None:
    """High-level API to load all known tables from an extracted directory.

    Parameters
    ----------
    indir : str
            Root directory containing extracted .txt data files.
    db_uri : str | None
            SQLAlchemy database URI. If None, read from environment variable DATABASE_URL.
    workers : int
            Placeholder for future parallelization (currently unused).
    codebook_dir : str | Path
            Directory containing *_columns.csv codebook files.
    """
    root = Path(indir)
    if not root.exists():
        raise FileNotFoundError(f"Input directory does not exist: {root}")
    db_uri = db_uri or os.getenv("DATABASE_URL")
    if not db_uri:
        # Attempt to parse a local .env file manually (simple KEY=VALUE lines)
        env_path = Path(".env")
        if env_path.exists():
            for line in env_path.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    k = k.strip()
                    v = v.strip()
                    if k == "DATABASE_URL" and v:
                        db_uri = v
                        break
        if not db_uri:
            raise ValueError(
                "Database URI not provided and DATABASE_URL not set in environment or .env file."
            )
    engine = create_engine(db_uri, future=True)
    metadata = MetaData()

    codebook_dir_path = Path(codebook_dir)
    table_defs = discover_codebook_tables(codebook_dir_path)
    if not table_defs:
        raise RuntimeError(f"No codebook tables discovered under {codebook_dir_path}")
    tables: Dict[str, Table] = {}
    for name, cols in table_defs.items():
        tables[name] = build_table(metadata, name, cols)

    _log("Dropping and recreating tables...")
    metadata.drop_all(engine)
    metadata.create_all(engine)

    data_files = find_data_files(root)
    matched = set(data_files.keys()) & set(tables.keys())
    _log(
        f"Discovered {len(data_files)} data files; {len(matched)} match codebook tables."
    )

    # Sort tables by dependency order (FK parents before children)
    sorted_table_names = _topological_sort_tables(list(matched))

    for tbl_name in sorted_table_names:
        tbl = tables[tbl_name]
        fpath = data_files[tbl_name]
        _log(f"Loading {tbl_name} from {fpath} ...")
        try:
            count = load_table(engine, tbl, fpath)
            _log(f"Loaded {count} rows into {tbl_name}.")
        except Exception as e:
            _log(f"Error loading {tbl_name}: {e}")

    _log("Load process complete.")


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Load HCAD extracted data into a database.")
    p.add_argument(
        "--indir", default="extracted", help="Directory with extracted .txt files."
    )
    p.add_argument(
        "--db-uri",
        dest="db_uri",
        default=None,
        help="Database URI (overrides DATABASE_URL env)",
    )
    p.add_argument(
        "--codebook-dir",
        dest="codebook_dir",
        default=str(CODEBOOK_DIR_DEFAULT),
        help="Directory containing *_columns.csv definitions.",
    )
    p.add_argument(
        "--workers", type=int, default=1, help="Future parallel workers (unused)."
    )
    return p.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> None:
    args = _parse_args(argv or sys.argv[1:])
    load_data(
        indir=args.indir,
        db_uri=args.db_uri,
        workers=args.workers,
        codebook_dir=args.codebook_dir,
    )


if __name__ == "__main__":  # pragma: no cover
    main()
