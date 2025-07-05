from flask import Flask, request, jsonify
import joblib
import numpy as np
import pandas as pd
import logging
import os

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

processing_dir = os.path.join(os.path.dirname(__file__), '..', 'processing')
basic_model_path = os.path.join(processing_dir, 'aod_to_pm25_calibrator.pkl')
basic_scaler_path = os.path.join(processing_dir, 'feature_scaler.pkl')
ensemble_path = os.path.join(processing_dir, 'ensemble_calibrator.pkl')
advanced_model_path = os.path.join(processing_dir, 'advanced_calibrator.pkl')
advanced_scaler_path = os.path.join(processing_dir, 'advanced_scaler.pkl')
advanced_features_path = os.path.join(processing_dir, 'advanced_features.pkl')
basic_model = None
basic_scaler = None
ensemble_model = None
advanced_model = None
advanced_scaler = None
advanced_features = None

def load_models():
    """Load all available models"""
    global basic_model, basic_scaler, ensemble_model, advanced_model, advanced_scaler, advanced_features
    
    try:
        if os.path.exists(basic_model_path) and os.path.exists(basic_scaler_path):
            basic_model = joblib.load(basic_model_path)
            basic_scaler = joblib.load(basic_scaler_path)
    except Exception as e:
        logging.error(f"Error loading basic model: {e}")
    
    try:
        if os.path.exists(ensemble_path):
            ensemble_model = joblib.load(ensemble_path)
    except Exception as e:
        logging.error(f"Error loading ensemble model: {e}")
    
    try:
        if (os.path.exists(advanced_model_path) and 
            os.path.exists(advanced_scaler_path) and 
            os.path.exists(advanced_features_path)):
            advanced_model = joblib.load(advanced_model_path)
            advanced_scaler = joblib.load(advanced_scaler_path)
            advanced_features = joblib.load(advanced_features_path)
    except Exception as e:
        logging.error(f"Error loading advanced model: {e}")
    
    test_models()

def test_models():
    """Test all loaded models with sample data"""
    test_input = [300, 25, 35, 0]
    
    if basic_model and basic_scaler:
        try:
            test_scaled = basic_scaler.transform([test_input])
            basic_model.predict(test_scaled)[0]
        except Exception as e:
            logging.error(f"Basic model test failed: {e}")
    
    if ensemble_model:
        try:
            ensemble_model.predict([test_input])[0]
        except Exception as e:
            logging.error(f"Ensemble model test failed: {e}")
    
    if advanced_model and advanced_scaler and advanced_features:
        try:
            test_df = pd.DataFrame([{
                'satellite_aod': test_input[0],
                'min_temp': test_input[1],
                'max_temp': test_input[2],
                'rainfall': test_input[3],
                'date': pd.Timestamp.now()
            }])
            
            import sys
            sys.path.append(processing_dir)
            from advanced_feature_engineering import create_advanced_features
            
            test_advanced = create_advanced_features(test_df)
            X_test = test_advanced[advanced_features].fillna(0)
            X_test_scaled = advanced_scaler.transform(X_test)
            advanced_model.predict(X_test_scaled)[0]
        except Exception as e:
            logging.error(f"Advanced model test failed: {e}")

load_models()

@app.route('/calibrate', methods=['POST'])
def calibrate_aod():
    """Main calibration endpoint - uses best available model"""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No JSON data provided'}), 400
    
    if advanced_model and advanced_scaler and advanced_features:
        return calibrate_with_advanced_model(data)
    elif ensemble_model:
        return calibrate_with_ensemble_model(data)
    elif basic_model and basic_scaler:
        return calibrate_with_basic_model(data)
    else:
        return jsonify({'error': 'No models available'}), 500

def calibrate_with_basic_model(data):
    """Calibrate using basic model"""
    try:
        features = np.array([[
            data['satellite_aod'], 
            data['min_temp'], 
            data['max_temp'], 
            data['rainfall']
        ]])
        
        features_scaled = basic_scaler.transform(features)
        calibrated_pm25 = basic_model.predict(features_scaled)[0]
        
        return jsonify({
            'calibrated_pm25': round(calibrated_pm25, 2),
            'source': 'basic_model',
            'model_version': '1.0',
            'confidence': 'standard'
        })
    except Exception as e:
        return jsonify({'error': f'Basic model error: {str(e)}'}), 500

def calibrate_with_ensemble_model(data):
    """Calibrate using ensemble model"""
    try:
        features = [
            data['satellite_aod'], 
            data['min_temp'], 
            data['max_temp'], 
            data['rainfall']
        ]
        
        calibrated_pm25 = ensemble_model.predict([features])[0]
        model_info = ensemble_model.get_model_info()
        
        return jsonify({
            'calibrated_pm25': round(calibrated_pm25, 2),
            'source': 'ensemble_model',
            'model_version': '2.0',
            'confidence': 'high',
            'ensemble_weights': model_info['weights']
        })
    except Exception as e:
        return jsonify({'error': f'Ensemble model error: {str(e)}'}), 500

