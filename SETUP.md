# VoiceMind: A Voice-Based Agent AI Companion for Mental Health Support - Setup Guide

## Prerequisites

Before you begin, ensure you have the following installed:

### 1. Flutter SDK
- Download from [flutter.dev](https://flutter.dev)
- Minimum version: 3.10.8
- Verify installation:
  ```bash
  flutter doctor
  ```

### 2. Python
- Version 3.11 or higher
- Verify installation:
  ```bash
  python --version
  ```

### 3. Development Tools
- **For iOS:** Xcode 15+ (macOS only)
- **For Android:** Android Studio with Android SDK
- **Code Editor:** VS Code (recommended) or Android Studio

### 4. API Keys
- **Gemini API Key**: Get from [Google AI Studio](https://aistudio.google.com/app/apikey)
  - Sign in with Google account
  - Create new API key
  - Copy and save it securely

---

## 🚀 Installation Steps

### Step 1: Clone or Navigate to Project
```bash
git clone https://github.com/<your-username>/voicemind.git
cd voicemind
```

### Step 2: Backend Setup

#### 2.1 Navigate to backend folder
```bash
cd backend
```

#### 2.2 Create virtual environment
```bash
# macOS/Linux
python3 -m venv venv
source venv/bin/activate

# Windows
python -m venv venv
venv\Scripts\activate
```

#### 2.3 Install Python dependencies
```bash
pip install -r requirements.txt
```

#### 2.4 Configure environment variables
```bash
# Copy example env file
cp .env.example .env

# Edit .env file (use nano, vim, or your favorite editor)
nano .env
```

Add your Gemini API key. See `backend/.env.example` for full comments.

**REST + ADK (`/chat`, etc.):** set `GEMINI_API_KEY` from [Google AI Studio](https://aistudio.google.com/app/apikey).

```env
GEMINI_API_KEY=your_actual_api_key_here
PORT=8000
HOST=0.0.0.0
DEBUG=True

# Optional — leave blank if you don't need Firestore-backed event logging
FIREBASE_PROJECT=
ADMIN_EMAIL=
```

#### 2.5 Test backend
```bash
python main.py
```

You should see:
```
INFO:     Started server process
INFO:     Uvicorn running on http://0.0.0.0:8000
```

Visit `http://localhost:8000` to see API status.

**Keep this terminal running** and open a new terminal for Flutter setup.

---

### Step 3: Flutter App Setup

#### 3.1 Navigate to project root (new terminal)
```bash
cd path/to/voicemind
```

#### 3.2 Install Flutter dependencies
```bash
flutter pub get
```

#### 3.3 Configure Firebase

VoiceMind uses Firebase Auth (Google Sign-In) and Cloud Firestore (profile
sync, admin event logging). The generated config files
(`lib/firebase_options.dart`, `android/app/google-services.json`,
`ios/Runner/GoogleService-Info.plist`, `macos/Runner/GoogleService-Info.plist`,
and `firebase.json`) are gitignored — you generate them yourself against your
own Firebase project.

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com).
2. Enable **Authentication → Google sign-in** and **Cloud Firestore**.
3. Install the FlutterFire CLI and configure:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This writes all the config files locally. See
[`lib/firebase_options.example.dart`](lib/firebase_options.example.dart) for
the expected shape of the generated `firebase_options.dart`.

If you don't need Firebase (e.g. quick local-only demo), you can stub
`lib/firebase_options.dart` with placeholder values — auth/Firestore calls
will simply fail gracefully and the rest of the app still works.

> **Bundle IDs:** the iOS/macOS projects ship with `com.example.voicemind` and
> the Android namespace is `com.example.final_project` (legacy scaffold name).
> Change these to your own bundle ID before publishing to a store.

#### 3.4 Configure Backend URL

VoiceMind reads `BACKEND_URL` from Flutter `--dart-define` (preferred), with a fallback in [lib/src/common/constants.dart](lib/src/common/constants.dart).

**Recommended (no code edits):**
```bash
flutter run -d chrome --dart-define=BACKEND_URL=http://localhost:8000
```

**Optional fallback:** edit the default in [lib/src/common/constants.dart](lib/src/common/constants.dart).

**Finding your IP address:**
- macOS: `ifconfig | grep "inet " | grep -v 127.0.0.1`
- Windows: `ipconfig` (look for IPv4 Address)
- Linux: `ip addr show`

#### 3.5 Run the app

**One-command launch (recommended):**
```bash
./run.sh web      # Chrome (web)
./run.sh ios      # Wired iPhone (default)
./run.sh android  # Android device/emulator
```

The script auto-detects your IP, passes `BACKEND_URL` via `--dart-define`, starts the backend, and launches Flutter.

**Manual launch:**
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# Web
flutter run -d chrome

# Physical device
flutter run
```

---

## 🔧 Troubleshooting

### Issue: "GEMINI_API_KEY not set"
**Solution:** Make sure `.env` file exists in `backend/` with your API key.

### Issue: Flutter dependencies fail
**Solution:** 
```bash
flutter clean
flutter pub get
```

### Issue: Web build errors (`livekit_client`, `connectivity_plus`, `web_plugin_registrant`)
Those packages are not in this app’s `pubspec.yaml`. The errors are almost always **stale generated files** after removing dependencies or switching branches.

**Solution:**
```bash
cd /path/to/final-project
flutter clean
flutter pub get
flutter build web
# or: flutter run -d chrome
```

### Issue: Can't connect to backend from app
**Solution:** 
1. Verify backend is running (`http://localhost:8000`)
2. Check the `BACKEND_URL` value passed via `--dart-define`
3. For physical devices, ensure phone and computer on same WiFi

### Issue: Voice recognition not working
**Solution:** 
- Grant microphone permissions when prompted
- iOS: Settings → Privacy → Microphone → VoiceMind
- Android: Settings → Apps → VoiceMind → Permissions

### Issue: Text-to-Speech not working
**Solution:** 
- Check device volume
- iOS: Download voice data (Settings → Accessibility → Spoken Content)
- Android: Install Google Text-to-Speech from Play Store

---

## 📱 Platform-Specific Setup

### iOS Additional Steps
1. Open `ios/Runner.xcworkspace` in Xcode
2. Update Bundle Identifier (com.yourname.voicemind)
3. Add microphone permission in `ios/Runner/Info.plist`:
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>VoiceMind needs microphone access for voice conversations</string>
   <key>NSSpeechRecognitionUsageDescription</key>
   <string>VoiceMind uses speech recognition to understand you</string>
   ```

### Android Additional Steps
1. Update package name in `android/app/build.gradle`
2. Permissions already added in manifest (microphone, internet)
3. Increase minSdkVersion if needed (should be 21+)

---

## 🧪 Testing

### Test Backend Endpoints

```bash
# Health check
curl http://localhost:8000/

# Test chat (from terminal)
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"transcript": "I feel anxious", "emotion": "anxious"}'

# Get helplines
curl http://localhost:8000/helplines
```

### Test Flutter App
1. Tap microphone button
2. Say "I'm feeling stressed"
3. Should see transcript appear
4. AI response should play via TTS
5. Check emotion indicator updates

### Backend tests
```bash
cd backend
source venv/bin/activate
pytest tests/ -v
```

Tests that hit the real Gemini API (`test_chat_*`, `test_full_journey`) require
`GEMINI_API_KEY` to be set in `backend/.env`. The other tests run offline.

---

## 🎯 Usage Guide

### First Time Setup
1. Launch app
2. Tap profile icon (top right)
3. Enter your name, age group, and main concerns
4. Save profile

### Having a Conversation
1. **Tap to speak**: Press and hold mic button
2. **Speak naturally**: Share your feelings
3. **Release**: AI processes your message
4. **Listen**: Response plays automatically
5. **Alternative**: Shake phone to activate mic

### Profile Features
- Add coping strategies that work
- Mark strategies that don't help
- AI avoids suggesting failed strategies

### Crisis Support
- Say any crisis keywords → Immediate helpline access
- Anytime: Tap help icon (top right) for helplines

---

## 🔄 Updates & Maintenance

### Update Dependencies
```bash
# Backend
cd backend
pip install --upgrade -r requirements.txt

# Flutter
cd ..
flutter pub upgrade
```

### Pull Latest Changes
```bash
git pull origin main
flutter clean && flutter pub get
cd backend && pip install -r requirements.txt
```

---

## 🚀 Production Deployment (Future)

### Backend
- Deploy to Google Cloud Run, AWS Lambda, or Heroku
- Update `BACKEND_URL` to the production URL
- Use environment-specific .env files

### Flutter App
- **iOS**: Submit to App Store via Xcode
- **Android**: Build APK/AAB for Google Play
- Update backend URL before building release

---

## 📞 Support

Having issues? Check:
1. Backend is running: `http://localhost:8000`
2. Flutter dependencies installed: `flutter doctor`
3. API key is valid in `.env`
4. Permissions granted for mic/speech

Still stuck? Open an issue on GitHub with:
- Platform (iOS/Android)
- Error message
- Steps to reproduce

---

Happy mental wellness journey! 💚
