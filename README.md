# HCAD Database Pipeline

Complete pipeline for downloading, extracting, and loading Harris County Appraisal District (HCAD) property data into PostgreSQL with comprehensive analysis views for property tax protests.

## Features

- **Automated Data Pipeline**: Download → Extract → Load → Create Analysis Views
- **Comprehensive Protest Analysis**: Pre-built views with 1.18M+ residential properties including protest history, hearing outcomes, and comparable property analysis
- **Safe Extraction**: Zip-slip protection for secure file extraction
- **Database Views**: Automatically creates `property_features`, `property_features_v2`, and `residential_protest_analysis` views
- **MCP Server Support**: Query database directly from Claude Desktop or other MCP clients

## Quick Start (Docker + Postgres)

1.  **Start the database:**
    ```powershell
    docker-compose up -d
    ```
    This starts a PostgreSQL 15 instance on port 5432 (user: `postgres`, pass: `postgres`, db: `hcad`).

2.  **Install dependencies:**
    ```powershell
    & ".venv/Scripts/python.exe" -m pip install -r requirements.txt
    ```

3.  **Run the complete pipeline:**
    ```powershell
    # Download HCAD data (example: 2025)
    & ".venv/Scripts/python.exe" download.py --use-named-list --year 2025

    # Extract all ZIP files
    & ".venv/Scripts/python.exe" extract.py --workers 4 --manifest extracted

    # Load into database (automatically creates analysis views)
    & ".venv/Scripts/python.exe" load.py --indir extracted --db-uri postgresql://postgres:postgres@localhost:5432/hcad
    ```

After loading, three analysis views are automatically created:
- `property_features` - Normalized property characteristics
- `property_features_v2` - Enhanced with anomaly detection
- `residential_protest_analysis` - Comprehensive protest data for 1.18M+ residential properties

## Analysis Views

The database includes powerful pre-built views for property analysis:

### `residential_protest_analysis`
Comprehensive view covering **1,185,083 residential properties** across all residential state classes (A1-A4, B1-B4):
- Property details (address, owner, neighborhood)
- Assessment values (market, appraised, land, building)
- Building characteristics (year built, sqft, quality, multiple buildings)
- Features (bedrooms, baths, pool, anomaly detection)
- **Protest history** (total protests, success rates)
- **Hearing outcomes** (last 5 years, reductions, success rates)
- Sales history and exemptions (homestead, over-65, etc.)
- Comparable analysis helpers ($/sqft calculations)

See `RESIDENTIAL_PROTEST_VIEW_DOCUMENTATION.md` for complete usage guide.

### Sample Queries
```sql
-- Get protest-ready property profile
SELECT * FROM residential_protest_analysis WHERE acct = '1234567890123';

-- Find comparable properties
SELECT acct, address, current_market_value, market_value_per_sqft,
       bedrooms, full_baths, primary_year_built
FROM residential_protest_analysis
WHERE neighborhood_code = '1234.50'
  AND primary_heated_sqft BETWEEN 1800 AND 2200
  AND primary_year_built BETWEEN 2000 AND 2010
ORDER BY ABS(primary_heated_sqft - 2000);

-- Protest success analysis by neighborhood
SELECT neighborhood_code, COUNT(*) as properties,
       SUM(total_protests) as total_protests,
       ROUND(AVG(protest_success_rate), 2) as avg_success_rate
FROM residential_protest_analysis
WHERE neighborhood_code LIKE '1234%'
  AND hearing_count > 0
GROUP BY neighborhood_code
ORDER BY avg_success_rate DESC;
```

## MCP Server Configuration

### Local Installation (Recommended)
The project uses Node.js-based MCP Postgres server via npx. Configure in VS Code or Claude Desktop:

**For VS Code** (`mcp.json`):
```json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://postgres:postgres@localhost:5432/hcad"]
    }
  }
}
```

**For Claude Desktop** (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "hcad-postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://postgres:postgres@localhost:5432/hcad"]
    }
  }
}
```

Requires Node.js v18+ and npm installed on your system.

Requires Node.js v18+ and npm installed on your system.

## Project Structure

```
├── download.py              # Download HCAD ZIP files
├── extract.py              # Extract ZIP files with safety checks
├── load.py                 # Load data into PostgreSQL + create views
├── post_load_setup.sql     # Auto-executed: creates functions & views
├── sample_queries.sql      # Example queries and view definitions
├── docker-compose.yml      # PostgreSQL 15 database container
├── database_info/          # HCAD codebook metadata
│   ├── codebook_tables/    # Table column definitions
│   └── pdataCodebook_structured.json
├── downloads/              # Downloaded ZIP files
└── extracted/              # Extracted data files

Key Files:
- RESIDENTIAL_PROTEST_VIEW_DOCUMENTATION.md - Complete view usage guide
- POST_LOAD_SETUP_IMPLEMENTATION.md - View creation details
- test_post_load_setup.py - Validate post-load setup
- test_residential_protest_view.sql - Sample test queries
```

## Development

### Code Formatting
This project uses Black for Python code formatting:

```powershell
# Format all Python files
& ".venv/Scripts/python.exe" -m black .

# Install pre-commit hooks (optional)
pre-commit install
pre-commit run --all-files
```

Black is configured in `pyproject.toml` (line length 88).

### Testing Post-Load Setup
```powershell
# Verify views were created correctly
& ".venv/Scripts/python.exe" test_post_load_setup.py
```

Expected output:
```
✓ Post-load setup completed successfully
✓ Found 3 views (expected 3)
✓ safe_num() function works
✓ residential_protest_analysis has 1,185,083 rows
```

## Environment Variables

Create a `.env` file (see `.env_example`):
```env
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/hcad
```

The loader uses this connection string if `--db-uri` is not provided.

## Command Reference

### Download
```powershell
# Download with default file list for a year
& ".venv/Scripts/python.exe" download.py --use-named-list --year 2025

# Dry run to see what would be downloaded
& ".venv/Scripts/python.exe" download.py --use-named-list --year 2025 --dry-run

# Download from custom URL
& ".venv/Scripts/python.exe" download.py --url https://download.hcad.org/data/CAMA/2025/ --outdir downloads
```

### Extract
```powershell
# Extract with 4 workers and create manifest
& ".venv/Scripts/python.exe" extract.py --workers 4 --manifest extracted

# Extract specific pattern
& ".venv/Scripts/python.exe" extract.py --pattern "Real*.zip" --workers 2
```

### Load
```powershell
# Load all data (creates views automatically)
& ".venv/Scripts/python.exe" load.py --indir extracted --db-uri postgresql://postgres:postgres@localhost:5432/hcad

# Use DATABASE_URL from .env
& ".venv/Scripts/python.exe" load.py --indir extracted
```

## Troubleshooting

**Views not created after loading:**
```powershell
# Manually run post-load setup
Get-Content "post_load_setup.sql" | docker exec -i hcad-db psql -U postgres -d hcad
```

**Check table counts:**
```powershell
& ".venv/Scripts/python.exe" check_counts.py
```

**Verify MCP connection:**
Check that MCP server can query the database by running a simple query like:
```sql
SELECT COUNT(*) FROM real_acct;
```

**Verify MCP connection:**
Check that MCP server can query the database by running a simple query like:
```sql
SELECT COUNT(*) FROM real_acct;
```

## Contributing

Contributions welcome! Please ensure:
1. Code is formatted with Black
2. New SQL views are documented
3. Test scripts pass

## License

See repository for license details.