def calibrate_with_advanced_model(data):
    """Calibrate using advanced feature model"""
    try:
        test_df = pd.DataFrame([{
            'satellite_aod': data['satellite_aod'],
            'min_temp': data['min_temp'],
            'max_temp': data['max_temp'],
            'rainfall': data['rainfall'],
            'date': pd.Timestamp.now()
        }])
        
        import sys
        sys.path.append(processing_dir)
        from advanced_feature_engineering import create_advanced_features
        
        test_advanced = create_advanced_features(test_df)
        X_test = test_advanced[advanced_features].fillna(0)
        X_test_scaled = advanced_scaler.transform(X_test)
        
        calibrated_pm25 = advanced_model.predict(X_test_scaled)[0]
        
        return jsonify({
            'calibrated_pm25': round(calibrated_pm25, 2),
            'source': 'advanced_model',
            'model_version': '3.0',
            'confidence': 'very_high',
            'features_used': len(advanced_features)
        })
    except Exception as e:
        return jsonify({'error': f'Advanced model error: {str(e)}'}), 500

@app.route('/calibrate/basic', methods=['POST'])
def calibrate_basic():
    """Force use of basic model"""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No JSON data provided'}), 400
    
    if not (basic_model and basic_scaler):
        return jsonify({'error': 'Basic model not available'}), 500
    
    return calibrate_with_basic_model(data)

@app.route('/calibrate/ensemble', methods=['POST'])
def calibrate_ensemble():
    """Force use of ensemble model"""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No JSON data provided'}), 400
    
    if not ensemble_model:
        return jsonify({'error': 'Ensemble model not available'}), 500
    
    return calibrate_with_ensemble_model(data)

@app.route('/calibrate/advanced', methods=['POST'])
def calibrate_advanced():
    """Force use of advanced model"""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No JSON data provided'}), 400
    
    if not (advanced_model and advanced_scaler and advanced_features):
        return jsonify({'error': 'Advanced model not available'}), 500
    
    return calibrate_with_advanced_model(data)

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint with model status"""
    return jsonify({
        'status': 'healthy',
        'models_available': {
            'basic': basic_model is not None and basic_scaler is not None,
            'ensemble': ensemble_model is not None,
            'advanced': (advanced_model is not None and 
                        advanced_scaler is not None and 
                        advanced_features is not None)
        },
        'default_model': (
            'advanced' if (advanced_model and advanced_scaler and advanced_features) else
            'ensemble' if ensemble_model else
            'basic' if (basic_model and basic_scaler) else
            'none'
        )
    })

@app.route('/models/info', methods=['GET'])
def models_info():
    """Get detailed information about available models"""
    info = {
        'basic_model': {
            'available': basic_model is not None and basic_scaler is not None,
            'features': ['satellite_aod', 'min_temp', 'max_temp', 'rainfall'],
            'version': '1.0',
            'description': 'Basic GradientBoosting model'
        },
        'ensemble_model': {
            'available': ensemble_model is not None,
            'features': ['satellite_aod', 'min_temp', 'max_temp', 'rainfall'],
            'version': '2.0',
            'description': 'Ensemble of multiple algorithms'
        },
        'advanced_model': {
            'available': (advanced_model is not None and 
                         advanced_scaler is not None and 
                         advanced_features is not None),
            'features': advanced_features if advanced_features else [],
            'version': '3.0',
            'description': 'Advanced model with temporal and interaction features'
        }
    }
    
    if ensemble_model:
        try:
            model_info = ensemble_model.get_model_info()
            info['ensemble_model']['weights'] = model_info['weights']
            info['ensemble_model']['component_scores'] = model_info['scores']
        except:
            pass
    
    return jsonify(info)

@app.route('/test', methods=['GET'])
def test_endpoint():
    """Test endpoint to verify all models work"""
    test_input = {
        'satellite_aod': 300,
        'min_temp': 25,
        'max_temp': 35,
        'rainfall': 0
    }
    
    results = {}
    
    if basic_model and basic_scaler:
        try:
            result = calibrate_with_basic_model(test_input)
            results['basic'] = result.get_json()
        except Exception as e:
            results['basic'] = {'error': str(e)}
    
    if ensemble_model:
        try:
            result = calibrate_with_ensemble_model(test_input)
            results['ensemble'] = result.get_json()
        except Exception as e:
            results['ensemble'] = {'error': str(e)}
    
    if advanced_model and advanced_scaler and advanced_features:
        try:
            result = calibrate_with_advanced_model(test_input)
            results['advanced'] = result.get_json()
        except Exception as e:
            results['advanced'] = {'error': str(e)}
    
    return jsonify({
        'test_input': test_input,
        'results': results
    })

if __name__ == '__main__':
    print("Starting enhanced calibration API...")
    app.run(port=5001, debug=True)

