# data_ingestion/generate_aligned_data.py

import os
import sys
import logging
import random
from supabase import create_client, Client
from dotenv import load_dotenv

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
dotenv_path = os.path.join(os.path.dirname(__file__), '..', '.env')
load_dotenv(dotenv_path=dotenv_path)

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def generate_realistic_values():
    """Generates realistic AQI and weather values"""
    pm25 = round(random.uniform(20, 150), 2)
    min_temp = round(random.uniform(20, 30), 1)
    max_temp = round(min_temp + random.uniform(5, 12), 1)
    rainfall = round(random.uniform(0, 5), 1) if random.random() < 0.2 else 0.0 # 20% chance of rain
    return {'pm25': pm25, 'min_temp': min_temp, 'max_temp': max_temp, 'rainfall': rainfall}

def generate_aligned_data():
    """Generates and aligns all necessary sample data for the calibration period"""

    logging.info("Starting generation of aligned sample data for calibration...")

    try:
        # Clear existing tables
        logging.info("Clearing station_readings and weather_readings tables...")
        supabase.table('station_readings').delete().neq('id', 0).execute()
        supabase.table('weather_readings').delete().neq('id', 0).execute()

        # Fetch stations
        stations_response = supabase.table('ground_stations').select('id, location').execute()
        stations = stations_response.data
        if not stations:
            logging.error("No ground stations found.")
            return

        target_dates = ['2025-06-28', '2025-06-29', '2025-06-30', '2025-07-01', '2025-07-02']

        all_cpcb_readings = []
        all_weather_readings = []

        for station in stations:
            for date_str in target_dates:
                # Generate a single realistic reading per station per day
                values = generate_realistic_values()

                all_cpcb_readings.append({
                    'station_id_ref': station['id'],
                    'recorded_at': f"{date_str}T12:00:00+00:00",
                    'pm25': values['pm25']
                })

                all_weather_readings.append({
                    'station_id_ref': station['id'],
                    'location': station['location'],
                    'recorded_at': date_str,
                    'min_temp': values['min_temp'],
                    'max_temp': values['max_temp'],
                    'rainfall': values['rainfall']
                })

        # Bulk insert
        logging.info(f"Inserting {len(all_cpcb_readings)} CPCB readings...")
        supabase.table('station_readings').insert(all_cpcb_readings).execute()

        logging.info(f"Inserting {len(all_weather_readings)} weather readings...")
        supabase.table('weather_readings').insert(all_weather_readings).execute()

        logging.info("✅ Aligned sample data generation complete.")

    except Exception as e:
        logging.error(f"An error occurred: {e}", exc_info=True)

if __name__ == "__main__":
    generate_aligned_data()
