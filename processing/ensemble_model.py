# ensemble_model.py - Define the ensemble model class

class EnsembleModel:
    def __init__(self, models, weights, scaler):
        self.models = models
        self.weights = weights
        self.scaler = scaler
        self.scores = None  # Will be set later
    
    def predict(self, X):
        # Ensure X is scaled
        if hasattr(X, 'shape') and X.shape[1] == 4:
            X_scaled = self.scaler.transform(X)
        else:
            X_scaled = X  # Assume already scaled
        
        predictions = {}
        for name, model in self.models.items():
            predictions[name] = model.predict(X_scaled)
        
        # Weighted average
        ensemble_pred = sum(
            self.weights[name] * predictions[name]
            for name in self.models.keys()
        )
        return ensemble_pred
    
    def set_scores(self, scores):
        """Set the model scores after creation"""
        self.scores = scores
    
    def get_model_info(self):
        return {
            'weights': self.weights,
            'models': list(self.models.keys()),
            'scores': self.scores
        }
