# processing/ensemble_calibrator.py

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.linear_model import LinearRegression
from sklearn.neural_network import MLPRegressor
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import r2_score, mean_absolute_error
import joblib
import logging

logging.basicConfig(level=logging.INFO)

def create_ensemble_model():
    """Create ensemble model combining multiple algorithms"""
    
    try:
        # Load data
        logging.info("Loading calibration data...")
        df = pd.read_csv('calibration_data.csv').dropna()
        
        if df.empty or len(df) < 100:
            logging.error("Insufficient data for ensemble training!")
            return None
        
        # Prepare features
        features = ['satellite_aod', 'min_temp', 'max_temp', 'rainfall']
        X = df[features]
        y = df['ground_truth_pm25']
        
        # Scale features
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X_scaled, y, test_size=0.2, random_state=42
        )
        
        # Initialize models
        models = {
            'gb': GradientBoostingRegressor(n_estimators=300, learning_rate=0.08, random_state=42),
            'rf': RandomForestRegressor(n_estimators=200, random_state=42),
            'mlp': MLPRegressor(hidden_layer_sizes=(100, 50), random_state=42, max_iter=1000),
            'linear': LinearRegression()
        }
        
        # Train all models
        trained_models = {}
        model_scores = {}
        
        logging.info("Training ensemble models...")
        
        for name, model in models.items():
            logging.info(f"Training {name}...")
            model.fit(X_train, y_train)
            trained_models[name] = model
            
            # Evaluate model
            y_pred = model.predict(X_test)
            r2 = r2_score(y_test, y_pred)
            mae = mean_absolute_error(y_test, y_pred)
            model_scores[name] = {'r2': r2, 'mae': mae}
            
            logging.info(f"  {name}: R²={r2:.4f}, MAE={mae:.2f}")
        
        # Determine optimal weights based on performance
        best_r2 = max(model_scores.values(), key=lambda x: x['r2'])['r2']
        weights = {}
        total_weight = 0
        
        for name, scores in model_scores.items():
            # Weight based on R² score (higher R² gets higher weight)
            weight = scores['r2'] / best_r2 if best_r2 > 0 else 0.25
            weights[name] = weight
            total_weight += weight
        
        # Normalize weights
        for name in weights:
            weights[name] /= total_weight
        
        logging.info(f"Optimized weights: {weights}")
        
        # Import the EnsembleModel class
        from ensemble_model import EnsembleModel
        
        # Create ensemble
        ensemble = EnsembleModel(trained_models, weights, scaler)
        ensemble.set_scores(model_scores)
        
        # Test ensemble performance
        ensemble_pred = ensemble.predict(X_test)
        ensemble_r2 = r2_score(y_test, ensemble_pred)
        ensemble_mae = mean_absolute_error(y_test, ensemble_pred)
        
        logging.info(f"\n🎯 Ensemble Performance:")
        logging.info(f"  R²: {ensemble_r2:.4f}")
        logging.info(f"  MAE: {ensemble_mae:.2f}")
        
        # Save ensemble model
        joblib.dump(ensemble, 'ensemble_calibrator.pkl')
        logging.info("✅ Ensemble model saved successfully!")
        
        return ensemble
        
    except Exception as e:
        logging.error(f"Error creating ensemble model: {e}")
        return None

def load_ensemble_model():
    """Load the trained ensemble model"""
    try:
        ensemble = joblib.load('ensemble_calibrator.pkl')
        logging.info("✅ Ensemble model loaded successfully")
        return ensemble
    except Exception as e:
        logging.error(f"Error loading ensemble model: {e}")
        return None

def test_ensemble_model():
    """Test the ensemble model with various inputs"""
    ensemble = load_ensemble_model()
    if ensemble is None:
        print("❌ Failed to load ensemble model")
        return
    
    # Test cases
    test_cases = [
        [300, 25, 35, 0],   # Low AOD
        [600, 25, 35, 0],   # Medium AOD
        [1200, 25, 35, 0],  # High AOD
        [300, 20, 30, 5],   # Cool and rainy
        [1200, 35, 45, 0],  # Hot and dry
    ]
    
    print("\n🧪 Testing Ensemble Model:")
    print("Input [AOD, min_temp, max_temp, rainfall] → Predicted PM2.5")
    
    for i, test_input in enumerate(test_cases):
        prediction = ensemble.predict([test_input])[0]
        print(f"Test {i+1}: {test_input} → {prediction:.2f}")
    
    # Show model info
    info = ensemble.get_model_info()
    print("\n📊 Model Information:")
    for model_name, weight in info['weights'].items():
        score = info['scores'][model_name]
        print(f"  {model_name}: Weight={weight:.3f}, R²={score['r2']:.4f}, MAE={score['mae']:.2f}")

if __name__ == "__main__":
    print("🚀 Creating ensemble calibration model...")
    ensemble = create_ensemble_model()
    if ensemble:
        print("\n🧪 Testing ensemble model...")
        test_ensemble_model()

