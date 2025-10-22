# Copilot Instructions for Heritage Services App

This document provides guidance for AI coding agents working on the Heritage Services App. The app integrates a Flutter-based frontend with a FastAPI backend to manage and analyze heritage data. Follow these instructions to ensure consistency and productivity.

---

## 🏗️ Project Overview

### Architecture
- **Frontend**: Flutter app located in `my_cross_app/`.
  - Key files:
    - `lib/env.dart`: Contains environment variables like `PROXY_BASE`.
    - `lib/data/heritage_api.dart`: Handles REST API calls to the backend.
    - `lib/screens/`: Contains UI screens for various app functionalities.
- **Backend**: FastAPI server located in `server/`.
  - Key files:
    - `server/main.py`: Entry point for the FastAPI application.
    - `server/heritage/`: Handles heritage-related API routes and logic.
    - `server/ai/`: Manages AI-based damage detection.
    - `server/common/`: Shared utilities like configuration and middleware.

### Data Flow
1. **Frontend**: User interacts with the Flutter app.
2. **Backend**: API requests are sent to the FastAPI server.
3. **External API**: Backend communicates with the National Heritage API (XML-based).
4. **AI Model**: Backend uses a PyTorch model for damage detection.

---

## 🔧 Developer Workflows

### Backend Setup
1. Navigate to the `server/` directory.
2. Install dependencies:
   ```bash
   python3 -m pip install -r requirements.txt
   ```
3. Run the server in development mode:
   ```bash
   python3 -m uvicorn main:app --host 0.0.0.0 --port 8080 --reload
   ```
4. Verify the server is running:
   ```bash
   curl http://localhost:8080/health
   ```

### Frontend Setup
1. Navigate to the `my_cross_app/` directory.
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

### Building the App
- **Web**:
  ```bash
  flutter build web --dart-define=PROXY_BASE=https://<backend-url>
  ```
- **Android**:
  ```bash
  flutter build apk --dart-define=PROXY_BASE=https://<backend-url>
  ```
- **iOS**:
  ```bash
  flutter build ios --dart-define=PROXY_BASE=https://<backend-url>
  ```

---

## 📂 Key Conventions

### Backend
- Use `server/common/config.py` for environment-specific configurations.
- Follow modular design:
  - `heritage/` for heritage-related logic.
  - `ai/` for AI-related logic.
  - `common/` for shared utilities.
- Ensure CORS settings are updated in `common/middleware.py`.

### Frontend
- Use `lib/env.dart` to manage environment variables.
- Organize screens under `lib/screens/`.
- Use `lib/data/heritage_api.dart` for API interactions.

---

## 🔗 Integration Points

### API Endpoints
- **Health Check**: `GET /health`
- **Heritage List**: `GET /heritage/list`
- **Heritage Detail**: `GET /heritage/detail`
- **AI Model Status**: `GET /ai/model/status`
- **AI Damage Detection**: `POST /ai/damage/infer`

### External Dependencies
- **National Heritage API**: XML-based API for heritage data.
- **AI Model**: PyTorch model located at `server/ai/hanok_damage_model.pt`.

---

## 🧩 Tips for AI Agents
- **Error Handling**: Ensure proper error handling for API calls, especially for XML parsing.
- **Testing**: Use `test/widget_test.dart` for Flutter tests and `pytest` for backend tests.
- **Performance**: Optimize AI model loading in `server/ai/loader.py`.
- **CORS**: Verify CORS settings for web compatibility.

---

For any issues or questions, refer to the project README files or consult the development team.