# HCAD ZIP Downloader & Database Loader

Tools to download HCAD CAMA ZIP files, extract them safely, and load them into a database (PostgreSQL recommended).

## Quick Start (Docker + Postgres)

1.  **Start the database:**
    ```powershell
    docker-compose up -d
    ```
    This starts a PostgreSQL instance on port 5432 (user: `postgres`, pass: `postgres`, db: `hcad`).

2.  **Install dependencies:**
    ```powershell
    & ".venv/Scripts/python.exe" -m pip install -r requirements.txt
    ```

3.  **Run the pipeline:**
    ```powershell
    # Download (example year)
    & ".venv/Scripts/python.exe" download.py --use-named-list --year 2025

    # Extract
    & ".venv/Scripts/python.exe" extract.py --workers 4 --manifest extracted

    # Load into DB (uses .env settings)
    & ".venv/Scripts/python.exe" load.py --indir extracted
    ```

## MCP Server Configuration (Claude Desktop)

To allow Claude (or other MCP clients) to query your local HCAD database, add this to your MCP configuration file (e.g., `%APPDATA%\Claude\claude_desktop_config.json` on Windows):

```json
{
  "mcpServers": {
    "hcad-postgres": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "node:18-alpine",
        "npx", "-y", "@modelcontextprotocol/server-postgres",
        "postgresql://postgres:postgres@host.docker.internal:5432/hcad"
      ]
    }
  }
}
```
*Note: This uses `host.docker.internal` to connect from the MCP container to the Postgres container running on your host's port 5432.*

Alternatively you can run an MCP Postgres server as a Docker service (recommended for reproducibility). The repository's `docker-compose.yml` includes a `mcp_postgres` service which runs the MCP Postgres server via `npx` and exposes an HTTP MCP endpoint on port 8080.

Start both services (DB + MCP server):

```powershell
docker-compose up -d db mcp_postgres
```

The MCP server listens on http://localhost:8080 by default. To configure an MCP client (e.g., Claude Desktop) to use this local MCP server, add a config like:

```json
{
  "mcpServers": {
    "hcad-postgres": {
      "command": "curl",
      "args": ["http://localhost:8080/"]
    }
  }
}
```

Notes:
- The `mcp_postgres` container connects to the `db` service using the Compose network; credentials are sourced from the repository `.env`.
- If you run the MCP server outside Docker and want it to reach the Postgres container, use `host.docker.internal` in the connection string on Windows/macOS Docker Desktop. On Linux, either publish the Postgres port and connect to localhost or run both services in Docker.

## Legacy Usage (Downloader only)

Usage:

```powershell
& "D:/HCAD Database/.venv/Scripts/python.exe" "d:\\HCAD Database\\download.py" --url https://hcad.org/pdata/pdata-property-downloads.html --outdir downloads
```

Notes:
 - Script scans the page for links that contain ".zip" and downloads them.
 - Default output folder is `downloads`.
 - Use `--dry-run` to list found zip files without downloading.
 - Use `--workers N` to set the number of concurrent downloads (default 4).

Dependencies:
```powershell
pip install -r requirements.txt
```

Optional packages:
 - `tqdm` shows progress bars for downloads.

Code formatting
---------------

This project uses Black for Python code formatting. Configure your environment and run Black or install the Git pre-commit hook:

Install Black (and pre-commit if you want hooks):

```powershell
pip install black pre-commit
```

Run Black across the repository:

```powershell
& "D:/HCAD Database/.venv/Scripts/python.exe" -m black .
```

Or install the pre-commit hook so Black runs on each commit:

```powershell
pre-commit install
pre-commit run --all-files
```

Black is configured via `pyproject.toml` (line length 88).
