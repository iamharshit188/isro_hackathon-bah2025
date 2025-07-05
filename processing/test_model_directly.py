# processing/test_model_directly.py

import joblib
import numpy as np
import pandas as pd

def test_model_directly():
    """Test the trained model directly without Flask API"""
    
    try:
        print("🔍 Loading model and scaler...")
        model = joblib.load('aod_to_pm25_calibrator.pkl')
        scaler = joblib.load('feature_scaler.pkl')
        print("✅ Model and scaler loaded successfully")
        
        # Test with the exact same inputs as your API calls
        test_cases = [
            [293, 20.2, 28.1, 0],    # Your first test case
            [1191, 29.1, 36.2, 0],  # Your second test case
            [100, 25, 35, 0],       # Additional test
            [500, 25, 35, 0],       # Additional test
        ]
        
        print("\n🧪 Testing model with different AOD values:")
        print("Input: [AOD, min_temp, max_temp, rainfall] → Predicted PM2.5")
        
        for i, test_input in enumerate(test_cases):
            # Apply scaling (same as Flask API)
            input_scaled = scaler.transform([test_input])
            prediction = model.predict(input_scaled)[0]
            print(f"Test {i+1}: {test_input} → {prediction:.2f}")
        
        # Check if the model is learning AOD relationships
        # Test with same weather, different AOD
        print("\n🔍 AOD Sensitivity Test (same weather, different AOD):")
        aod_values = [100, 200, 300, 500, 1000]
        for aod in aod_values:
            input_scaled = scaler.transform([[aod, 25, 35, 0]])
            prediction = model.predict(input_scaled)[0]
            print(f"AOD {aod:4d} → PM2.5 {prediction:6.2f}")
        
        # Check the training data to see what the model learned from
        print("\n📊 Checking training data...")
        df = pd.read_csv('calibration_data.csv')
        print(f"AOD range in training: {df['satellite_aod'].min():.2f} to {df['satellite_aod'].max():.2f}")
        print(f"PM2.5 range in training: {df['ground_truth_pm25'].min():.2f} to {df['ground_truth_pm25'].max():.2f}")
        
        # Check correlation
        correlation = df['satellite_aod'].corr(df['ground_truth_pm25'])
        print(f"AOD-PM2.5 correlation in training data: {correlation:.3f}")
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    test_model_directly()

