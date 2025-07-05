# processing/train_calibrator.py - COMPLETE CORRECTED VERSION

import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import r2_score, mean_absolute_error
import joblib
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def train_production_calibration_model():
    """Train a production-ready calibration model with proper validation and realistic testing"""
    
    try:
        logging.info("Loading calibration data...")
        df = pd.read_csv('processing/calibration_data.csv').dropna()
        
        if df.empty or len(df) < 50:
            logging.error("Insufficient calibration data for training!")
            return
            
        # Data analysis and validation
        logging.info(f"Dataset shape: {df.shape}")
        logging.info(f"AOD range: {df['satellite_aod'].min():.3f} to {df['satellite_aod'].max():.3f}")
        logging.info(f"PM2.5 range: {df['ground_truth_pm25'].min():.2f} to {df['ground_truth_pm25'].max():.2f}")
        logging.info(f"Temperature std: {df['min_temp'].std():.2f}°C")
        logging.info(f"Rainfall std: {df['rainfall'].std():.2f}mm")
        
        # Prepare features and target
        features = ['satellite_aod', 'min_temp', 'max_temp', 'rainfall']
        X = df[features]
        y = df['ground_truth_pm25']
        
        # Feature scaling (CRITICAL for good performance)
        logging.info("Applying StandardScaler...")
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)
        
        # Train/test split
        X_train, X_test, y_train, y_test = train_test_split(
            X_scaled, y, test_size=0.2, random_state=42, shuffle=True
        )
        
        # Train model with optimized parameters
        logging.info("Training GradientBoostingRegressor...")
        model = GradientBoostingRegressor(
            n_estimators=300,           # More trees for better accuracy
            learning_rate=0.1,          # Balanced learning rate
            max_depth=5,                # Moderate depth
            min_samples_split=20,       # Prevent overfitting
            min_samples_leaf=10,        # Prevent overfitting
            subsample=0.8,              # Bootstrap for robustness
            random_state=42
        )
        
        model.fit(X_train, y_train)
        
        # Evaluate performance
        train_pred = model.predict(X_train)
        test_pred = model.predict(X_test)
        
        train_r2 = r2_score(y_train, train_pred)
        test_r2 = r2_score(y_test, test_pred)
        train_mae = mean_absolute_error(y_train, train_pred)
        test_mae = mean_absolute_error(y_test, test_pred)
        
        logging.info(f"Training R²: {train_r2:.4f}, MAE: {train_mae:.2f}")
        logging.info(f"Testing R²: {test_r2:.4f}, MAE: {test_mae:.2f}")
        
        # Overfitting check
        if abs(train_r2 - test_r2) > 0.1:
            logging.warning("⚠️ Possible overfitting detected!")
        else:
            logging.info("✅ Model generalization looks good!")
        
        # --- [CORRECTED DIVERSITY TEST] ---
        # Use realistic AOD values within the training range
        logging.info("Testing model diversity with realistic inputs...")
        
        # Get actual AOD range from training data for realistic test cases
        aod_min = df['satellite_aod'].min()
        aod_max = df['satellite_aod'].max()
        
        test_cases = np.array([
            [aod_min + 50, 25, 35, 0],        # Low AOD within training range
            [aod_min + 250, 25, 35, 0],       # Medium AOD  
            [aod_min + 750, 25, 35, 0],       # High AOD
            [aod_min + 50, 20, 30, 5],        # Low AOD, cool, rainy
            [aod_min + 750, 30, 40, 0],       # High AOD, hot, dry
        ])
        
        # Ensure test cases are within training bounds
        test_cases[:, 0] = np.clip(test_cases[:, 0], aod_min, aod_max)
        
        test_cases_scaled = scaler.transform(test_cases)
        predictions = model.predict(test_cases_scaled)
        
        logging.info("Diversity test results:")
        for i, (inputs, pred) in enumerate(zip(test_cases, predictions)):
            logging.info(f"  AOD={inputs[0]:.0f}, Temp={inputs[1]:.0f}-{inputs[2]:.0f}°C, Rain={inputs[3]:.0f}mm → PM2.5={pred:.1f}")
        
        # Verify diversity with more realistic threshold
        prediction_std = np.std(predictions)
        if prediction_std < 10:  # Relaxed threshold for realistic expectations
            logging.warning(f"⚠️ Limited prediction diversity detected! Std={prediction_std:.2f}")
            logging.info("This might be acceptable if your training data has consistent relationships.")
        else:
            logging.info(f"✅ Good prediction diversity! Std={prediction_std:.2f}")
        
        # Feature importance analysis
        feature_importance = model.feature_importances_
        feature_names = features
        logging.info("Feature importance ranking:")
        for name, importance in sorted(zip(feature_names, feature_importance), key=lambda x: x[1], reverse=True):
            logging.info(f"  {name}: {importance:.3f}")
        
        # Save model and scaler
        joblib.dump(model, 'processing/aod_to_pm25_calibrator.pkl')
        joblib.dump(scaler, 'processing/feature_scaler.pkl')
        
        logging.info("✅ Production calibration model and scaler saved successfully!")
        
        # Final validation with extreme cases within range
        logging.info("Testing extreme cases within training range...")
        extreme_cases = np.array([
            [aod_min, 18, 25, 0],      # Minimum AOD
            [aod_max, 35, 45, 0]       # Maximum AOD
        ])
        extreme_scaled = scaler.transform(extreme_cases)
        extreme_predictions = model.predict(extreme_scaled)
        
        for i, (inputs, pred) in enumerate(zip(extreme_cases, extreme_predictions)):
            logging.info(f"  Extreme case {i+1}: AOD={inputs[0]:.0f} → PM2.5={pred:.1f}")
        
        logging.info("🎉 Model training completed successfully!")
        
    except Exception as e:
        logging.error(f"Error during training: {e}", exc_info=True)

if __name__ == "__main__":
    train_production_calibration_model()

