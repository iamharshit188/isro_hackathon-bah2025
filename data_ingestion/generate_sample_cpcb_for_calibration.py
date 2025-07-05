# data_ingestion/generate_sample_cpcb_for_calibration.py

import os
import sys
import logging
import random
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv

# --- Setup ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
dotenv_path = os.path.join(os.path.dirname(__file__), '..', '.env')
load_dotenv(dotenv_path=dotenv_path)

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    logging.error("FATAL: Supabase credentials not found. Check your .env file.")
    sys.exit(1)

def generate_realistic_aqi_values():
    """Generate realistic AQI values based on typical Indian air quality patterns"""
    # PM2.5 values: 20-150 range (Good to Very Poor)
    pm25 = round(random.uniform(25, 120), 2)
    # PM10 is typically 1.2-1.8x higher than PM2.5
    pm10 = round(pm25 * random.uniform(1.3, 1.7), 2)
    # Other pollutants in typical ranges
    no2 = round(random.uniform(15, 65), 2)
    so2 = round(random.uniform(8, 35), 2)
    co = round(random.uniform(0.8, 2.5), 2)
    o3 = round(random.uniform(25, 90), 2)

    return {
        'pm25': pm25,
        'pm10': pm10,
        'no2': no2,
        'so2': so2,
        'co': co,
        'o3': o3
    }

def generate_calibration_cpcb_data():
    """Generate sample CPCB data for June 28 - July 2, 2025 to match ISRO data"""

    logging.info("Starting generation of sample CPCB data for calibration (2025-06-28 to 2025-07-02)...")
    supabase_client: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    try:
        # Step 1: Clear existing station readings to avoid conflicts
        logging.info("Clearing existing station readings...")
        delete_result = supabase_client.table('station_readings').delete().neq('id', 0).execute()
        logging.info(f"Cleared {len(delete_result.data) if delete_result.data else 0} existing readings.")

        # Step 2: Get all ground stations
        stations_response = supabase_client.table('ground_stations').select('id, city, state').execute()

        if not stations_response.data:
            logging.error("No ground stations found. Please run CPCB ingestion first.")
            return

        stations = stations_response.data
        logging.info(f"Found {len(stations)} ground stations. Generating sample data...")

        # Step 3: Generate data for the exact dates that match ISRO data
        target_dates = [
            '2025-06-28',
            '2025-06-29',
            '2025-06-30',
            '2025-07-01',
            '2025-07-02'
        ]

        all_readings = []

        # Step 4: For each station and each date, generate realistic readings
        for station in stations:
            for date_str in target_dates:
                # Generate readings for multiple times during the day to simulate real monitoring
                times = ['06:00:00', '12:00:00', '18:00:00']  # Morning, noon, evening

                for time_str in times:
                    pollutant_values = generate_realistic_aqi_values()

                    reading_data = {
                        'station_id_ref': station['id'],
                        'recorded_at': f"{date_str}T{time_str}+00:00",
                        'pm25': pollutant_values['pm25'],
                        'pm10': pollutant_values['pm10'],
                        'no2': pollutant_values['no2'],
                        'so2': pollutant_values['so2'],
                        'co': pollutant_values['co'],
                        'o3': pollutant_values['o3']
                    }
                    all_readings.append(reading_data)

        # Step 5: Bulk insert all generated readings
        if all_readings:
            logging.info(f"Inserting {len(all_readings)} sample CPCB readings...")
            result = supabase_client.table('station_readings').insert(all_readings).execute()

            if result.data:
                logging.info("✅ Successfully generated sample CPCB data for calibration.")
                logging.info(f"Generated data for {len(target_dates)} days across {len(stations)} stations.")
            else:
                logging.error("Failed to insert sample CPCB data.")
        else:
            logging.warning("No sample data generated.")

    except Exception as e:
        logging.error(f"An error occurred during sample data generation: {e}", exc_info=True)

if __name__ == "__main__":
    generate_calibration_cpcb_data()
