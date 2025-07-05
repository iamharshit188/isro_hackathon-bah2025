// api/routes/aqi.js

const express = require("express");
const { createClient } = require("@supabase/supabase-js");
const axios = require("axios");
const router = express.Router();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

router.get("/realtime", async (req, res) => {
  const { lat, lon } = req.query;

  if (!lat || !lon) {
    return res
      .status(400)
      .json({ error: "Latitude and longitude are required" });
  }

  try {
    console.log(`Calling get_fused_aqi with lat: ${lat}, lon: ${lon}`);

    const { data: fusedData, error: rpcError } = await supabase.rpc(
      "get_fused_aqi",
      {
        target_lat: parseFloat(lat),
        target_lon: parseFloat(lon),
      },
    );

    if (rpcError) throw rpcError;
    if (!fusedData) {
      return res
        .status(404)
        .json({ message: "No data found for this location." });
    }

    let finalData = Array.isArray(fusedData) ? fusedData[0] : fusedData;
    console.log("Received data:", JSON.stringify(finalData, null, 2));

    if (finalData.source === "satellite") {
      console.log("Satellite data detected. Calling calibration API...");

      try {
        const calibrationPayload = {
          satellite_aod: finalData.aqi,
          min_temp: finalData.weather?.min_temp || 25.0,
          max_temp: finalData.weather?.max_temp || 35.0,
          rainfall: finalData.weather?.rainfall || 0.0,
        };

        console.log("Sending to calibration API:", calibrationPayload);

        const calibrationResponse = await axios.post(
          "http://localhost:5001/calibrate",
          calibrationPayload,
          {
            timeout: 5000,
            headers: { "Content-Type": "application/json" },
          },
        );

        console.log("Calibration response:", calibrationResponse.data);

        // Update with calibrated data
        finalData.aqi = calibrationResponse.data.calibrated_pm25;
        finalData.source = "satellite_calibrated";
        finalData.pollutant_type = "PM2.5 (ML Calibrated)";

        console.log(
          "Calibration successful! Calibrated PM2.5:",
          calibrationResponse.data.calibrated_pm25,
        );
      } catch (calibrationError) {
        console.error("Calibration API failed:", calibrationError.message);
        finalData.pollutant_type = "AOD (Raw - Calibration Unavailable)";
        finalData.calibration_status = "failed";
      }
    } else {
      console.log(
        `Ground station data detected. Source: ${finalData.source}`,
      );
      finalData.pollutant_type = "PM2.5 (Ground Station)";
    }

    console.log(
      "Sending final response:",
      JSON.stringify(finalData, null, 2),
    );
    res.json(finalData);
  } catch (err) {
    console.error("API Error:", err.message);
    res.status(500).json({
      error: "An internal server error occurred.",
      details: err.message,
    });
  }
});

module.exports = router;
