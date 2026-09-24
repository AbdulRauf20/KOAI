# KOAI

### Kahoot Optimization AI

KOAI is an experimental low-latency AI system designed to capture multiple-choice quiz questions, extract the question and options using OCR, determine the most likely answer using a combination of local knowledge and AI, and return the result as quickly as possible.

The project combines **Flutter, Python backend development, OCR, NLP/AI, Android development, and performance optimization**.

> **Read → Understand → Answer → Measure**

---

## 🚀 Project Goal

The goal of KOAI is to build a fast and reliable system capable of processing a multiple-choice question through the following pipeline:

```text
Question on Screen
       ↓
Screen Capture
       ↓
OCR
       ↓
Question Parser
       ↓
Answer Engine
   ↙          ↘
Local KB      AI
   ↘          ↙
     Answer
       ↓
Flutter UI
       ↓
Performance Metrics
```

The main focus of the project is **accuracy, speed, and measurable performance**.

---

# 🛠️ Technology Stack

## Mobile

* Flutter
* Dart
* Android
* Android MediaProjection
* Android Accessibility APIs where appropriate

## Backend

* Python
* FastAPI
* Pydantic
* REST APIs
* Async Python

## OCR

* Google ML Kit Text Recognition

## AI / NLP

* LLM API
* scikit-learn
* Sentence Transformers
* PyTorch

These technologies will be introduced gradually. The project will start with a simple local knowledge engine instead of immediately training a complex model.

## Database / Storage

Initially:

* JSON

Later:

* SQLite
* Firebase

## Development

* Git
* GitHub
* VS Code
* Postman / Thunder Client
* pytest

---

# 📁 Project Structure

```text
KOAI/
│
├── mobile/
│   └── Flutter Android application
│
├── backend/
│   ├── API
│   ├── answer engine
│   ├── OCR processing
│   └── AI integration
│
├── knowledge/
│   ├── ml.json
│   └── dbms.json
│
├── experiments/
│   ├── OCR experiments
│   ├── latency experiments
│   └── model experiments
│
├── tests/
│
├── docs/
│
├── .gitignore
├── README.md
└── LICENSE
```

---

# 🗺️ Development Roadmap

## Phase 1 — Python Backend Foundation

Build the initial backend using Python and FastAPI.

### Tasks

* [ ] Set up Python virtual environment
* [ ] Learn FastAPI basics
* [ ] Create FastAPI application
* [ ] Understand REST APIs
* [ ] Learn request/response handling
* [ ] Create Pydantic models
* [ ] Create `/answer` endpoint
* [ ] Test API using Postman or curl

### Initial API

```text
POST /answer
```

Example request:

```json
{
  "question": "What is the output range of sigmoid?",
  "options": [
    "-1 to 1",
    "0 to 1",
    "0 to infinity",
    "-infinity to infinity"
  ]
}
```

Example response:

```json
{
  "answer": "B",
  "confidence": 0.99
}
```

### Milestone

**Flutter/client → Python backend → JSON response**

---

# Phase 2 — Local Knowledge Engine

Before using an AI API, build a fast local answer engine.

Initial knowledge areas:

### Machine Learning

* Linear Regression
* Logistic Regression
* Sigmoid
* Loss Functions
* MSE
* Gradient Descent
* Classification
* Training and Testing
* Basic Neural Networks

### Database Systems

* SQL
* SELECT
* INSERT
* UPDATE
* DELETE
* Joins
* Keys
* Constraints
* Normalization
* Transactions
* ACID
* Aggregation
* Authorization

Initial knowledge will be stored in JSON files.

Example:

```json
{
  "question": "What is the output range of sigmoid?",
  "answer": "B",
  "topic": "logistic_regression"
}
```

### Milestone

A known question can be answered locally without an external AI request.

---

# Phase 3 — Flutter Application

Build the initial Android application.

### Tasks

* [ ] Create Flutter project
* [ ] Design basic KOAI interface
* [ ] Add question display
* [ ] Add answer display
* [ ] Add confidence display
* [ ] Add latency display
* [ ] Connect Flutter to FastAPI

Initial interface:

```text
+-------------------------+
|          KOAI           |
|                         |
|   Question detected     |
|                         |
|       Answer: B         |
|                         |
|   Confidence: 98%       |
|   Latency: 184 ms       |
|                         |
+-------------------------+
```

The first version will prioritize **functionality and speed over UI design**.

---

