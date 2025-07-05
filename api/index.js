const express = require('express');
const path = require('path');
const dotenv = require('dotenv');

// Try loading .env from the API directory first
const localEnvPath = path.resolve(__dirname, '.env');
const parentEnvPath = path.resolve(__dirname, '../.env');

// Load .env files, with parent directory taking precedence
dotenv.config({ path: localEnvPath });
dotenv.config({ path: parentEnvPath });

// Add environment variable check
const requiredEnvVars = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'];
const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingVars.length > 0) {
    console.error('Missing required environment variables:', missingVars);
    console.error('Please check your .env files at:');
    console.error(`- ${localEnvPath}`);
    console.error(`- ${parentEnvPath}`);
    process.exit(1);
}

const aqiRoutes = require('./routes/aqi');

const app = express();

// Global logging middleware
app.use((req, res, next) => {
    console.log(`[Server Log] Incoming Request: ${req.method} ${req.originalUrl}`);
    next();
});

app.use(express.json());
app.use('/api/v1/aqi', aqiRoutes);

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
    console.log(`API Server is running on http://localhost:${PORT}`);
    console.log('Environment Status:');
    console.log(`- SUPABASE_URL: ${process.env.SUPABASE_URL ? 'Set' : 'Missing'}`);
    console.log(`- SUPABASE_ANON_KEY: ${process.env.SUPABASE_ANON_KEY ? 'Set' : 'Missing'}`);
});
