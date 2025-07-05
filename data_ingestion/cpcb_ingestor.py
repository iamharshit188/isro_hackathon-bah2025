# data_ingestion/cpcb_ingestor.py

import os
import sys
import requests
import logging
from supabase import create_client, Client
from dotenv import load_dotenv
from dateutil.parser import isoparse

# --- Setup ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
dotenv_path = os.path.join(os.path.dirname(__file__), '..', '.env')
load_dotenv(dotenv_path=dotenv_path)

# --- Configuration ---
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
CPCB_API_URL = "https://api.data.gov.in/resource/3b01bcb8-0b14-4abf-b6f2-c1bfd384ba69"
CPCB_API_KEY = os.getenv("CPCB_API_KEY")

# --- [THE FIX IS HERE - Part 1] ---
# A more robust helper function to safely convert any value to a float.
def to_numeric(value):
    """
    Attempts to convert a value to a float.
    Returns None if the value is None, 'NA', an empty string, or cannot be converted.
    """
    if value is None or str(value).strip() in ['NA', '']:
        return None
    try:
        # Directly try to convert to float. This is the most Pythonic way.
        return float(value)
    except (ValueError, TypeError):
        # If any error occurs (e.g., for 'b'04-0''), it will be caught here.
        # We log it once for debugging but return None so the script doesn't crash.
        return None

def fetch_cpcb_data():
    """Fetches real-time AQI data from the CPCB data.gov.in API."""
    params = {'api-key': CPCB_API_KEY, 'format': 'json', 'limit': '1000'}
    logging.info(f"Fetching data from CPCB API: {CPCB_API_URL}")
    try:
        response = requests.get(CPCB_API_URL, params=params)
        response.raise_for_status()
        data = response.json()
        logging.info(f"Successfully fetched {len(data.get('records', []))} station records.")
        return data.get('records', [])
    except requests.exceptions.RequestException as e:
        logging.error(f"Error fetching data from CPCB API: {e}")
        return []

def process_and_store_data(supabase: Client, records: list):
    """Processes CPCB records and bulk upserts them into Supabase tables."""
    if not records:
        logging.warning("No records to process.")
        return

    # --- [THE FIX IS HERE - Part 2] ---
    # We will process all records first and then do one big database operation.
    all_readings_payload = []
    station_map = {}

    for record in records:
        try:
            station_id = record.get('station')
            if not station_id:
                logging.warning(f"Skipping record with no station ID: {record}")
                continue

            # Check if we have already processed this station
            if station_id not in station_map:
                station_info = {
                    'station_id': station_id,
                    'city': record.get('city'),
                    'state': record.get('state'),
                    'location': f"POINT({record.get('longitude')} {record.get('latitude')})"
                }
                station_response = supabase.table('ground_stations').upsert(station_info, on_conflict='station_id').execute()
                station_map[station_id] = station_response.data[0]['id']

            station_id_ref = station_map[station_id]

            # Prepare the reading data
            pollutants_str = record.get('pollutant_id', '')
            values_str = record.get('pollutant_avg', '')

            if not pollutants_str or not values_str:
                continue

            pollutants = pollutants_str.split(',')
            values = values_str.split(',')

            if len(pollutants) != len(values):
                logging.warning(f"Mismatched pollutant and value counts for station {station_id}. Skipping.")
                continue

            pollutant_map = dict(zip(pollutants, values))

            reading_data = {
                'station_id_ref': station_id_ref,
                'recorded_at': isoparse(record.get('last_update')).isoformat(),
                'pm25': to_numeric(pollutant_map.get('PM2.5')),
                'pm10': to_numeric(pollutant_map.get('PM10')),
                'no2': to_numeric(pollutant_map.get('NO2')),
                'so2': to_numeric(pollutant_map.get('SO2')),
                'co': to_numeric(pollutant_map.get('CO')),
                'o3': to_numeric(pollutant_map.get('Ozone'))
            }
            all_readings_payload.append(reading_data)

        except Exception as e:
            logging.warning(f"Skipping record due to unexpected error for station {record.get('station')}: {e}")

    if all_readings_payload:
        logging.info(f"Attempting to bulk upsert {len(all_readings_payload)} processed readings...")
        try:
            supabase.table('station_readings').upsert(all_readings_payload, on_conflict='station_id_ref,recorded_at').execute()
            logging.info("✅ Successfully upserted CPCB readings.")
        except Exception as e:
            logging.error(f"Error during bulk upsert of readings: {e}")

def main():
    """Main function to orchestrate the data ingestion process."""
    if not all([SUPABASE_URL, SUPABASE_KEY, CPCB_API_KEY]):
        logging.error("FATAL: Supabase or CPCB API credentials not found. Check your .env file.")
        sys.exit(1)

    logging.info("Initializing Supabase client...")
    supabase_client: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    cpcb_records = fetch_cpcb_data()
    process_and_store_data(supabase_client, cpcb_records)

    logging.info("CPCB data ingestion process finished.")

if __name__ == "__main__":
    main()
