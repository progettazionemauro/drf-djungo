# env_loader.py
import os
from dotenv import load_dotenv
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Permetti override esplicito: ENV_FILE=.env.prod ecc.
override = os.getenv("ENV_FILE")
if override and (BASE_DIR / override).exists():
    env_path = BASE_DIR / override
elif (BASE_DIR / ".env").exists():
    env_path = BASE_DIR / ".env"
else:
    env_path = BASE_DIR / ".env.dev"

# Stampa solo se non siamo in prod
if os.getenv("PRINT_ENV_LOAD", "1") == "1":
    print(f"🔄 Loading env file: {env_path}")

load_dotenv(dotenv_path=env_path)
