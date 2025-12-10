# National Heritage Monitoring and Registration System

A cross-platform application for field survey and registration tasks based on the Korea Heritage Service Open API. Built with Flutter frontend and FastAPI backend, this comprehensive management system integrates AI-based damage detection capabilities and Firebase real-time database.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Key Features](#key-features)
- [Technology Stack](#technology-stack)
- [System Architecture](#system-architecture)
- [AI Model Details](#ai-model-details)
- [Data Structure](#data-structure)
- [Main Screens and Workflow](#main-screens-and-workflow)
- [Installation and Setup](#installation-and-setup)
- [Deployment Guide](#deployment-guide)
- [API Documentation](#api-documentation)

---

## Project Overview

### Purpose
This system provides integrated management capabilities for systematic monitoring and preservation of national heritage sites by digitizing field survey data and automatically analyzing damage conditions using AI technology.

### Core Value Propositions
- **Digital Transformation**: Converting paper-based survey records to digital database
- **AI Automation**: Improving survey efficiency through image-based damage detection
- **Real-time Collaboration**: Supporting real-time data synchronization and collaboration via Firebase
- **Cross-platform**: Providing consistent experience across Web, Android, and iOS platforms

### Collaborators
This project is a collaborative effort between:
- **Natural Language Learning Lab, Jeonbuk National University** (https://sites.google.com/view/nlllab/main)
- **Korea Heritage Service**

---

## Key Features

### 1. Heritage Search and Retrieval
- **Multi-criteria Search**: Search by designation type (National Treasure, Treasure, Historic Site, etc.), region, and keyword (heritage name)
- **Korea Heritage Service Open API Integration**: Real-time cultural heritage information retrieval
- **Infinite Scroll Pagination**: Efficient loading of large datasets
- **Manual Registration Support**: Direct registration of cultural heritage not available in OpenAPI

### 2. Detailed Information Management
- **Basic Information Display**: Designation type, designation date, owner, manager, location, coordinates, etc.
- **Three-tier Tab Structure**:
  - **Field Survey**: Basic information, metadata, location status, current photos, damage surveys
  - **Inspector Comments**: Preservation management history, survey results, preservation items, management items
  - **Comprehensive Diagnosis**: Damage summary, inspector comments review, grade classification, AI prediction

### 3. Damage Survey (Core Feature)
#### 3.1 AI-based Automatic Damage Detection
- **Four Damage Type Detection**:
  - Splitting (Gallem)
  - Cracking (Crack)
  - Decay (Buhu)
  - Crushing/Bursting (Damage)
- **Bounding Box Visualization**: Direct display of detected damage regions on images
- **Confidence Scoring**: AI confidence display for each detection result (0-1 scale)
- **Automatic Grade Assignment**: Automatic assignment of grades A-D based on detection results

#### 3.2 Survey Process
1. **Survey Registration**: Select component name, component number, and orientation
2. **Photo Capture/Selection**: Select image from camera or gallery
3. **AI Automatic Analysis**: Image transmission to server → AI model inference → Result return
4. **Result Verification**: Verify detection results with bounding boxes
5. **Information Input**: Enter damage location, damage phenomenon, inspector opinion, grade
6. **Save**: Store image, detection results, and metadata in Firebase

#### 3.3 Damage Survey UI
- **Statistics Dashboard**: Total surveys, detected damages, grade distribution
- **Interactive Table**: Display survey list in table format (selection, photo, location, damage type, grade, survey datetime, opinion)
- **Thumbnail Card View**: 4:3 fixed ratio thumbnails, bounding box overlay, full-screen viewer on click
- **Full-screen Viewer**: Original image, all bounding boxes, metadata display

### 4. Current Photo Management
- **Photo Upload**: Image storage in Firebase Storage
- **Real-time Stream**: Reflect Firestore real-time updates
- **Image Optimization**: Resizing and caching through proxy
- **Delete Function**: Simultaneous deletion of document and storage files

### 5. Inspector Comment Management
- **Section-based Edit Control**: Requires switching to edit mode after saving
- **Modification History Tracking**: Store modifier, changed fields, timestamp in Firebase
- **Real-time History Viewing**: Real-time modification history display through StreamBuilder
- **Automatic Preservation Items Connection**: Damage survey data automatically reflected in preservation items

### 6. Preservation Management History
- **History Loading**: Synchronize existing preservation management history data
- **Firebase Integration**: Real-time history data retrieval and display

---

## Technology Stack

### Frontend
- **Flutter 3.35.1** (Dart 3.9.0)
  - Cross-platform development (Web, Android, iOS)
  - Material Design 3
  - Responsive layout (ResponsivePage, LayoutBuilder)
- **Firebase**
  - **Firestore**: Real-time database (survey data, history management)
  - **Storage**: Image file storage and management
  - **StreamBuilder**: Real-time data synchronization
- **State Management**: StatefulWidget, ChangeNotifier, ViewModel pattern
- **Image Processing**: OptimizedImage (caching, resizing), ImagePicker

### Backend
- **FastAPI** (Python 3.10+)
  - RESTful API server
  - XML to JSON conversion (Korea Heritage Service API)
  - CORS middleware
  - Automatic Swagger/ReDoc documentation
- **AI/ML**
  - **PyTorch**: Deep learning framework
  - **DETA (Detection Transformer)**: Object detection model
    - Backbone: ResNet-50
    - Task: Traditional Korean architecture damage region detection
    - Number of classes: 4 (Splitting, Cracking, Decay, Crushing/Bursting)
  - **Transformers**: DetaImageProcessor
  - **Torchvision**: NMS (Non-Maximum Suppression)

### Infrastructure
- **Docker**: Containerization and deployment
- **Docker Compose**: Multi-container orchestration
- **Nginx**: Reverse proxy and static file serving

---

## System Architecture

### Overall Structure
```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Client (Web/Android/iOS)          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  UI Layer    │  │  State Mgmt  │  │  Services    │     │
│  │  (Screens,   │  │  (ViewModels)│  │  (Firebase,  │     │
│  │   Widgets)   │  │              │  │   API)       │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTP/REST
                            │
┌─────────────────────────────────────────────────────────────┐
│              FastAPI Backend (Port 8080)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Heritage    │  │  AI Service  │  │  Image       │     │
│  │  API Proxy   │  │  (PyTorch)   │  │  Processing  │     │
│  │  (XML→JSON)  │  │              │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
         │                              │
         │                              │
    ┌────▼────┐                    ┌────▼────┐
    │  Korea  │                    │ Firebase │
    │Heritage │                    │ Firestore│
    │ Service │                    │ Storage  │
    │Open API │                    │          │
    │  (XML)  │                    │          │
    └──────────┘                    └──────────┘
```

### Data Flow

#### 1. Heritage Search
```
User Input (designation type/region/keyword)
    ↓
Flutter: HeritageApi.searchHeritage()
    ↓
FastAPI: /heritage/list
    ↓
Korea Heritage Service Open API (XML)
    ↓
FastAPI: XML → JSON conversion
    ↓
Flutter: List display
```

#### 2. Damage Survey (AI Detection)
```
User: Photo selection/capture
    ↓
Flutter: ImagePicker → Uint8List
    ↓
Flutter: AiDetectionService.detectDamage()
    ↓
FastAPI: POST /ai/damage/infer (multipart/form-data)
    ↓
AI Service: Image preprocessing (DetaImageProcessor)
    ↓
PyTorch Model: CustomDeta inference
    ↓
Post-processing: Class-wise Threshold → NMS
    ↓
Result return: {detections, grade, explanation}
    ↓
Flutter: Bounding box visualization
    ↓
User: Information input (location, phenomenon, opinion)
    ↓
Firebase: Firestore + Storage save
```

#### 3. Real-time Data Synchronization
```
Firebase Firestore change
    ↓
StreamBuilder automatic update
    ↓
UI automatic rebuild
    ↓
Real-time reflection to user
```

---

## AI Model Details

### Model Architecture
- **Base Model**: DETA (Detection Transformer)
- **Backbone Network**: ResNet-50
- **Task Type**: Object Detection
- **Input**: RGB image (arbitrary size)
- **Output**: Bounding box + Class + Confidence score

### Detection Classes
| ID | Class Name | Korean Name | Threshold |
|----|-----------|-------------|-----------|
| 0 | LABEL_0 | Splitting | 0.30 |
| 1 | LABEL_1 | Cracking | 0.25 |
| 2 | LABEL_2 | Decay | 0.15 |
| 3 | LABEL_3 | Crushing/Bursting | 0.25 |

### Processing Pipeline

#### 1. Image Preprocessing
```python
Image bytes → PIL Image (RGB) → DetaImageProcessor
→ pixel_values tensor (with batch dimension)
```

#### 2. Model Inference
```python
pixel_values → CustomDeta model → Object detection results
```

#### 3. Post-processing
1. **Initial Filtering**: Extract candidates with low threshold (0.05)
2. **Class-wise Threshold Application**: Apply different criteria for each damage type
3. **NMS (Non-Maximum Suppression)**: 
   - IoU threshold: 0.1
   - Independent application per class
   - Removal of duplicate detections

#### 4. Grade Assignment
| Confidence Range | Grade | Description |
|-----------------|-------|-------------|
| ≥ 0.85 | D | Severe damage, immediate repair required |
| 0.75 ~ 0.85 | C2 | Clear damage, monitoring and preventive measures needed |
| 0.6 ~ 0.75 | C1 | Minor damage, regular observation required |
| 0.5 ~ 0.6 | B | Suspected damage, continuous observation needed |
| < 0.5 | A | Almost no abnormal signs |

### Response Format
```json
{
  "detections": [
    {
      "label": "Cracking",
      "label_id": 1,
      "score": 0.85,
      "bbox": [x1, y1, x2, y2]
    }
  ],
  "count": 3,
  "grade": "C2",
  "explanation": "Clear cracking damage observed. Monitoring and preventive measures are required."
}
```

### Model Files
- **Location**: `server/ai/hanok_damage_model.pth` (default)
- **Size**: Approximately 552MB
- **Format**: PyTorch checkpoint
- **Auto-detection**: Automatic loading from environment variable `MODEL_PATH` or default path

---

## Data Structure

### Firebase Firestore Structure

#### 1. Heritage Collection
```
heritages/
  {heritageId}/
    ├── damage_surveys/          # Damage surveys
    │   └── {surveyId}/
    │       ├── imageUrl: string
    │       ├── detections: array
    │       ├── location: string
    │       ├── phenomenon: string
    │       ├── severityGrade: string (A~F)
    │       ├── inspectorOpinion: string
    │       ├── timestamp: string (ISO8601)
    │       └── ...
    │
    ├── photos/                  # Current photos
    │   └── {photoId}/
    │       ├── url: string
    │       ├── timestamp: string
    │       └── ...
    │
    ├── detail_surveys/          # Detailed surveys
    │   └── {surveyId}/
    │       └── ...
    │
    └── edit_history/            # Edit history
        └── {historyId}/
            ├── sectionType: string
            ├── editor: string
            ├── changedFields: array
            └── timestamp: Timestamp
```

#### 2. Damage Survey Document Structure
```dart
{
  'imageUrl': 'https://firebasestorage...',
  'url': 'https://firebasestorage...',  // Same (compatibility)
  'detections': [
    {
      'label': 'Cracking',
      'label_id': 1,
      'score': 0.85,
      'bbox': [x1, y1, x2, y2]  // Absolute coordinates (pixels)
    }
  ],
  'location': 'East wall',
  'phenomenon': 'Vertical crack',
  'severityGrade': 'C2',
  'inspectorOpinion': 'Inspector opinion...',
  'timestamp': '2024-01-15T10:30:00Z',
  'width': 1920,   // Original image width
  'height': 1080,  // Original image height
  'heritageName': 'Bulguksa Temple',
  'desc': 'Damage survey'
}
```

#### 3. Edit History Document Structure
```dart
{
  'sectionType': 'inspectionResult' | 'preservationItems' | 'management',
  'editor': 'Manager name',
  'changedFields': ['field1', 'field2'],
  'timestamp': Timestamp,
  'createdAt': '2024-01-15T10:30:00Z'
}
```

### Firebase Storage Structure
```
gs://{bucket}/
  heritages/
    {heritageId}/
      ├── damage_surveys/
      │   └── {uuid}.jpg
      └── photos/
          └── {uuid}.jpg
```

---

## Main Screens and Workflow

### 1. Login Screen
- **Function**: Access with administrator account
- **Validation**: Simple entry validation (Firebase Auth integration recommended for production)

### 2. Home Screen
- **Function**: Provides "Survey and Registration System" button
- **Navigation**: Move to heritage search screen

### 3. Heritage Search Screen
- **Search Criteria**:
  - Designation type (National Treasure, Treasure, Historic Site, Natural Monument, etc.)
  - Region (Seoul, Jeonbuk, Gyeongnam, etc.)
  - Keyword (heritage name)
- **Display Information**: Designation type | Heritage name | Location | Address
- **Functions**:
  - Infinite scroll pagination
  - Item click → Move to detail screen
  - Manual registration (cultural heritage not in OpenAPI)

### 4. Basic Information Detail Screen (Core)

#### 4.1 Tab Structure
- **Field Survey** (Tab 1)
  - Basic information
  - Metadata (survey date, surveying organization, surveyor)
  - Location status
  - Current photos (Firebase Storage integration)
  - Damage survey (including AI detection)

- **Inspector Comments** (Tab 2)
  - Preservation management history (load button)
  - Survey results (editable/read-only control)
  - Preservation items (automatic damage survey connection)
  - Management items (editable/read-only control)
  - Edit history (Firebase real-time viewing)

- **Comprehensive Diagnosis** (Tab 3)
  - Damage summary
  - Inspector comments review
  - Grade classification
  - AI prediction function

#### 4.2 Damage Survey Section
- **Statistics Dashboard**:
  - Total surveys
  - Detected damages
  - Grade distribution (A, B, C1, C2, D)
- **Interactive Table**:
  - Selection (radio button)
  - Photo (thumbnail)
  - Location
  - Damage type
  - Grade (color badge)
  - Survey datetime (YYYY-MM-DD HH:mm)
  - Inspector opinion (with detection count badge)
- **Thumbnail Card View**:
  - 4:3 fixed ratio
  - Bounding box overlay
  - Display location, damage phenomenon, detection count, date
  - Full-screen viewer on click
- **Buttons**:
  - Register survey
  - Advanced survey (selection required)

#### 4.3 Damage Survey Dialog
1. **Survey Registration Step**:
   - Select component name
   - Enter component number
   - Select orientation
2. **Damage Survey Step**:
   - Display previous year survey photo (if available)
   - Register current survey photo (camera/gallery)
   - AI automatic analysis (loading display)
   - Bounding box visualization
3. **Detection Result Verification**:
   - List of detected damages
   - Confidence scores
   - Automatic grade assignment
4. **Information Input**:
   - Damage location
   - Damage phenomenon
   - Damage classification (standard terminology selection)
   - Damage grade (A~F)
   - Inspector opinion
5. **Save**: Store all data in Firebase

---

## Installation and Setup

### Prerequisites
- **Flutter**: 3.35.1 or higher
- **Dart**: 3.9.0 or higher
- **Python**: 3.10 or higher
- **Firebase Project**: Firestore and Storage setup complete

### 1. Clone Repository
```bash
git clone <repository-url>
cd heritage_services_app
```

### 2. Backend Server Setup

#### 2.1 Install Dependencies
```bash
cd server
python3 -m pip install -r requirements.txt
```

#### 2.2 Place AI Model File
```bash
# Copy model file to server/ai/ directory
cp /path/to/model.pth server/ai/hanok_damage_model.pth
```

#### 2.3 Environment Variable Setup (Optional)
```bash
export MODEL_PATH="/path/to/model.pth"  # Specify model path
export API_BASE="http://localhost:8080"  # API base address
```

#### 2.4 Run Server
```bash
# Method 1: Using script (recommended)
./run_server.sh

# Method 2: Direct execution
python3 -m uvicorn main:app --host 0.0.0.0 --port 8080 --reload

# Method 3: Python execution
python3 main.py
```

#### 2.5 Verify Server Status
```bash
curl http://localhost:8080/health
# Response: {"ok": true}
```

### 3. Flutter App Setup

#### 3.1 Install Dependencies
```bash
cd my_cross_app
flutter pub get
```

#### 3.2 Firebase Setup
1. Place `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files
2. Verify `lib/firebase_options.dart` file (automatically generated)

#### 3.3 Environment Variable Setup
Set API address in `lib/core/config/env.dart` file:
```dart
static const String proxyBase = 'http://localhost:8080';
static const String aiBase = 'http://localhost:8080';
```

Or specify during build:
```bash
flutter run -d chrome \
  --dart-define=API_BASE=http://localhost:8080 \
  --dart-define=AI_BASE=http://localhost:8080
```

#### 3.4 Run App
```bash
# Web
flutter run -d chrome

# Android
flutter run -d android

# iOS
flutter run -d ios
```

### 4. Development Mode
- **Hot Reload**: Automatic reflection on code changes (press 'r')
- **Hot Restart**: Full restart (press 'R')
- **Server Auto-restart**: Use `--reload` option

---

## Deployment Guide

### Using Docker Compose (Recommended)

#### 1. Build and Run
```bash
# Flutter web build
cd my_cross_app
flutter build web --release

# Run entire stack with Docker Compose
cd ..
docker-compose up -d --build
```

#### 2. Verify Services
- **Web App**: http://localhost:80
- **API Server**: http://localhost:8080
- **API Documentation**: http://localhost:8080/docs

#### 3. View Logs
```bash
docker-compose logs -f heritage-web
docker-compose logs -f heritage-api
```

#### 4. Redeploy
```bash
# Rebuild web app only
cd my_cross_app
flutter build web --release
cd ..
docker-compose restart heritage-web

# Full rebuild
docker-compose up -d --build
```

### Manual Deployment

#### 1. Backend Deployment
```bash
cd server
# Production mode (4 workers)
uvicorn main:app --host 0.0.0.0 --port 8080 --workers 4
```

#### 2. Frontend Deployment
```bash
cd my_cross_app
flutter build web --release
# Deploy build/web directory to web server
```

---

## API Documentation

### Basic Information
- **Server Address**: `http://localhost:8080`
- **Swagger UI**: `http://localhost:8080/docs`
- **ReDoc**: `http://localhost:8080/redoc`

### Main Endpoints

#### 1. Health Check
```http
GET /health
```
**Response**:
```json
{"ok": true}
```

#### 2. Heritage List Retrieval
```http
GET /heritage/list?keyword={heritage_name}&kind={designation_code}&region={region_code}&page=1&size=20
```
**Example**:
```bash
curl "http://localhost:8080/heritage/list?keyword=bulguksa&page=1&size=10"
```

#### 3. Heritage Detail Information
```http
GET /heritage/detail?ccbaKdcd={designation_code}&ccbaAsno={designation_number}&ccbaCtcd={city_code}
```

#### 4. AI Model Status Check
```http
GET /ai/model/status
```
**Response**:
```json
{
  "loaded": true,
  "model_path": "server/ai/hanok_damage_model.pth",
  "num_classes": 4,
  "device": "cuda"
}
```

#### 5. AI Damage Detection
```http
POST /ai/damage/infer
Content-Type: multipart/form-data

file: <image file>
```
**Response**:
```json
{
  "detections": [
    {
      "label": "Cracking",
      "label_id": 1,
      "score": 0.85,
      "bbox": [100, 200, 300, 400]
    }
  ],
  "count": 1,
  "grade": "C2",
  "explanation": "Clear cracking damage observed..."
}
```

---

## Troubleshooting

### 1. Model Load Failure
**Symptom**: `[AI] Model file not found!`

**Solution**:
1. Verify model file exists in `server/ai/` directory
2. Check if file extension is `.pth` or `.pt`
3. Verify `MODEL_PATH` environment variable

### 2. CORS Error
**Symptom**: CORS-related error in browser console

**Solution**:
- Verify FastAPI server CORS configuration (`common/middleware.py`)
- Confirm proxy address usage

### 3. Firebase Connection Failure
**Symptom**: Firestore data not loading

**Solution**:
1. Verify `google-services.json` file
2. Check Firebase project configuration
3. Verify Firestore rules (development mode: allow read/write)

### 4. Image Upload Failure
**Symptom**: Firebase Storage upload error

**Solution**:
1. Verify Storage rules
2. Check CORS configuration (`firebase_storage_cors.json`)
3. Verify network connection

---

## Additional Documentation

- [QUICKSTART.md](./QUICKSTART.md) - 3-minute quick start guide
- [DOCKER_DEPLOYMENT.md](./DOCKER_DEPLOYMENT.md) - Detailed Docker deployment guide
- [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) - Detailed project structure
- [server/README.md](./server/README.md) - Server API documentation
- [server/ai/README_MODEL.md](./server/ai/README_MODEL.md) - Detailed AI model guide

---

## Roadmap

### Short-term (Completed)
- Heritage search and detailed information retrieval
- AI-based damage detection
- Firebase real-time data synchronization
- Damage survey UI/UX improvement
- Edit history tracking

### Mid-term (In Progress)
- Server-side designation type/region code provision
- Representative image addition to detail screen
- Preservation management history API integration
- Advanced AI prediction capabilities

### Long-term (Planned)
- Damage map visualization
- Mobile app optimization
- Offline mode support
- Multi-language support

---

## License

This project is intended for internal use.

---

## Contributing

Please submit suggestions for project improvements and bug reports through the issue tracker.

---

**Last Updated**: November 2025