# Phase 4 — Screen Capture

Enable KOAI to capture the relevant portion of the Android screen.

### Tasks

* [ ] Research Android MediaProjection
* [ ] Implement screen capture
* [ ] Capture screenshots
* [ ] Optimize screenshot resolution
* [ ] Crop unnecessary screen regions

### Pipeline

```text
Android Screen
      ↓
Screen Capture
      ↓
Screenshot
```

### Milestone

KOAI can obtain the current quiz screen as an image.

---

# Phase 5 — OCR

Use Google ML Kit to extract text from the captured screen.

### Tasks

* [ ] Integrate ML Kit
* [ ] Send screenshot to OCR
* [ ] Extract raw text
* [ ] Test different screen sizes
* [ ] Handle OCR errors
* [ ] Measure OCR latency

Example:

```text
Screenshot
    ↓
OCR
    ↓
What is the output range of sigmoid?

A -1 to 1
B 0 to 1
C 0 to infinity
D -infinity to infinity
```

### Milestone

**Screenshot → readable text**

---

# Phase 6 — Question Parser

Convert raw OCR text into structured question data.

### Input

```text
What is the output range of sigmoid?

A -1 to 1
B 0 to 1
C 0 to infinity
D -infinity to infinity
```

### Output

```json
{
  "question": "What is the output range of sigmoid?",
  "options": {
    "A": "-1 to 1",
    "B": "0 to 1",
    "C": "0 to infinity",
    "D": "-infinity to infinity"
  }
}
```

### Tasks

* [ ] Detect question text
* [ ] Detect options
* [ ] Handle different option layouts
* [ ] Clean OCR errors
* [ ] Handle missing characters
* [ ] Validate extracted questions

### Milestone

**OCR text → structured question**

---

# Phase 7 — AI Answer Engine

Introduce an AI model as a fallback when the local knowledge engine cannot confidently answer a question.

```text
                 Question
                    ↓
             Local Knowledge
               /         \
            Found       Not Found
              ↓            ↓
           Answer       AI Model
                           ↓
                         Answer
```

The AI should return structured data.

Example:

```json
{
  "answer": "B",
  "confidence": 0.96
}
```

### Tasks

* [ ] Integrate AI API
* [ ] Design structured prompt
* [ ] Validate AI responses
* [ ] Add confidence handling
* [ ] Handle API failures
* [ ] Measure API latency
* [ ] Add fallback behavior

---

# Phase 8 — End-to-End Pipeline

Connect every component.

```text
Android Screen
      ↓
Screen Capture
      ↓
OCR
      ↓
Question Parser
      ↓
Local Knowledge Engine
      ↓
AI Fallback
      ↓
Answer
      ↓
Flutter UI
```

### Milestone

A question visible on the Android device can travel through the complete KOAI pipeline and produce an answer.

---

# Phase 9 — Dataset

Build a high-quality dataset of multiple-choice questions.

### Dataset fields

```text
question
option_A
option_B
option_C
option_D
answer
topic
difficulty
source
```

Example:

```text
What is the output range of sigmoid?
-1 to 1
0 to 1
0 to infinity
-infinity to infinity
B
Logistic Regression
Easy
Lab
```

### Initial target

**500–2,000 high-quality questions**

Potential categories:

* Machine Learning
* Database Systems
* SQL
* Computer Science fundamentals

The goal is **quality and diversity**, not simply creating a huge dataset.

---

# Phase 10 — ML / NLP Experiments

Once enough data has been collected, experiment with different answering approaches.

### Approaches

1. Rule-based knowledge engine
2. Keyword matching
3. Vector similarity
4. Embedding-based retrieval
5. LLM API
6. Small local ML/NLP model

Compare:

| Approach         | Accuracy | Latency | Cost |
| ---------------- | -------: | ------: | ---: |
| Rules            |      TBD |     TBD | Free |
| Keyword Matching |      TBD |     TBD | Free |
| Vector Search    |      TBD |     TBD | Free |
| LLM API          |      TBD |     TBD |  API |
| Local Model      |      TBD |     TBD | Free |

A trained model will only be introduced if experiments show that it provides a meaningful improvement.

---

# Phase 11 — Performance Optimization

KOAI is designed around low latency.

Measure every stage:

```text
Screen Capture
      ↓
OCR
      ↓
Parsing
      ↓
Knowledge Search
      ↓
AI Inference
      ↓
UI Response
```

Example benchmark:

