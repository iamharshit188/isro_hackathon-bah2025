# processing/create_realistic_dataset.py - FINAL FIXED VERSION

import pandas as pd
import numpy as np
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def create_realistic_calibration_dataset():
    """Create calibration dataset with CORRECT AOD scale matching real satellite data"""
    
    logging.info("Creating calibration dataset with realistic AOD scale...")
    
    np.random.seed(42)
    num_samples = 2000
    
    # *** FIX: Use AOD range that matches your ACTUAL satellite data ***
    satellite_aod = np.random.uniform(50, 1500, num_samples)  # Matches your real range!
    min_temp = np.random.uniform(18, 35, num_samples)
    max_temp = min_temp + np.random.uniform(5, 15, num_samples)
    rainfall = np.random.choice([0, 0, 0, 0, 1, 2, 5, 10], num_samples)
    
    # Create realistic PM2.5 relationship (adjusted for larger AOD scale)
    ground_truth_pm25 = (
        20 +                                    # Base level
        0.12 * satellite_aod +                 # Scaled properly for large AOD values
        0.8 * (max_temp - min_temp) +          # Temperature effect
        -4 * np.sqrt(rainfall) +               # Rain reduces PM2.5
        np.random.normal(0, 15, num_samples)   # Natural variation
    )
    
    # Clip to realistic PM2.5 bounds
    ground_truth_pm25 = np.clip(ground_truth_pm25, 10, 300)
    
    # Create DataFrame
    df = pd.DataFrame({
        'date': pd.date_range('2025-06-28', periods=num_samples, freq='h').date,
        'ground_truth_pm25': ground_truth_pm25,
        'satellite_aod': satellite_aod,
        'min_temp': min_temp,
        'max_temp': max_temp,
        'rainfall': rainfall
    })
    
    # Save to CSV
    output_path = 'calibration_data.csv'
    df.to_csv(output_path, index=False)
    
    logging.info(f"✅ Created realistic dataset with {len(df)} samples")
    logging.info(f"AOD range: {df['satellite_aod'].min():.1f} to {df['satellite_aod'].max():.1f}")
    logging.info(f"PM2.5 range: {df['ground_truth_pm25'].min():.2f} to {df['ground_truth_pm25'].max():.2f}")
    logging.info(f"AOD-PM2.5 correlation: {df['satellite_aod'].corr(df['ground_truth_pm25']):.3f}")
    logging.info(f"Saved to '{output_path}'")

if __name__ == "__main__":
    create_realistic_calibration_dataset()

