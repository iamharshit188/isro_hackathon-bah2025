# processing/advanced_feature_engineering.py

import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import r2_score, mean_absolute_error
import joblib
import logging

logging.basicConfig(level=logging.INFO)

def create_advanced_features(df):
    """Add sophisticated features based on atmospheric science research"""
    
    # Make a copy to avoid modifying original
    df = df.copy()
    
    # Ensure we have the date column
    if 'recorded_at' in df.columns:
        df['recorded_at'] = pd.to_datetime(df['recorded_at'])
    elif 'date' in df.columns:
        df['recorded_at'] = pd.to_datetime(df['date'])
    else:
        # Create a default date column for testing
        df['recorded_at'] = pd.date_range(start='2025-06-01', periods=len(df), freq='H')
    
    # Temporal features (from LSTM research)
    df['hour'] = df['recorded_at'].dt.hour
    df['day_of_week'] = df['recorded_at'].dt.dayofweek
    df['month'] = df['recorded_at'].dt.month
    df['is_weekend'] = df['day_of_week'].isin([5, 6]).astype(int)
    
    # Time of day categories
    df['time_category'] = pd.cut(df['hour'], 
                                bins=[0, 6, 12, 18, 24], 
                                labels=['night', 'morning', 'afternoon', 'evening'],
                                include_lowest=True)
    
    # Meteorological interactions (proven important)
    df['temp_range'] = df['max_temp'] - df['min_temp']
    df['avg_temp'] = (df['max_temp'] + df['min_temp']) / 2
    
    # Add humidity and pressure interactions if available
    if 'humidity' in df.columns:
        if 'pressure' in df.columns:
            df['humidity_pressure'] = df['humidity'] * df['pressure']
        df['temp_humidity'] = df['avg_temp'] * df['humidity']
    else:
        # Create synthetic humidity based on temperature and rainfall
        df['humidity'] = 50 + (df['max_temp'] - 25) * -1.5 + df['rainfall'] * 2
        df['humidity'] = np.clip(df['humidity'], 20, 90)
    
    # AOD transformations (from atmospheric science)
    df['aod_log'] = np.log1p(df['satellite_aod'])
    df['aod_squared'] = df['satellite_aod'] ** 2
    df['aod_sqrt'] = np.sqrt(df['satellite_aod'])
    
    # Weather-AOD interactions
    df['aod_temp_interaction'] = df['satellite_aod'] * df['avg_temp']
    df['aod_rainfall_interaction'] = df['satellite_aod'] * (1 + df['rainfall'])
    
    # Sort by date for lag features
    df = df.sort_values('recorded_at')
    
    # Lag features (temporal dependencies)
    for lag in [1, 2, 3, 6, 12, 24]:  # Include hourly lags
        df[f'aod_lag_{lag}'] = df['satellite_aod'].shift(lag)
        if 'ground_truth_pm25' in df.columns:
            df[f'pm25_lag_{lag}'] = df['ground_truth_pm25'].shift(lag)
    
    # Rolling averages (smoothing)
    for window in [3, 6, 12, 24]:  # Multiple window sizes
        df[f'aod_rolling_{window}'] = df['satellite_aod'].rolling(window, min_periods=1).mean()
        df[f'temp_rolling_{window}'] = df['avg_temp'].rolling(window, min_periods=1).mean()
    
    # Volatility features
    df['aod_volatility_3h'] = df['satellite_aod'].rolling(3, min_periods=1).std()
    df['temp_volatility_6h'] = df['avg_temp'].rolling(6, min_periods=1).std()
    
    # Seasonal features
    df['day_of_year'] = df['recorded_at'].dt.dayofyear
    df['season_sin'] = np.sin(2 * np.pi * df['day_of_year'] / 365.25)
    df['season_cos'] = np.cos(2 * np.pi * df['day_of_year'] / 365.25)
    
    # Diurnal patterns
    df['hour_sin'] = np.sin(2 * np.pi * df['hour'] / 24)
    df['hour_cos'] = np.cos(2 * np.pi * df['hour'] / 24)
    
    # Fill any remaining NaN values
    df = df.fillna(method='bfill').fillna(method='ffill')
    
    return df

def get_advanced_feature_list():
    """Return list of advanced features for model training"""
    
    base_features = ['satellite_aod', 'min_temp', 'max_temp', 'rainfall']
    
    advanced_features = [
        # Temporal
        'hour', 'day_of_week', 'month', 'is_weekend',
        'hour_sin', 'hour_cos', 'season_sin', 'season_cos',
        
        # Meteorological
        'temp_range', 'avg_temp', 'humidity',
        
        # AOD transformations
        'aod_log', 'aod_squared', 'aod_sqrt',
        
        # Interactions
        'aod_temp_interaction', 'aod_rainfall_interaction',
        
        # Lag features (last 3 hours)
        'aod_lag_1', 'aod_lag_2', 'aod_lag_3',
        
        # Rolling averages (shorter windows for responsiveness)
        'aod_rolling_3', 'aod_rolling_6', 'temp_rolling_3',
        
        # Volatility
        'aod_volatility_3h'
    ]
    
    return base_features + advanced_features

