import os
import sys
import xarray as xr
from supabase import create_client, Client
from dotenv import load_dotenv
import logging
import numpy as np
from datetime import datetime

# --- Setup Logging ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# --- Robust Environment Variable Loading ---
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(script_dir)
dotenv_path = os.path.join(project_root, '.env')
if not os.path.exists(dotenv_path):
    logging.error(f"FATAL: .env file not found at {dotenv_path}")
    sys.exit(1)
load_dotenv(dotenv_path=dotenv_path)

DATA_DIR = os.path.join(project_root, "isro_data/")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    logging.error("FATAL: SUPABASE_URL or SUPABASE_SERVICE_KEY is missing from your .env file.")
    sys.exit(1)

def process_and_store_isro_data(file_path: str, supabase: Client):
    """Parses an ISRO EOS-6 Level-3 NetCDF file and stores the data in batches."""
    
    filename = os.path.basename(file_path)
    logging.info(f"--- Processing ISRO file: {filename} ---")
    
    try:
        ds = xr.open_dataset(file_path)
        
        aod_data = ds['AOD'].values
        lats = ds['latitude'].values
        lons = ds['longitude'].values
        
        lon_grid, lat_grid = np.meshgrid(lons, lats)
        
        aod_flat = aod_data.flatten()
        lats_flat = lat_grid.flatten()
        lons_flat = lon_grid.flatten()
        
        valid_mask = (
            np.isfinite(aod_flat) & (aod_flat >= 0) &
            np.isfinite(lats_flat) & np.isfinite(lons_flat)
        )
        
        clean_aod = aod_flat[valid_mask]
        clean_lats = lats_flat[valid_mask]
        clean_lons = lons_flat[valid_mask]
        
        num_valid_points = len(clean_aod)
        if num_valid_points == 0:
            logging.warning(f"No valid data points found in {filename}. Skipping.")
            return

        logging.info(f"Found {num_valid_points} valid data points. Starting batched insertion...")

        date_string = filename.split('_')[1]
        timestamp = datetime.strptime(date_string, '%Y%m%d').isoformat()

        # --- [THE BATCHING LOGIC] ---
        BATCH_SIZE = 50000  # Insert 50,000 records at a time
        for i in range(0, num_valid_points, BATCH_SIZE):
            batch_end = i + BATCH_SIZE
            logging.info(f"Preparing batch {i+1} to {min(batch_end, num_valid_points)}...")
            
            payloads = [
                {
                    'location': f"POINT({lon} {lat})",
                    'aod_value': float(aod),
                    'recorded_at': timestamp
                }
                for lon, lat, aod in zip(clean_lons[i:batch_end], clean_lats[i:batch_end], clean_aod[i:batch_end])
            ]
            
            supabase.table('satellite_aod_data').insert(payloads, returning='minimal').execute()
            logging.info(f"Successfully inserted batch.")
        
        logging.info(f"--- Finished processing file: {filename} ---")
        ds.close()

    except Exception as e:
        logging.error(f"An error occurred while processing file {file_path}: {e}", exc_info=True)

if __name__ == "__main__":
    supabase_client: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    logging.info("Starting ISRO MOSDAC Data Ingestion Process...")
    for filename in os.listdir(DATA_DIR):
        if filename.endswith((".nc", ".hdf5")):
            process_and_store_isro_data(
                os.path.join(DATA_DIR, filename), 
                supabase_client
            )
    logging.info("ISRO MOSDAC Data Ingestion Process Finished.")
