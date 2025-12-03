# Copilot instructions for this repository

This file gives concise, repository-specific guidance for AI coding agents (Copilot/assistant) to be immediately productive.

Key entrypoints
- `download.py` — CLI and importable API. Use `download_year(year, outdir, workers, filenames=None, dry_run=False)` to programmatically build/download the canonical HCAD CAMA ZIP files. The CLI flags `--use-named-list --year` will build URLs like `https://download.hcad.org/data/CAMA/{year}/{fname}` using the built-in `DEFAULT_FILENAMES` list.
- `main.py` — example entrypoint that calls `download.download_year`. Useful to run end-to-end from CLI: `python main.py --year 2025 --outdir downloads/2025`.
- `extract.py` — CLI and API for unpacking zips. Use `extract_all(indir='downloads', outdir='extracted', pattern=None, workers=1, manifest=None)` to extract archives. It implements Zip-Slip protection and can produce a JSON manifest in `extracted/`.
- `load.py` — CLI and API for loading data into a database. Use `load_data(indir='extracted', db_uri, workers=1)` to load extracted data into the specified database. It supports various database backends and handles data validation and transformation during the load process.

Loading data (step 3)
- Purpose: load extracted files into a database for analysis and downstream ETL.
- Programmatic API: `load.load_data(indir='extracted', db_uri, workers=1)`. `db_uri` should be an SQLAlchemy-compatible database URI. Example URIs:
  - SQLite (local file): `sqlite:///./data/hcad.db`
  - PostgreSQL: `postgresql://user:password@localhost:5432/hcad`
- CLI (example, PowerShell):
  - `& ".venv/Scripts/python.exe" load.py --indir extracted --db-uri "sqlite:///./data/hcad.db" --workers 4`
- Environment and credentials: we recommend placing database credentials in a `.env` file as `DATABASE_URL`. Example `.env` placeholder:
  - `DATABASE_URL=""`
  - The repository can create a `.env` with a `DATABASE_URL` placeholder if one does not already exist; fill it with a real URI before running the loader.
- Validation / acceptance criteria:
  - The loader completes without unhandled exceptions.
  - Key tables (for example `real_acct`, `t_pp_c`, `t_jur_value`) have non-zero row counts after load.
  - A small set of sample queries return expected columns and value shapes.
- Notes & tips:
  - For large datasets prefer a server-backed DB (Postgres, MySQL) over SQLite for performance and concurrent writes.
  - Monitor memory and I/O when running with multiple workers; adjust `--workers` to fit your machine.
  - If you need a dry-run mode or additional validation steps, consider adding flags to `load.py` or wrapping `load.load_data` in a small validation script.

Project structure & data flow
- Raw ZIPs are stored in `downloads/` (the downloader writes there). Extraction outputs go to `extracted/<zip_basename>/`.
- Typical workflow: run `download.py` (or `main.py`) to fetch zips → run `extract.py` to unpack → downstream processing (not included in this repo).

Conventions & patterns
- URL template: `https://download.hcad.org/data/CAMA/{year}/{fname}`. `download.build_urls_for_year` and `DEFAULT_FILENAMES` centralize filenames.
- Safe extraction: `extract.safe_extract` prevents path traversal — do not remove or weaken this without explicit justification and tests.
- Config & formatting: Black is configured via `pyproject.toml`. A `.pre-commit-config.yaml` is present to run Black on commit. Use the repository virtualenv (`.venv`) when running commands in CI or locally.

Developer workflows (commands)
- Install deps into workspace venv:
  - `pip install -r requirements.txt` or `& ".venv/Scripts/python.exe" -m pip install -r requirements.txt`
- Run downloader (dry-run):
  - `& ".venv/Scripts/python.exe" download.py --use-named-list --year 2025 --dry-run`
- Download actual files:
  - `& ".venv/Scripts/python.exe" download.py --use-named-list --year 2025`
- Extract zips and write manifest:
  - `& ".venv/Scripts/python.exe" extract.py --workers 4 --manifest extracted`
- Format code with Black:
  - `& ".venv/Scripts/python.exe" -m black .`

Important APIs and symbols to know
- `download.download_year(year, outdir='downloads', workers=4, filenames=None, base=..., dry_run=False)` — top-level helper used by `main.py`.
- `download.build_urls_for_year(year, filenames, base=...)` — constructs canonical download URLs.
- `extract.extract_all(indir='downloads', outdir='extracted', pattern=None, workers=1, manifest=None)` — parallel-safe extraction and manifest writer.

Testing & validation
- There are no unit tests in the repo. For validation, run the CLI in `--dry-run` or run the small import checks used during development (e.g., import `download` and call `download_year(..., dry_run=True)`). After formatting changes run Black and a quick dry-run of the scripts.

Integration points & external services
- HCAD download host: `https://download.hcad.org/` (CAMA data). The downloader expects the site to host ZIPs under the `data/CAMA/{year}/` path.

Agent guidance (what to change and how)
- To add/remove dataset files: update `DEFAULT_FILENAMES` in `download.py` or pass a `filenames` list to `download_year`.
- To change URL layout, update `build_urls_for_year` or pass a different `base` template to `download_year`.
- When modifying extraction behavior, preserve `safe_extract` safety checks and update manifest generation accordingly.

If anything here is unclear or you'd like additional examples (CI workflow, tests, or a `main` subcommand to chain download+extract), say which area to expand and I will iterate.