def train_advanced_model():
    """Train model with advanced features"""
    
    try:
        logging.info("Loading and processing data with advanced features...")
        
        # Load base data
        df = pd.read_csv('processing/calibration_data.csv')
        
        # Create advanced features
        df_advanced = create_advanced_features(df)
        
        # Get feature list
        feature_list = get_advanced_feature_list()
        
        # Filter features that actually exist in the dataframe
        available_features = [f for f in feature_list if f in df_advanced.columns]
        logging.info(f"Using {len(available_features)} features: {available_features[:10]}...")
        
        # Prepare data
        X = df_advanced[available_features]
        y = df_advanced['ground_truth_pm25']
        
        # Remove any rows with NaN
        mask = ~(X.isnull().any(axis=1) | y.isnull())
        X = X[mask]
        y = y[mask]
        
        logging.info(f"Training data shape: {X.shape}")
        
        # Scale features
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X_scaled, y, test_size=0.2, random_state=42
        )
        
        # Train advanced model
        logging.info("Training advanced GradientBoosting model...")
        model = GradientBoostingRegressor(
            n_estimators=500,
            learning_rate=0.05,
            max_depth=6,
            min_samples_split=20,
            min_samples_leaf=10,
            subsample=0.8,
            random_state=42
        )
        
        model.fit(X_train, y_train)
        
        # Evaluate
        train_pred = model.predict(X_train)
        test_pred = model.predict(X_test)
        
        train_r2 = r2_score(y_train, train_pred)
        test_r2 = r2_score(y_test, test_pred)
        train_mae = mean_absolute_error(y_train, train_pred)
        test_mae = mean_absolute_error(y_test, test_pred)
        
        logging.info(f"\n🎯 Advanced Model Performance:")
        logging.info(f"  Training R²: {train_r2:.4f}, MAE: {train_mae:.2f}")
        logging.info(f"  Testing R²: {test_r2:.4f}, MAE: {test_mae:.2f}")
        
        # Feature importance
        feature_importance = model.feature_importances_
        feature_names = available_features
        
        # Sort by importance
        importance_pairs = list(zip(feature_names, feature_importance))
        importance_pairs.sort(key=lambda x: x[1], reverse=True)
        
        logging.info("\n📊 Top 10 Most Important Features:")
        for i, (name, importance) in enumerate(importance_pairs[:10]):
            logging.info(f"  {i+1:2d}. {name:25s}: {importance:.4f}")
        
        # Save model and related components
        joblib.dump(model, 'processing/advanced_calibrator.pkl')
        joblib.dump(scaler, 'processing/advanced_scaler.pkl')
        joblib.dump(available_features, 'processing/advanced_features.pkl')
        
        logging.info("\n✅ Advanced model saved successfully!")
        
        return model, scaler, available_features
        
    except Exception as e:
        logging.error(f"Error training advanced model: {e}")
        return None, None, None

def test_advanced_model():
    """Test the advanced model"""
    try:
        # Load model components
        model = joblib.load('processing/advanced_calibrator.pkl')
        scaler = joblib.load('processing/advanced_scaler.pkl')
        features = joblib.load('processing/advanced_features.pkl')
        
        logging.info(f"✅ Loaded advanced model with {len(features)} features")
        
        # Create test data
        test_data = pd.DataFrame({
            'satellite_aod': [300, 600, 1200],
            'min_temp': [20, 25, 35],
            'max_temp': [30, 35, 45],
            'rainfall': [0, 0, 0],
            'date': pd.date_range('2025-07-01', periods=3, freq='H')
        })
        
        # Add advanced features
        test_advanced = create_advanced_features(test_data)
        
        # Extract required features
        X_test = test_advanced[features].fillna(0)
        X_test_scaled = scaler.transform(X_test)
        
        # Predict
        predictions = model.predict(X_test_scaled)
        
        print("\n🧪 Advanced Model Test Results:")
        for i, (aod, pred) in enumerate(zip(test_data['satellite_aod'], predictions)):
            print(f"  AOD {aod:4d} → PM2.5 {pred:6.2f}")
        
        return True
        
    except Exception as e:
        logging.error(f"Error testing advanced model: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Training advanced feature model...")
    model, scaler, features = train_advanced_model()
    
    if model:
        print("\n🧪 Testing advanced model...")
        test_advanced_model()

