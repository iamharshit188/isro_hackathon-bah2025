import os
import sys
from dotenv import load_dotenv
import logging

# Setup clear logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

# --- This is the key part ---
# We will explicitly find the absolute path to the .env file
# instead of relying on the current working directory.

# Get the directory where this script (`check_env.py`) is located
script_dir = os.path.dirname(os.path.abspath(__file__))
# Go one level up to get the project's root directory (`bah-aqi`)
project_root = os.path.dirname(script_dir)
# Construct the full, absolute path to your .env file
dotenv_path = os.path.join(project_root, '.env')

logging.info(f"Attempting to load .env file from this exact path: {dotenv_path}")

# Load the .env file from the specified path
was_loaded = load_dotenv(dotenv_path=dotenv_path)

if not was_loaded:
    logging.error("CRITICAL: The .env file was NOT found at the path above.")
    sys.exit(1)

logging.info("SUCCESS: .env file was found and loaded.")

# --- Now we check the actual values ---
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_SERVICE_KEY")

print("\n" + "="*40)
print("   ENVIRONMENT VARIABLE DIAGNOSTIC")
print("="*40)
print(f"Value of SUPABASE_URL:     '{supabase_url}'")
print(f"Value of SUPABASE_SERVICE_KEY: '{'********' if supabase_key else None}'") # Hide the key for safety
print("="*40 + "\n")

if supabase_url and "supabase.co" in supabase_url:
    logging.info("URL check PASSED.")
else:
    logging.error("URL check FAILED. The URL is missing, empty, or invalid.")
    logging.error("Please re-copy the URL from your Supabase dashboard into the .env file.")

