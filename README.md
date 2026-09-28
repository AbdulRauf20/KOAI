# KOAI

### Kahoot Optimization AI

KOAI is an experimental **low-latency real-time multiple-choice question answering pipeline**. The end goal: look at a quiz question on a phone screen, extract the question and options (OCR), ask an AI model, and demonstrate an automated answer action in a **local/mock quiz environment** — while measuring the latency of every stage.

> **Capture → Extract → Understand → Decide → Act → Measure**

There is **no question database**. Every question can be completely unseen; the AI answers it at runtime.

All automated-answer functionality is demonstrated against a locally created mock quiz screen only — not against any third-party quiz platform.

---

## Architecture

```text
┌─────────────────── ANDROID DEVICE ───────────────────┐
│  Mock Quiz Screen → MediaProjection Screenshot        │
│        → Crop → ML Kit OCR → Question Parser          │
│        → { question, options[] }  (~0.5 KB JSON)      │
└──────────────────────────┬────────────────────────────┘
                           │ HTTP POST /answer
┌────────────────── BACKEND (FastAPI) ──────────────────┐
│  validate → AI Engine → AIProvider interface          │
│                         └─ Groq (swappable)           │
└──────────────────────────┬────────────────────────────┘
                           │ { answer, confidence, metrics }
┌──────────────────────────┴────────────────────────────┐
│  Flutter UI: show answer → simulated tap on mock quiz │
└───────────────────────────────────────────────────────┘
```

Design decisions:

- **OCR and parsing run on-device** (ML Kit) — sending text instead of images avoids uploading ~100 KB screenshots and is the single biggest latency win.
- **The backend is a thin async proxy** — validate, call AI, validate AI output, return. No database, no state.
- **The AI provider is swappable** via the `AIProvider` interface. Current provider: Groq (`openai/gpt-oss-20b`) — lowest time-to-first-token among no-card free tiers.

## Technology stack

- **Mobile:** Flutter / Dart, Android (MediaProjection planned), Google ML Kit (planned)
- **Backend:** Python 3.12, FastAPI, Uvicorn, Pydantic, httpx (async)
- **AI:** Groq API (`openai/gpt-oss-20b`), structured JSON output
- **Testing:** pytest, flutter_test

## Project structure

```text
KOAI/
├── mobile/koai/            # Flutter app
│   └── lib/
│       ├── main.dart
│       ├── models/answer.dart
│       ├── services/api_service.dart
│       └── screens/home_screen.dart
├── backend/
│   ├── main.py             # FastAPI app + endpoints
│   ├── config.py           # settings from .env
│   ├── models/schemas.py   # Pydantic request/response models
│   ├── providers/          # AIProvider interface + Groq implementation
│   ├── services/ai_engine.py
│   └── tests/test_api.py
├── experiments/
│   └── ai_latency/         # measured latency baselines
├── docs/
└── README.md
```

## Setup

### Backend

```bash
cd backend
python3 -m venv .venv          # already exists in this repo checkout
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env           # then paste your real Groq API key
uvicorn main:app --reload
```

Environment variables (`backend/.env`, never committed):

```text
GROQ_API_KEY=your_api_key_here      # from console.groq.com
GROQ_MODEL=openai/gpt-oss-20b
```

### Flutter app

```bash
cd mobile/koai
flutter pub get
flutter run                    # pick a device: Android emulator / Linux desktop
```

Networking notes:

- **Android emulator** reaches your PC's backend via `http://10.0.2.2:8000` (handled automatically in `api_service.dart`).
- **Physical phone**: set `baseUrl` in `lib/services/api_service.dart` to your PC's LAN IP and start the backend with `uvicorn main:app --host 0.0.0.0`.
- Debug builds allow cleartext HTTP (`android:usesCleartextTraffic="true"`); remove before any HTTPS deployment.

## API

### `GET /`

```json
{ "message": "KOAI Backend is running!" }
```

### `POST /answer`

Request:

```json
{
  "question": "Which protocol is connection-oriented?",
  "options": ["UDP", "IP", "TCP", "ICMP"]
}
```

Response (`200`):

```json
{
  "answer": "C",
  "confidence": 0.99,
  "metrics": { "ai_ms": 679, "server_total_ms": 680 }
}
```

Errors: `422` invalid request (missing/blank/too many options), `502` AI provider error, `504` AI provider timeout — always structured JSON, the server never crashes on AI failure.

## Latency measurement

Rule: **never subtract timestamps from two different clocks.**

- Backend measures `ai_ms` and `server_total_ms` with `time.perf_counter()` and returns them in every response.
- Flutter measures `round_trip_ms` with a `Stopwatch`.
- Network overhead is derived: `round_trip_ms − server_total_ms`.

Current baseline (2026-09-28, 5 questions, details in `experiments/ai_latency/`):

- AI inference: 411–851 ms (mean ≈ 670 ms) — this is 99%+ of server time
- Server overhead: ~1 ms
- Accuracy: 5/5 (easy set; real benchmarking pending)

## Testing

```bash
cd backend && .venv/bin/python -m pytest tests/ -v   # 8 tests: API, validation, error handling
cd mobile/koai && flutter test                        # widget smoke test
```

Tests use fake providers injected through FastAPI dependency overrides — no API key or network needed.

## Status

**Implemented (v0.1):** manual question → FastAPI → Groq → structured answer → Flutter UI with per-stage latency display. Backend tests, provider abstraction, secrets via `.env`.

**Next:**

1. **v0.2** — Android screen capture (MediaProjection) + configurable crop
2. **v0.3** — ML Kit OCR + question parser (tolerant of `A.` / `A)` / `A -` formats)
3. **v0.4** — mock quiz screen + simulated tap; end-to-end latency breakdown
4. **v0.5+** — model benchmarking (`gpt-oss-120b` vs `20b` vs others), prompt/latency optimization

## License

To be decided.
