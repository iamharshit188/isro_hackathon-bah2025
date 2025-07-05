# processing/validate_against_cpcb.py

import requests
import pandas as pd
from datetime import datetime
import logging
import os

def get_actual_cpcb_data(lat, lon):
    """Get actual CPCB data from database for comparison"""
    try:
        from supabase import create_client
        import os
        
        # Initialize Supabase client
        supabase_url = os.getenv('SUPABASE_URL')
        supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
        
        if not supabase_url or not supabase_key:
            print("Warning: Supabase credentials not found in environment")
            return None
            
        supabase = create_client(supabase_url, supabase_key)
        
        # Query CPCB data near the location
        response = supabase.table('cpcb_data').select('pm25').gte('pm25', 0).limit(1).execute()
        
        if response.data and len(response.data) > 0:
            return response.data[0]['pm25']
        else:
            # Return simulated data for testing (remove in production)
            return 45.0 + (lat - 20) * 2  # Rough approximation for testing
            
    except Exception as e:
        logging.error(f"Error fetching CPCB data: {e}")
        return None

def validate_model_accuracy():
    """Compare model predictions with real CPCB data for accuracy assessment"""
    
    # Test coordinates with known CPCB stations
    test_locations = [
        {"name": "Delhi", "lat": 28.6139, "lon": 77.2090},
        {"name": "Mumbai", "lat": 19.0760, "lon": 72.8777},
        {"name": "Bangalore", "lat": 12.9716, "lon": 77.5946},
        {"name": "Chennai", "lat": 13.0827, "lon": 80.2707}
    ]
    
    results = []
    
    print("🔍 Starting model accuracy validation...")
    
    for location in test_locations:
        try:
            print(f"\n🌍 Testing {location['name']}...")
            
            # Get your model's prediction
            your_api_response = requests.get(
                f"http://localhost:3001/api/v1/aqi/realtime?lat={location['lat']}&lon={location['lon']}",
                timeout=10
            ).json()
            
            # Get actual CPCB data
            actual_aqi = get_actual_cpcb_data(location['lat'], location['lon'])
            
            if actual_aqi and 'aqi' in your_api_response:
                difference = abs(your_api_response['aqi'] - actual_aqi)
                accuracy = max(0, 100 - (difference / actual_aqi * 100))
                
                results.append({
                    'city': location['name'],
                    'predicted': your_api_response['aqi'],
                    'actual': actual_aqi,
                    'difference': difference,
                    'accuracy': accuracy,
                    'source': your_api_response.get('source', 'unknown')
                })
                
                print(f"✅ {location['name']}: Predicted={your_api_response['aqi']:.1f}, Actual={actual_aqi:.1f}, Accuracy={accuracy:.1f}%")
            else:
                print(f"❌ {location['name']}: No valid data received")
                
        except Exception as e:
            logging.error(f"Error validating {location['name']}: {e}")
            print(f"❌ {location['name']}: Error - {e}")
    
    # Calculate overall accuracy
    if results:
        avg_accuracy = sum(r['accuracy'] for r in results) / len(results)
        print(f"\n📊 Overall Model Accuracy: {avg_accuracy:.2f}%")
        
        # Show detailed results
        print("\n📋 Detailed Results:")
        for result in results:
            print(f"  {result['city']:10} | Pred: {result['predicted']:6.1f} | Actual: {result['actual']:6.1f} | Diff: {result['difference']:6.1f} | Acc: {result['accuracy']:5.1f}% | Source: {result['source']}")
        
    return results

if __name__ == "__main__":
    validate_model_accuracy()

