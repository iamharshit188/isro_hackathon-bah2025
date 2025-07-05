# processing/debug_calibration_model.py

import pandas as pd
import joblib
import numpy as np
from sklearn.metrics import r2_score, mean_absolute_error

# Load the calibration data and model
print("🔍 Loading calibration data...")
df = pd.read_csv('calibration_data.csv')
print(f"Dataset shape: {df.shape}")
print(f"Dataset info:\n{df.describe()}")

# Check for data diversity
print("\n📊 Data Range Analysis:")
print(f"Satellite AOD range: {df['satellite_aod'].min():.3f} to {df['satellite_aod'].max():.3f}")
print(f"Ground truth PM2.5 range: {df['ground_truth_pm25'].min():.3f} to {df['ground_truth_pm25'].max():.3f}")
print(f"Temperature range: {df['min_temp'].min():.1f}°C to {df['max_temp'].max():.1f}°C")

# Load the model and test with different inputs
print("\n🤖 Testing Model Behavior:")
model = joblib.load('aod_to_pm25_calibrator.pkl')

# Test with very different input values
test_cases = [
    [0.5, 25, 35, 0],    # Low AOD
    [1.0, 25, 35, 0],    # Medium AOD
    [2.0, 25, 35, 0],    # High AOD
    [0.5, 15, 25, 5],    # Different weather
    [2.0, 35, 45, 0]     # Hot weather
]

print("Input [AOD, min_temp, max_temp, rainfall] → Predicted PM2.5")
for i, test_input in enumerate(test_cases):
    prediction = model.predict([test_input])[0]
    print(f"Test {i+1}: {test_input} → {prediction:.2f}")
