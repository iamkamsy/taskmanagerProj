#imports necessary modules
from pymongo import MongoClient
from dotenv import load_dotenv
import os

#loads environment variables from .env file
load_dotenv()

MONGO_URI = os.getenv("MONGO_URI")
DB_NAME = os.getenv("DB_NAME")

#establishes connection to MongoDB
client = MongoClient(MONGO_URI)
db = client[DB_NAME]

#function to test the database connection
def test_connection():
    try:
        # Try listing collections to test connection
        db.list_collection_names()
        print("✅ MongoDB connection successful!")
    except Exception as e:
        print("❌ MongoDB connection failed:", e)