```text
Capture       80 ms
OCR          120 ms
Parsing       15 ms
Knowledge      3 ms
AI           700 ms
UI            50 ms
-------------------
Total        968 ms
```

### Optimization techniques

* [ ] Crop unnecessary screen areas
* [ ] Optimize OCR input
* [ ] Cache repeated questions
* [ ] Preload knowledge
* [ ] Reduce network requests
* [ ] Use local inference where practical
* [ ] Async processing
* [ ] Persistent connections
* [ ] Smaller models
* [ ] Parallel processing where appropriate

### Goal

Minimize end-to-end latency while maintaining reliable answer accuracy.

---

# Phase 12 — Analytics

Track KOAI's performance.

Record:

```text
Question number
Detected question
Predicted answer
Correct answer
Correct / Incorrect
OCR latency
Inference latency
Total latency
Confidence
```

This allows us to identify exactly where the system is slow or making mistakes.

---

# Phase 13 — Firebase Integration

Firebase can be introduced later for the non-core application features.

Potential uses:

* Run history
* Statistics
* User accounts
* Competition records
* Leaderboards
* Performance graphs

Architecture:

```text
                 KOAI
                  │
       ┌──────────┴──────────┐
       ↓                     ↓
 Python Backend          Firebase
       │                     │
       ↓                     ↓
 Answer Engine        Statistics
 OCR                  Leaderboard
 AI                   History
```

Firebase is **not required for the initial MVP**.

---

# Phase 14 — Competition Integration

After the core system is stable, integrate it with the agreed competition environment.

The final pipeline can become:

```text
Question
    ↓
Screen Capture
    ↓
OCR
    ↓
Question Parser
    ↓
Answer Engine
    ↓
Answer
    ↓
Competition Interface
```

Performance should be recorded for every question.

---

# 🎯 Final Success Criteria

KOAI should eventually be able to:

* [ ] Capture a multiple-choice question
* [ ] Extract its text
* [ ] Identify all options
* [ ] Understand the question
* [ ] Determine the answer
* [ ] Handle unknown questions through AI
* [ ] Return results with low latency
* [ ] Measure its own performance
* [ ] Maintain a high-quality question dataset
* [ ] Compare different answering approaches
* [ ] Provide useful analytics

---

# 🧠 Development Philosophy

KOAI will follow:

> **Don't add complexity until the simpler solution stops being good enough.**

The development path is:

```text
Python Backend
      ↓
Local Knowledge
      ↓
Flutter App
      ↓
Screen Capture
      ↓
OCR
      ↓
Question Parser
      ↓
AI Fallback
      ↓
Dataset
      ↓
ML/NLP Experiments
      ↓
Performance Optimization
      ↓
Analytics
```

We will **measure before optimizing** and **experiment before training a model**.

---

# 📌 Current Status

🚧 **Under Development**

### Phase 1 — Backend Foundation

* [ ] Python environment
* [ ] FastAPI setup
* [ ] First API endpoint
* [ ] API testing

### Phase 2 — Local Knowledge Engine

* [ ] ML knowledge base
* [ ] DBMS knowledge base
* [ ] Answer matching

### Phase 3 — Flutter

* [ ] Flutter project
* [ ] Basic UI
* [ ] Backend connection

### Phase 4 — Screen Capture

* [ ] Android screen capture
* [ ] Screenshot processing

### Phase 5 — OCR

* [ ] ML Kit integration
* [ ] OCR processing

### Phase 6 — Question Parser

* [ ] Question extraction
* [ ] Option extraction
* [ ] OCR cleanup

### Phase 7 — AI

* [ ] AI API
* [ ] Structured responses
* [ ] Fallback system

### Phase 8 — Integration

* [ ] End-to-end pipeline

### Phase 9 — Dataset

* [ ] Question collection
* [ ] Dataset cleaning
* [ ] Dataset validation

### Phase 10 — ML/NLP

* [ ] Baselines
* [ ] Embeddings
* [ ] Local model experiments

### Phase 11 — Optimization

* [ ] Latency profiling
* [ ] Bottleneck identification
* [ ] Optimization

### Phase 12 — Analytics

* [ ] Performance tracking
* [ ] Statistics

### Phase 13 — Firebase

* [ ] Optional leaderboard
* [ ] History
* [ ] Analytics

### Phase 14 — Competition Integration

* [ ] Final integration
* [ ] End-to-end testing

---

## 📜 License

To be decided.
