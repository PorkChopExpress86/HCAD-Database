import os
import re
from flask import Flask, request, jsonify, abort
import psycopg2
from psycopg2.extras import RealDictCursor

app = Flask(__name__)

DATABASE_URL = os.getenv("DATABASE_URL")
API_KEY = os.getenv("MCP_BRIDGE_API_KEY", "")

if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is required")

SELECT_RE = re.compile(r"^\s*SELECT\b", re.IGNORECASE)


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def require_auth():
    if not API_KEY:
        return
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        abort(401)
    token = auth.split(" ", 1)[1]
    if token != API_KEY:
        abort(403)


@app.route("/", methods=["GET"])
def index():
    return jsonify(
        {
            "service": "mcp-bridge",
            "version": "0.1",
            "endpoints": ["/tables", "/schema/<table>", "/query"],
        }
    )


@app.route("/tables", methods=["GET"])
def list_tables():
    require_auth()
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type='BASE TABLE'"
            )
            rows = cur.fetchall()
    return jsonify([r["table_name"] for r in rows])


@app.route("/schema/<table>", methods=["GET"])
def table_schema(table):
    require_auth()
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='public' AND table_name = %s",
                (table,),
            )
            rows = cur.fetchall()
    if not rows:
        return jsonify({"error": "table not found"}), 404
    return jsonify(rows)


@app.route("/query", methods=["POST"])
def query():
    require_auth()
    data = request.get_json(silent=True) or {}
    sql = data.get("sql", "")
    if not sql or not SELECT_RE.match(sql):
        return jsonify({"error": "Only SELECT queries allowed"}), 400
    # Simple safety: disallow semicolons to avoid multiple statements
    if ";" in sql:
        return jsonify({"error": "Multiple statements are not allowed"}), 400
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("BEGIN TRANSACTION READ ONLY")
            cur.execute(sql)
            rows = cur.fetchall()
            cur.execute("ROLLBACK")
    return jsonify(rows)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 5000)))
