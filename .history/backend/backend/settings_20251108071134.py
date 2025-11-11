import os
import logging
from pathlib import Path
from dotenv import load_dotenv
import dj_database_url

# === Percorsi base ===
BASE_DIR = Path(__file__).resolve().parent.parent

# === Caricamento intelligente file .env (.env -> .env.prod -> .env.dev) + override via ENV_FILE ===
env_candidates = [
    BASE_DIR / ".env",
    BASE_DIR / ".env.prod",
    BASE_DIR / ".env.dev",
]
override = os.getenv("ENV_FILE")
if override and (BASE_DIR / override).exists():
    env_path = BASE_DIR / override
else:
    env_path = next((p for p in env_candidates if p.exists()), None)

if env_path:
    if os.getenv("PRINT_ENV_LOAD", "1") == "1":
        print(f"🔄 Loading env file: {env_path}")
    load_dotenv(dotenv_path=env_path)
else:
    print("⚠️ Nessun file .env trovato tra .env, .env.prod, .env.dev")

# === Config base da ENV ===
SECRET_KEY = os.getenv("SECRET_KEY", "django-insecure-change-me")
DEBUG = os.getenv("DEBUG", "False").strip().lower() in ("true", "1", "yes")
ALLOWED_HOSTS = [h.strip() for h in os.getenv("ALLOWED_HOSTS", "127.0.0.1,localhost").split(",") if h.strip()]
CSRF_TRUSTED_ORIGINS = [o.strip() for o in os.getenv("CSRF_TRUSTED_ORIGINS", "").split(",") if o.strip()]

# === Applicazioni ===
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "corsheaders",
    # "movies",
    "movies.apps.MoviesConfig",
]

# === Middleware (inserisci corsheaders PRIMA di CommonMiddleware) ===
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

# === CORS ===
# In ambiente di sviluppo locale (DEV):
# --------------------------------------------------
# Poiché Hugo cambia spesso porta (es. 1313, 1314, 1315...),
# conviene abilitare temporaneamente TUTTE le origini
# impostando nel file .env.dev:
#
#     CORS_ALLOW_ALL=true
#
# In questo modo puoi lavorare liberamente da qualsiasi porta
# senza ricevere "Network Error" da Axios.

# In ambiente di produzione (PROD):
# --------------------------------------------------
# NON usare CORS_ALLOW_ALL, ma definisci un elenco preciso di origini
# nel file .env.prod, ad esempio:
#
#     CORS_ALLOWED_ORIGINS=https://www.miodominio.it,https://api.miodominio.it
#
# In questo modo solo i frontend autorizzati potranno accedere alle API.

if os.getenv("CORS_ALLOW_ALL", "0").lower() in ("1", "true", "yes"):
    # ✅ Modalità "libera" per sviluppo locale
    CORS_ALLOW_ALL_ORIGINS = True
else:
    # ✅ Modalità "ristretta" per produzione
    CORS_ALLOWED_ORIGINS = [
        o.strip()
        for o in os.getenv(
            "CORS_ALLOWED_ORIGINS",
            # Valori di default: le origini più comuni per dev locale
            "http://localhost:1313,http://127.0.0.1:1313,"
            "http://localhost:1314,http://127.0.0.1:1314,"
            "http://localhost:8000,http://127.0.0.1:8000"
        ).split(",")
        if o.strip()
    ]

ROOT_URLCONF = "backend.urls"


# === Templates ===
TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [
            BASE_DIR / "templates",  # opzionale: usa se hai template globali
        ],
        "APP_DIRS": True,
        "OPTIONS": {
            "debug": DEBUG,
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "backend.wsgi.application"

# === Database (usa dj_database_url per gestire qualsiasi backend) ===
# Esempi:
# sqlite:///db.sqlite3
# postgres://user:pass@host:5432/dbname
DATABASES = {
    "default": dj_database_url.parse(
        os.getenv("DATABASE_URL", "sqlite:///db.sqlite3"),
        conn_max_age=600,
        ssl_require=False if DEBUG else False,  # metti True se usi Postgres con SSL
    )
}
# Se è SQLite ed è path relativo, convertilo in BASE_DIR / nomefile
if DATABASES["default"]["ENGINE"] == "django.db.backends.sqlite3":
    name = DATABASES["default"]["NAME"]
    if not os.path.isabs(str(name)):
        DATABASES["default"]["NAME"] = str(BASE_DIR / name)

# === Password Validation ===
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# === Internationalization ===
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

# === Static Files ===
STATIC_URL = "/static/"
STATIC_ROOT = os.getenv("DJANGO_STATIC_ROOT", str(BASE_DIR / "staticfiles"))
STATICFILES_DIRS = [ BASE_DIR / os.getenv("DJANGO_STATIC_PATH", "static") ]

# === DRF ===
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [],  # in dev nessuna session/CSRF
}

# === Logging (file locale) ===
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {"format": "{levelname} {asctime} {module} {message}", "style": "{"},
    },
    "handlers": {
        "file": {
            "level": "DEBUG" if DEBUG else "INFO",
            "class": "logging.FileHandler",
            "filename": str(BASE_DIR / "django_debug.log"),
            "formatter": "verbose",
        },
    },
    "loggers": {
        "django": {"handlers": ["file"], "level": "DEBUG" if DEBUG else "INFO", "propagate": True},
    },
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# === Debug dump su file ===
try:
    with open(BASE_DIR / "settings_debug.log", "w") as f:
        f.write(f"DEBUG: {DEBUG}\n")
        f.write(f"ALLOWED_HOSTS: {ALLOWED_HOSTS}\n")
        f.write(f"STATICFILES_DIRS: {STATICFILES_DIRS}\n")
        f.write(f"STATIC_ROOT: {STATIC_ROOT}\n")
        f.write(f"DATABASE: {DATABASES}\n")
except Exception as e:
    print("⚠️ Impossibile scrivere settings_debug.log:", e)
