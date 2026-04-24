---
title: SCDO API
emoji: 🚀
colorFrom: blue
colorTo: indigo
sdk: docker
pinned: false
---

# SCDO v3.0 — Supply Chain Disruption Oracle

> **A scalable system for continuously analyzing multifaceted transit data to preemptively detect and flag potential supply chain disruptions, formulate dynamic re-routing mechanisms, and recommend optimized route adjustments before localized bottlenecks cascade into broader delays.**

## 🏗️ Architecture Overview

```
┌─────────────────┐     REST API      ┌──────────────────────────┐
│  Flutter Web UI  │ ◄──────────────► │    Flask Gateway (7860)  │
│  (Port 8080)     │                  │                          │
└─────────────────┘                   │  ┌────────────────────┐  │
                                      │  │ Routing Engine      │  │
                                      │  │ (Dijkstra + CTR)    │  │
                                      │  └────────────────────┘  │
                                      │  ┌────────────────────┐  │
                                      │  │ Risk Scoring Engine │  │
                                      │  │ (Weather+Sentiment) │  │
                                      │  └────────────────────┘  │
                                      │  ┌────────────────────┐  │
                                      │  │ Monte Carlo DES     │  │
                                      │  │ (Simulation Engine) │  │
                                      │  └────────────────────┘  │
                                      │  ┌────────────────────┐  │
                                      │  │ Firestore DB        │  │
                                      │  │ (Jobs + Profiles)   │  │
                                      │  └────────────────────┘  │
                                      └──────────────────────────┘
```

## 🔬 Key Technical Features

### 1. Multi-Modal Routing Engine
- **1,100+ city nodes** (766 Indian districts + 400 global cities/ports/airports)
- **Dijkstra-based pathfinding** with three modes: `HIGHWAY`, `SEA`, `AIR`
- **CTR Tensor Weighting** — Cost-Time-Risk dynamic edge weights: `W(e) = ω·Ĉ(e) + (1-ω)·T̂(e)`
- **Cargo-aware constraint pruning** — mode blacklists per product type, quantity thresholds
- **Route diversification** — Fastest, Cheapest, and Balanced routes with deduplication
- **Feasibility Index** — `F_idx = min(1, Budget/C) · min(1, Deadline/T)`

### 2. Risk Scoring Engine (ML/NLP)
- **Weather Risk** — Real-time weather API integration, normalized to 0–1 per-city scores
- **Sentiment Risk (NLP)** — News headline analysis via Gemini LLM for supply-chain sentiment scoring
- **Community Crowdsourced Risk** — User-submitted per-city ratings with deduplication (latest per user)
- **Non-linear combination**: `R = 1 - (1-S)(1-W) + S·W·k` with synergy amplification
- **Kill-switch** at 0.85 — auto-flags extreme-risk routes

### 3. Monte Carlo Discrete Event Simulation
- **Probabilistic delay modeling** — per-hop stochastic time/cost with risk-adjusted distributions
- **Configurable iterations** (default 1000) for confidence intervals
- **Background worker** — async job processing via Firestore queue

### 4. Smart Disruption-Aware Multi-Supplier Routing
- **Two-pass routing** — finds optimal path first, scans waypoints for disruptions, auto-blocks high-risk cities, re-routes
- **Risk threshold slider** (Strict → Cautious → Balanced → Aggressive)
- **Per-city disruption reports** with flagged reasons (weather, news sentiment, community intel)

### 5. Community Risk Feedback System
- **Upsert-based ratings** — users rate cities 1-10, latest rating per user wins
- **15% weight blending** into the combined risk score
- **72-hour expiry** for freshness

## 🖥️ Frontend (Flutter Web)

| Screen | Description |
|--------|-------------|
| **Route Simulator** | Enter origin → destination, pick cargo type, find 3 route options (fastest/cheapest/balanced), simulate with Monte Carlo, see results inline |
| **Multi-Supplier** | Add multiple supplier origins to one buyer, auto-detect disruptions, compare routes |
| **Route Comparison** | Side-by-side metric comparison across suppliers with "best route" highlighting |
| **History** | Past simulation results with polling, PDF report downloads, risk feedback dialogs |
| **Community** | Browse public supplier/buyer profiles, search by products/location |
| **Profile** | Manage your supply chain profile, delivery zones, contact info |

## 🚀 Quick Start

```bash
# Backend (Flask API Gateway)
python gateway.py

# Frontend (Flutter Web)
cd frontend_scdo_app
flutter run -d web-server --web-port 8080
```

**Backend:** http://localhost:7860  
**Frontend:** http://localhost:8080

## 📁 Project Structure

```
SCDO/
├── gateway.py              # Flask API gateway (all REST endpoints)
├── worker.py               # Background simulation job processor
├── scdo/
│   ├── config.py           # CTR constants, mode blacklists, thresholds
│   ├── db.py               # Firestore connection
│   ├── analytics.py        # Job history & analytics
│   ├── reports.py          # PDF report generation
│   ├── routing/
│   │   ├── graph.py        # Multi-modal graph + CTR Dijkstra
│   │   ├── router.py       # High-level routing API
│   │   └── cities_data.py  # 1,100+ city node definitions
│   ├── risk/
│   │   ├── weather_risk.py # Weather API risk scoring
│   │   ├── sentiment_risk.py # NLP sentiment via Gemini
│   │   └── combined_risk.py  # Non-linear risk fusion
│   └── simulation/
│       └── monte_carlo.py  # Monte Carlo DES engine
├── frontend_scdo_app/      # Flutter web application
│   └── lib/
│       ├── main.dart       # App entry + auth wrapper
│       ├── app_config.dart # API URL configuration
│       ├── screens/        # All UI screens
│       ├── theme/          # Glass morphism design system
│       └── widgets/        # Reusable glass containers
```

## 🔧 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/alternate-route` | Find fastest/cheapest/balanced routes |
| `POST` | `/api/simulate` | Queue Monte Carlo simulation |
| `POST` | `/api/simulate-path` | Find route + auto-simulate |
| `POST` | `/api/multi-supplier-routes` | Multi-supplier disruption-aware routing |
| `POST` | `/api/feedback` | Submit community risk ratings |
| `GET`  | `/api/history` | Get simulation history |
| `POST` | `/api/report` | Generate PDF report |
| `GET`  | `/api/cities` | Search available cities |
| `GET`  | `/health` | Health check |

## 📊 Mathematical Models

### CTR Edge Weight (v3.0)
```
W(e) = ω · Ĉ(e) + (1 - ω) · T̂(e)
Ĉ(e) = [F(mode,p) + Q·d·V·(1 + R·α)] / C_norm
T̂(e) = [(d/s)·(1 + R·β) + P(mode,Q)] / T_norm
```

### Combined Risk Score
```
R_base = 1 - (1-S)(1-W) + S·W·k
R_final = (1 - w_c)·R_base + w_c·C    (w_c = 0.15)
Kill-switch: if max(S,W) ≥ 0.85 → R ≥ 0.95
```

### Feasibility Index
```
F_idx = min(1, Budget/C_total) · min(1, Deadline/T_total)
```

## 🛠️ Tech Stack

- **Backend:** Python 3.10+, Flask, Firebase Admin SDK
- **Frontend:** Flutter 3.x (Web), Dart
- **Database:** Google Cloud Firestore
- **ML/NLP:** Google Gemini API (sentiment analysis)
- **APIs:** OpenWeatherMap (weather risk)
- **Design:** Glassmorphism dark theme
