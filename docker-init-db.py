#!/usr/bin/env python3

import importlib.util
import os
import sys
from pathlib import Path

PROJECT_ROOT = Path("/opt/OpenPagingServer")
DB_INIT_SCRIPT = PROJECT_ROOT / "scripts" / "database-initialization.py"
ENV_OUTPUT_DIR = Path("/opt/ops-env")


def main():
    if not DB_INIT_SCRIPT.exists():
        print(f"ERROR: {DB_INIT_SCRIPT} not found")
        sys.exit(1)

    spec = importlib.util.spec_from_file_location("database_initialization", DB_INIT_SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    root_pw = os.environ.get("MARIADB_ROOT_PASSWORD", "")
    db_host = os.environ.get("DB_HOST", "db")
    db_port = int(os.environ.get("DB_PORT", "3306"))

    import mysql.connector

    def connect_as_admin():
        kwargs = {
            "user": "root",
            "host": db_host,
            "port": db_port,
        }
        kwargs["passwd"] = root_pw
        return mysql.connector.connect(**kwargs)

    mod.connect_as_admin = connect_as_admin

    def recreate_database_user(cursor, db_pw):
        db_name = mod.DATABASE_NAME
        db_user = mod.DATABASE_USER
        for host in ["localhost", "127.0.0.1", "%"]:
            cursor.execute(f"DROP USER IF EXISTS '{db_user}'@'{host}'")
            cursor.execute(
                f"CREATE USER '{db_user}'@'{host}' IDENTIFIED BY {mod.sql_string(db_pw)}"
            )
            cursor.execute(
                f"GRANT ALL PRIVILEGES ON `{db_name}`.* TO '{db_user}'@'{host}'"
            )
        cursor.execute("FLUSH PRIVILEGES")

    mod.recreate_database_user = recreate_database_user

    app_db_host = os.environ.get("APP_DB_HOST", "127.0.0.1")

    def write_config(db_pw):
        env_content = (
            f"DB_HOST='{app_db_host}'\n"
            f"DB_USER='{mod.DATABASE_USER}'\n"
            f"DB_PASS={mod.sql_string(db_pw)}\n"
            f"DB_NAME='{mod.DATABASE_NAME}'\n"
            f"DEBUG=false\n"
            f"WEB_REVERSE_PROXY_ALLOWED=\n"
            f"API_REVERSE_PROXY_ALLOWED=\n"
            f"DEMO_MODE=false\n\n"
        )

        os.makedirs(PROJECT_ROOT, exist_ok=True)
        (PROJECT_ROOT / ".env").write_text(env_content, encoding="utf-8")
        (PROJECT_ROOT / ".oobe").write_text("", encoding="utf-8")

        os.makedirs(ENV_OUTPUT_DIR, exist_ok=True)
        (ENV_OUTPUT_DIR / ".env").write_text(env_content, encoding="utf-8")
        (ENV_OUTPUT_DIR / ".oobe").write_text("", encoding="utf-8")
        print(f"Generated .env written to {ENV_OUTPUT_DIR / '.env'}")

    mod.write_config = write_config

    mod.main()
    print("Docker database initialization complete.")


if __name__ == "__main__":
    main()
