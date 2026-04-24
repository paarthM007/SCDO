# SCDO v3.0 — Supply Chain Disruption Oracle 🚀

> **A predictive, multi-modal supply chain optimization engine designed to detect disruptions before they happen and auto-reconfigure logistics paths using stochastic modeling.**

---

## 🏛️ Part I: Product & Architecture Analysis

### 1. Vision & Value Proposition
SCDO (Supply Chain Disruption Oracle) is not just a routing tool; it is a **continuous intelligence system** for logistics. In an era of volatile climate patterns, geopolitical shifts, and rapid news cycles, traditional static routing is obsolete. SCDO solves this by:
- **Preemptive Detection**: Identifying bottlenecks *before* they cascade into delays.
- **Dynamic Re-Routing**: Auto-blocking high-risk nodes (weather/sentiment) and finding alternate paths.
- **Probabilistic Forecasting**: Using Monte Carlo simulations to give users confidence intervals on arrival times and costs.

### 2. High-Level Architecture (The Triple-Engine Model)
SCDO is built on a modular, asynchronous architecture consisting of three core engines:

#### A. Multi-Modal Routing Engine (CTR Tensor)
The routing engine uses a custom implementation of **Dijkstra's Algorithm** with **CTR (Cost-Time-Risk) Tensor Weighting**. 
- **1,100+ Nodes**: Covers 766 Indian districts and 400+ global logistics hubs.
- **Modes**: Highway, Sea, and Air.
- **Math**: Edge Weight $W(e) = \omega \cdot \hat{C}(e) + (1-\omega) \cdot \hat{T}(e)$, where $\omega$ is the user-defined balance between cost and time.

#### B. Risk Fusion Engine (Non-Linear Integration)
This engine fuses three distinct data streams into a singular risk score ($R \in [0, 1]$):
1. **Weather (Physical)**: Real-time data from OpenWeatherMap API.
2. **Sentiment (Sociopolitical)**: NLP-driven analysis of global news headlines via **Google Gemini LLM**.
3. **Community (Crowdsourced)**: Real-time reports from other users in the network.
- **Synergy Formula**: $R_{base} = 1 - (1-S)(1-W) + S \cdot W \cdot k$. This ensures that if both weather and sentiment are bad, the risk amplifies non-linearly.

#### C. Monte Carlo Simulation Engine (DES)
Instead of providing a single "ETA," SCDO runs **1,000+ probabilistic simulations** for every hop.
- **Stochastic Delay Modeling**: Models delays as random variables adjusted by the local risk score.
- **Outputs**: Mean arrival time, standard deviation, and "Worst Case" scenarios.
- **Asynchronous Processing**: Jobs are enqueued via **Firestore** and processed by a background worker to ensure UI responsiveness.

### 3. UX Philosophy: Glassmorphism
The frontend is built with Flutter, utilizing a **Glassmorphic Dark Theme**. This provides a premium, "mission control" aesthetic with smooth transitions, interactive maps, and real-time polling for simulation status.

---

## 🛠️ Part II: Developer Guide (Local Setup)

Follow these steps to clone the repository and run the full stack on your local machine.

### 1. Prerequisites
- **Python 3.10+**
- **Flutter SDK 3.x**
- **Firebase Account** (Firestore enabled)
- **API Keys**: Google Gemini, OpenWeatherMap, Google Maps.

### 2. Repository Setup
```bash
git clone https://github.com/paarthM007/SCDO.git
cd SCDO
```

### 3. Backend Configuration (Python)
1. **Create Virtual Environment**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Environment Variables**:
   Copy `.env.example` to `.env` and fill in your keys:
   ```bash
   cp .env.example .env
   ```
   *Required Keys:* `GEMINI_API_KEY`, `OWM_API_KEY`, `GOOGLE_MAPS_API_KEY`.

3. **Firebase Service Account**:
   - Download your Firebase Admin SDK JSON key from the Firebase Console.
   - Save it in the root directory as `service-account-file.json`.
   - Ensure the path matches in `scdo/db.py`.

### 4. Frontend Configuration (Flutter)
1. **Install Dependencies**:
   ```bash
   cd frontend_scdo_app
   flutter pub get
   ```

2. **Firebase Setup**:
   - Initialize Firebase for the web: `flutterfire configure`.
   - Ensure `lib/firebase_options.dart` is generated.

### 5. Running the Application
You need to run two processes (Backend and Worker) and then the Frontend.

**Process 1: API Gateway (Flask)**
```bash
# In the root SCDO directory
python gateway.py
```

**Process 2: Background Worker (Simulation Listener)**
```bash
# In a new terminal
python worker.py
```

**Process 3: Flutter Web**
```bash
cd frontend_scdo_app
flutter run -d chrome
```

### 6. Project Structure Analysis
- `/scdo/routing`: The "brain" of the pathfinding logic.
- `/scdo/risk`: Integration with Gemini LLM and Weather APIs.
- `/scdo/simulation`: The Monte Carlo stochastic engine.
- `gateway.py`: The entry point for the REST API.
- `worker.py`: Listen for Firestore job requests and process them.
- `/frontend_scdo_app`: The Flutter source code (Screens, Widgets, Theme).

---

### 📝 Note for Reviewers
This system is designed for **Scalability**. The transition to a Firestore-based worker queue allows the system to handle thousands of concurrent simulation requests across different user accounts without blocking the main API thread.
