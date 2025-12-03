from sqlalchemy import create_engine, inspect, text

engine = create_engine("postgresql://postgres:postgres@localhost:5432/hcad")
with engine.begin() as conn:
    tables = sorted(inspect(engine).get_table_names())
    print(f"Total tables: {len(tables)}\n")
    for t in tables:
        count = conn.execute(text(f'SELECT COUNT(*) FROM "{t}"')).scalar()
        print(f"{t:45} {count:>12,}")
