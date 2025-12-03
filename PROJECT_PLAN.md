# Project Plan: HCAD CAMA Downloader & Extractor

One-line summary
A CLI and library to download HCAD CAMA ZIPs, safely extract them, and provide manifests for downstream ETL and analysis.

Context / background
This repository contains utilities to programmatically download CAMA archives from HCAD, extract them with zip-slip protection, and (optionally) load selected files into a database for analysis.

Goals
- Provide stable CLI and importable APIs for download, extraction, and loading.
- Produce safe, reproducible manifests for each extraction run.
- Make it easy for contributors to run the pipeline locally and in CI.

Scope
- In-scope: `download.py`, `extract.py`, `load.py` behaviors; manifest format; documentation and examples; minimal validation checks.
- Out-of-scope: downstream analytics, ETL pipelines beyond schema loading, large-scale production orchestration (can be added later).

Database Strategy
- Primary: PostgreSQL via Docker (recommended for production/analytics).
- Dev/Test: SQLite (supported but less capable).
- MCP: Use `@modelcontextprotocol/server-postgres` running in a Docker container to expose the DB to AI agents.

High-level milestones
1. Core tooling & documentation
   - Stabilize `download.py`, `extract.py`, and `load.py` APIs
   - Provide CLI examples and usage in README
2. Validation & example runs
   - Add sample manifests in `extracted/`
   - Add a lightweight validation script to ensure key tables load
3. Contributor experience & CI
   - Add `PROJECT_PLAN.md`, `CONTRIBUTING.md`, and CI tasks for linting and basic smoke tests

Deliverables
- Working CLI commands and programmatic APIs
- `PROJECT_PLAN.md` (this file)
- Example `.env_example` with variables used by the loader
- Basic validation script or README check-list

Owners & contacts
- Repo owner: (add GitHub handle or email)
- Primary maintainer for loader: (assign an owner)

Next actions (convert these to GitHub issues)
- Create issues for: add unit/cli smoke tests; add CI job for Black and basic import; add schema migration or DDL files; add validation script.
- Update README with one-line usage examples for each stage.

Acceptance criteria
- All CLI commands run successfully in a fresh virtualenv after `pip install -r requirements.txt`.
- `extract.extract_all` produces a manifest JSON for a sample ZIP and files are present in `extracted/`.
- `load.load_data` runs to completion against a test database and populates key tables (`real_acct`, `t_pp_c`, `t_jur_value`) with non-zero rows.

Risks & mitigations
- Upstream URL layout changes: mitigation — make the URL template configurable and test sniffing functions.
- Large archives and memory pressure: mitigation — stream extraction, tune workers, use server-backed DB when loading.

How to contribute
- Fork and open PRs for small, focused changes.
- Run `& ".venv/Scripts/python.exe" -m pip install -r requirements.txt` then use the CLI examples in `README.md`.
- Follow code style (Black configured via `pyproject.toml`).

Links & important files
- `download.py` — downloader entrypoint
- `extract.py` — extractor and `extract_all` API
- `load.py` — loader and `load_data` API
- `extracted/` — sample outputs and manifests



