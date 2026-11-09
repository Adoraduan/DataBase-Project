import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent

# 连接信息与密钥放在仓库根目录的 .env，不入库
load_dotenv(BASE_DIR / ".env")


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-only-change-me")

    DB_DRIVER = os.getenv("DB_DRIVER", "ODBC Driver 18 for SQL Server")
    DB_SERVER = os.getenv("DB_SERVER", r".\SQLEXPRESS")
    DB_NAME = os.getenv("DB_NAME", "CampusCoffee")
    DB_USER = os.getenv("DB_USER", "")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "")
    DB_ENCRYPT = os.getenv("DB_ENCRYPT", "yes")
    DB_TRUST_SERVER_CERTIFICATE = os.getenv("DB_TRUST_SERVER_CERTIFICATE", "yes")
    DB_TIMEOUT = int(os.getenv("DB_TIMEOUT", "5"))

    LOG_FILE = os.getenv("LOG_FILE", str(BASE_DIR / "logs" / "app.log"))
