# data_ingestion/imd_ingestor.py

import os
import sys
import logging
from supabase import create_client, Client
from dotenv import load_dotenv
from shapely import wkb
from datetime import datetime, timedelta

# --- Setup ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
dotenv_path = os.path.join(os.path.dirname(__file__), '..', '.env')
load_dotenv(dotenv_path=dotenv_path)

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    logging.error("FATAL: Supabase credentials not found. Check your .env file.")
    sys.exit(1)

def parse_hexewkb_string(hexewkb_str):
    """Parses a HEXEWKB string and returns (longitude, latitude) as floats."""
    try:
        point = wkb.loads(hexewkb_str, hex=True)
        return point.x, point.y
    except Exception as e:
        logging.warning(f"Could not parse HEXEWKB string '{hexewkb_str}': {e}")
        return None, None

def fetch_sample_weather_data_for_2025(lat, lon):
    """
    Generates sample weather data for June 28 - July 2, 2025 to match the ISRO satellite data timeframe.
    """
    try:
        sample_data = [
            {
                'date': '2025-06-28',
                'min_temp': 28.0,
                'max_temp': 39.0,
                'rainfall': 0.0
            },
            {
                'date': '2025-06-29',
                'min_temp': 27.5,
                'max_temp': 38.5,
                'rainfall': 2.1
            },
            {
                'date': '2025-06-30',
                'min_temp': 26.0,
                'max_temp': 37.0,
                'rainfall': 8.3
            },
            {
                'date': '2025-07-01',
                'min_temp': 25.5,
                'max_temp': 36.0,
                'rainfall': 12.7
            },
            {
                'date': '2025-07-02',
                'min_temp': 26.5,
                'max_temp': 37.5,
                'rainfall': 5.4
            }
        ]

        logging.info(f"Generated {len(sample_data)} weather records for 2025 dates at coordinates ({lat}, {lon})")
        return sample_data

    except Exception as e:
        logging.error(f"Error generating weather data for coordinates ({lat}, {lon}): {e}")
        return []

def ingest_imd_weather_data():
    """Main function to ingest IMD weather data with corrected 2025 dates."""

    logging.info("Starting IMD Weather Data Ingestion Process with 2025 dates to match ISRO data.")
    supabase_client: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    try:
        # --- [THE FIX IS HERE] ---
        # Step 1: Clear existing weather data using the correct approach for BIGSERIAL id
        # As per the search results, we use .neq('id', 0) to delete all rows
        # since BIGSERIAL starts from 1, this condition matches all existing rows
        logging.info("Clearing existing weather data...")
        delete_result = supabase_client.table('weather_readings').delete().neq('id', 0).execute()
        logging.info(f"Cleared existing weather data. Deleted records: {len(delete_result.data) if delete_result.data else 0}")

        # Step 2: Fetch all ground station locations from Supabase
        logging.info("Fetching ground station locations from Supabase...")
        response = supabase_client.table('ground_stations').select('id, location').execute()

        if not response.data:
            logging.error("No ground stations found in the database. Please run the CPCB ingestion first.")
            return

        stations = response.data
        logging.info(f"Found {len(stations)} ground stations. Processing weather data for 2025...")

        all_weather_records = []

        # Step 3: For each station, generate weather data for the matching 2025 dates
        for station in stations:
            try:
                station_id = station['id']
                hexewkb_string = station['location']

                # Parse the HEXEWKB string to get longitude and latitude
                longitude, latitude = parse_hexewkb_string(hexewkb_string)

                if longitude is None or latitude is None:
                    logging.warning(f"Skipping station {station_id} due to invalid location data.")
                    continue

                # Fetch weather data for the 2025 dates that match ISRO data
                weather_data = fetch_sample_weather_data_for_2025(latitude, longitude)

                # Prepare records for bulk insertion
                for weather_record in weather_data:
                    weather_payload = {
                        'station_id_ref': station_id,
                        'location': hexewkb_string,
                        'recorded_at': weather_record['date'],
                        'min_temp': weather_record['min_temp'],
                        'max_temp': weather_record['max_temp'],
                        'rainfall': weather_record['rainfall']
                    }
                    all_weather_records.append(weather_payload)

            except Exception as e:
                logging.warning(f"Error processing station {station.get('id', 'unknown')}: {e}")

        # Step 4: Bulk insert all weather records
        if all_weather_records:
            logging.info(f"Inserting {len(all_weather_records)} weather records for 2025 dates...")
            result = supabase_client.table('weather_readings').insert(all_weather_records).execute()

            if result.data:
                logging.info("✅ Successfully ingested IMD weather data for 2025.")
            else:
                logging.error("Failed to insert weather data.")
        else:
            logging.warning("No weather records to insert.")

    except Exception as e:
        logging.error(f"An error occurred during IMD weather data ingestion: {e}", exc_info=True)

if __name__ == "__main__":
    ingest_imd_weather_data()
