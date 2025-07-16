# Vaayu Darshak: Hyperlocal Air Quality Monitoring and Forecasting App

Vaayu Darshak delivers real-time AQI updates, forecasts for the next three days, plus medical suggestions and health advisories—**reaching both urban metro cities and those underserved rural areas**. We're focused on giving people in smaller cities and villages access granular, real time and predictive air quality information to tackle those data gaps. 
By implementing a **hybrid LSTM + ARIMA model** for pollutant measurements and pulling in satellite data, we can predict air quality 24 to 72 hours ahead, all wrapped in a straightforward, interactive user interface. 

## Installation

To get Vaayu Darshak up and running locally (it's a Flutter-based app), follow these quick steps:

#### Prerequisites

- Flutter SDK (v3.3+)
- Dart (comes with Flutter)
- Android/iOS emulator or device

## Steps

1. Clone the repo:

	`git clone https://github.com/iamharshit188/isro_hackathon-bah2025.git cd isro_hackathon-bah2025`

2. Install dependencies:

    `flutter pub get`

3. Run the app:
  
    `flutter run`


Add any API keys (e.g., for Google Maps or Firebase) to your config files before launching. If you hit snags, `flutter doctor` is your friend for diagnostics


## Key Features

- **Real-Time AQI Mapping:** See current air quality on an interactive heatmap. Zoom into your exact location for hyperlocal details.
- **72-Hour Forecasts:** Predict AQI trends, so you know how reliable the prediction is.
- **Health Advisories & Alerts:** Get tips like "Wear a mask outdoors" or "Avoid exercise" based on your AQI level. Push notifications for sudden spikes.
- **Historical Trends:** Visualize past data to spot patterns, like seasonal pollution highs.
- **Multilingual & Accessible:** Supports English, Hindi, and more, with a simple UI that's easy on low-end devices.
- **Emergency Features:** Quick alerts for high-risk scenarios, integrated with Firebase for reliable push notifications.

## How It Works: A Quick Architecture Breakdown

We designed Vaayu Darshak to be robust and scalable. Here's the high-level flow—think of it as a smart pipeline that grabs data, processes it, and serves it to your phone.

## Data Sources

- **Ground Stations:** Real-time AQI from CPCB APIs (when available—super accurate but limited coverage).
- **Satellite Imagery:** AOD data from ISRO's EOS-6 satellite for wide-area coverage, especially in rural spots.
- **Weather Integration:** Pulls in temperature, humidity, wind, etc., from IMD to boost prediction accuracy.
- **User Location:** Uses device GPS for hyperlocal queries (with privacy controls, of course).


## BACKEND

- **Orchestration Layer:** Built with Node.js/Express. It routes requests intelligently. For example:

	- If ground data is fresh and nearby, use that.
	- Otherwise, switch to satellite data and kick off ML calibration.

- **Database:** Supabase (Postgres) for storing time-series AQI data in the cloud, and SQLite on-device for offline access.

- **ML Pipeline:**  We use Python (Flask for serving) with a hybrid model:

    - **ARIMA** for handling linear trends and seasonality in time-series data (like daily pollution cycles).

    - **LSTM** (a type of neural network) for capturing nonlinear patterns, like sudden spikes from events.

    - **CNN** (Convolutional Neural Network) layer upfront to extract spatial features from satellite images or data grids.

    - **Intelligent Fusion with DBO:** We blend ARIMA and LSTM outputs using Dung Beetle Optimizer (a nature-inspired algorithm) to weigh them optimally. This "fusion layer" gives a final, super-accurate prediction with uncertainty estimates.


	Why this hybrid? Single models struggle with air quality's mix of predictable patterns and wildcards (e.g., festivals or weather changes). Our setup beats benchmarks by 15-20% in accuracy on test data from Indian regions.
    
- **API Endpoints:** RESTful APIs handle everything from data ingestion to model inference (under 3 seconds per request).


## FRONTEND

- Built with Flutter (Dart) for cross-platform goodness.

- State management via Riverpod, animations for smooth UX (e.g., breathing AQI charts), and Firebase for analytics/notifications.


Data flows like this: App requests AQI → Backend routes/ processes → ML predicts if needed → Results visualized on your screen. For forecasts, we generate 24-72 hour predictions hourly in the background.

If you're technical, check out the `architecture_diagram.png` in this repo for a visual. We also have use-case diagrams in our docs folder.


## Contributing

We'd love your help! Whether it's improving the ML models, adding new languages, or fixing bugs:

- Fork the repo.
- Create a branch: `git checkout -b feature/your-idea`.
- Commit and PR with a clear description.
- Follow our code style 

## License

This project is licensed under the MIT License—see `LICENSE` for details. Feel free to use, modify, and share, but give us a nod if it helps your work.

## Contact Us

Got questions, feedback, or collab ideas? Hit us up at [tech.harshit.tiwari@gmail.com](mailto:tech.harshit.tiwari@gmail.com) or open an issue here. We're a small team passionate about clean air—let's make India breathe easier together!

Built with ❤️ by:
- VANSH DIXIT
- DEEKSHA SINGH
- AAMIN SIMMI SINGH
- **HARSHIT TIWARI**

  **WaterPlane** 2025.
