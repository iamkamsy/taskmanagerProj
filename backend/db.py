from pymongo import MongoClient
import os

_client: MongoClient | None = None


def init_db(app):
    """Create the MongoClient once at app startup and stash it on app.extensions."""
    global _client
    tls_insecure = os.environ.get("TLS_INSECURE", "false").lower() == "true"
    _client = MongoClient(
        os.environ["MONGO_URI"],
        tlsInsecure=tls_insecure,
    )
    app.extensions["mongo_db"] = _client[os.environ.get("DB_NAME", "taskmanager")]


def get_db():
    return _client[os.environ.get("DB_NAME", "taskmanager")]
