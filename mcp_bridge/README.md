mcp_bridge

A small HTTP bridge that exposes read-only access to the Postgres database.

Endpoints:
- GET / -> service info
- GET /tables -> list tables in public schema
- GET /schema/<table> -> schema for a table
- POST /query -> execute a read-only SELECT query. JSON body: {"sql": "SELECT ..."}

Authentication:
- If MCP_BRIDGE_API_KEY is set in the environment, include header `Authorization: Bearer <key>` in requests.

Run with docker-compose (from repo root):

```powershell
# build and start the bridge and db
docker-compose up -d db mcp_bridge

# test
curl --header "Authorization: Bearer $env:MCP_BRIDGE_API_KEY" http://localhost:5000/tables
```
