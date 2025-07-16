const express = require('express');
const router = express.Router();
const { supabase } = require('../index');

router.get('/heatmap-data', async (req, res) => {
    const { bounds, zoom_level } = req.query;

    if (!bounds || !zoom_level) {
        return res.status(400).json({ error: 'Missing required query parameters: bounds and zoom_level' });
    }

    try {
        const decodedBounds = JSON.parse(bounds);
        const { northeast, southwest } = decodedBounds;

        if (!northeast || !southwest || !northeast.lat || !northeast.lng || !southwest.lat || !southwest.lng) {
            return res.status(400).json({ error: 'Invalid bounds format' });
        }

        const latRange = northeast.lat - southwest.lat;
        const lngRange = northeast.lng - southwest.lng;

        const gridPoints = [];
        for (let i = 0; i < 10; i++) {
            for (let j = 0; j < 10; j++) {
                gridPoints.push({
                    lat: southwest.lat + latRange * (i / 9),
                    lng: southwest.lng + lngRange * (j / 9),
                });
            }
        }

        const promises = gridPoints.map(point => supabase.rpc('get_fused_aqi', { target_lat: point.lat, target_lon: point.lng }));

        const results = await Promise.all(promises);

        const heatmapPoints = results.map((result, index) => {
            if (result.data && result.data.length > 0) {
                return {
                    latitude: gridPoints[index].lat,
                    longitude: gridPoints[index].lng,
                    intensity: result.data[0].aqi_value / 500, // Normalize intensity
                    aqi_value: result.data[0].aqi_value,
                    source: result.data[0].source_type,
                    timestamp: result.data[0].recorded_at,
                };
            }
            return null;
        }).filter(p => p !== null);

        res.json({ points: heatmapPoints });
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch heatmap data' });
    }
});

module.exports = router;

