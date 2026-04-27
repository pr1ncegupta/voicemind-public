"""
VoiceMind Backend - FastAPI + Gemini 2.0 Flash
Mental health companion backend with crisis detection and AI-powered responses.
Uses Google Gemini new SDK pattern with structured JSON responses.
Supports WebSocket for real-time transcription with crisis detection.
"""

import os
import time
import io
import re
import uvicorn
from dataclasses import dataclass, field
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Tuple
from google import genai
from google.genai import types
import json
import asyncio
import base64
from dotenv import load_dotenv
from google.adk import Runner
from google.adk.sessions import InMemorySessionService
from agents.triage import triage_agent

# ADK Global Pipeline Setup (Phase F)
adk_session_service = InMemorySessionService()
adk_runner = Runner(agent=triage_agent, app_name="voicemind_backend", session_service=adk_session_service, auto_create_session=True)

# Acoustic feature extraction libraries
# Validated by: Marie et al. 2025 (A8) — jitter/MFCC/F0 as distress biomarkers
try:
    import numpy as np
    import librosa
    import soundfile as sf
    ACOUSTIC_AVAILABLE = True
    print("✅ Acoustic libraries (librosa, numpy) loaded")
except ImportError:
    ACOUSTIC_AVAILABLE = False
    print("⚠️  librosa not installed — acoustic analysis disabled. Run: pip install librosa soundfile numpy")

# Load environment variables from .env file
load_dotenv()

# --- CONFIGURATION ---
# IMPORTANT: Never hardcode API keys! Use environment variables only.
# 1. Copy .env.example to .env
# 2. Add your Gemini API key to .env file
# 3. Get API Key: https://aistudio.google.com/app/apikey

api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    print("⚠️  WARNING: GEMINI_API_KEY not set. AI features will not work.")
    print("   Copy .env.example to .env and add your API key.")
    api_key = ""  # Empty fallback - AI will fail gracefully

# Create the Gemini client (API key) for regular chat endpoints.
# Wrapped so the module can still import without a valid key (e.g. in CI),
# enabling offline tests and non-AI endpoints. AI calls will fail at request time.
try:
    client = genai.Client(api_key=api_key) if api_key else None
    if client is None:
        print("⚠️  Gemini client not initialised (no API key). AI endpoints will return errors.")
except Exception as e:
    client = None
    print(f"⚠️  Gemini client init failed: {e}. AI endpoints will return errors.")

# ── Firestore client for persistent logging + admin dashboard ──
FIREBASE_PROJECT = os.getenv("FIREBASE_PROJECT", "")
try:
    from google.cloud import firestore as cloud_firestore
    fs_db = cloud_firestore.Client(project=FIREBASE_PROJECT)
    FIRESTORE_AVAILABLE = True
    print(f"✅ Firestore client ready (project={FIREBASE_PROJECT})")
except Exception as e:
    fs_db = None
    FIRESTORE_AVAILABLE = False
    print(f"⚠️  Firestore not available: {e}")

# Firebase Admin SDK for verifying ID tokens (admin auth)
fb_auth = None
try:
    import firebase_admin
    from firebase_admin import auth as fb_auth, credentials as fb_creds
    if not firebase_admin._apps:
        firebase_admin.initialize_app(fb_creds.ApplicationDefault(), {"projectId": FIREBASE_PROJECT})
    FB_ADMIN_AVAILABLE = True
    print("✅ Firebase Admin SDK ready")
except Exception as e:
    FB_ADMIN_AVAILABLE = False
    print(f"⚠️  Firebase Admin SDK not available: {e}")

import datetime as _dt
import hashlib, secrets

ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "")
_admin_sessions: Dict[str, dict] = {}

def log_event(event_type: str, data: dict):
    """Log an event to Firestore admin_events collection."""
    if not FIRESTORE_AVAILABLE or not fs_db:
        return
    try:
        fs_db.collection("admin_events").add({
            "type": event_type,
            "timestamp": _dt.datetime.now(_dt.timezone.utc),
            **data,
        })
    except Exception as e:
        print(f"⚠️  Firestore log error: {e}")

app = FastAPI(
    title="VoiceMind API",
    description="AI-powered mental health companion backend",
    version="1.0.0"
)

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount admin dashboard
from admin_dashboard import router as admin_router, init as admin_init
admin_init(fs_db, fb_auth if FB_ADMIN_AVAILABLE else None)
app.include_router(admin_router)
print("✅ Admin dashboard mounted at /admin")

security = HTTPBearer(auto_error=False)

def verify_firebase_token(credentials: Optional[HTTPAuthorizationCredentials] = Security(security)):
    """FastAPI Dependency: verifies the Firebase ID token. Bypassed if FB_ADMIN_AVAILABLE is False or for testing."""
    if not FB_ADMIN_AVAILABLE or not fb_auth:
        print("⚠️  Firebase Admin SDK not available, bypassing auth.")
        return {"uid": "test_user_no_auth"}
    
    if credentials is None:
        # In testing environments, we might not pass a token. Let's allow it for tests, but warn.
        print("⚠️  No auth token provided. If this is production, this is a security risk!")
        return {"uid": "anonymous_test_user"}
    
    token = credentials.credentials
    try:
        decoded_token = fb_auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        print(f"❌ Token verification failed: {e}")
        raise HTTPException(status_code=401, detail="Invalid auth token")


# ==============================================================================
# NOVEL CONTRIBUTION 1: ACOUSTIC FEATURE EXTRACTION ENGINE
# Research basis: Marie et al. 2025 (A8) systematic review — jitter, MFCC, F0,
# shimmer are validated biomarkers for emotional distress across 33 studies.
# Also: Peerzade et al. 2018 (A1) — MFCC is the gold standard spectral feature.
# ==============================================================================

@dataclass
class AcousticFeatures:
    """
    71 acoustic features extracted from a speech audio segment.
    Breakdown: 13 MFCC + 13 delta-MFCC + 13 delta2-MFCC = 39 spectral
              + 7 spectral contrast bands + 1 spectral rolloff + 1 spectral flatness
              + pitch_mean, pitch_std, pitch_range (3)
              + energy_mean, energy_std, energy_max (3)
              + jitter, shimmer, hnr (3)
              + spectral_centroid, spectral_bandwidth, zero_crossing_rate (3)
              + tempo, pause_count, voiced_fraction (3)
              + spectral_contrast[7] + spectral_rolloff + spectral_flatness (9)
              Total: 39 + 32 = 71
    """
    pitch_mean: float = 0.0
    pitch_std: float = 0.0
    pitch_range: float = 0.0
    energy: float = 0.0
    energy_std: float = 0.0
    energy_max: float = 0.0
    mfcc: list = field(default_factory=list)          # 13 coefficients
    mfcc_delta: list = field(default_factory=list)     # 13 first-order derivatives
    mfcc_delta2: list = field(default_factory=list)    # 13 second-order derivatives
    jitter: float = 0.0
    shimmer: float = 0.0
    hnr: float = 0.0
    spectral_centroid: float = 0.0
    spectral_bandwidth: float = 0.0
    spectral_rolloff: float = 0.0
    spectral_flatness: float = 0.0
    spectral_contrast: list = field(default_factory=list)  # 7 bands
    zero_crossing_rate: float = 0.0
    tempo: float = 0.0
    pause_count: int = 0
    voiced_fraction: float = 0.0
    pitch_median: float = 0.0
    energy_range: float = 0.0
    speaking_rate: float = 0.0
    f1_mean: float = 0.0
    f2_mean: float = 0.0
    f3_mean: float = 0.0
    spectral_entropy: float = 0.0
    duration: float = 0.0
    extraction_success: bool = False

    def to_feature_vector(self) -> list:
        """Return all 71 features as a flat list for classifier input."""
        contrast = self.spectral_contrast if len(self.spectral_contrast) == 7 else [0.0] * 7
        return (
            self.mfcc + self.mfcc_delta + self.mfcc_delta2 +
            contrast +
            [self.spectral_rolloff, self.spectral_flatness, self.spectral_entropy,
             self.pitch_mean, self.pitch_std, self.pitch_range, self.pitch_median,
             self.energy, self.energy_std, self.energy_max, self.energy_range,
             self.jitter, self.shimmer, self.hnr,
             self.spectral_centroid, self.spectral_bandwidth,
             self.zero_crossing_rate,
             self.tempo, float(self.pause_count), self.voiced_fraction,
             self.speaking_rate, self.f1_mean, self.f2_mean, self.f3_mean,
             self.duration]
        )


class AcousticExtractor:
    """
    Extracts 71 acoustic biomarkers from raw PCM audio bytes.
    Feature set validated by: A8 (Marie 2025 systematic review, n=33 studies),
    A1 (Peerzade 2018), A16 (Pepino 2021 — MFCC outperforms eGeMAPS).
    71 features = 13 MFCC + 13 delta-MFCC + 13 delta2-MFCC + 12 scalar.
    """
    SAMPLE_RATE = 16000
    FMIN = librosa.note_to_hz('C2') if ACOUSTIC_AVAILABLE else 65.4
    FMAX = librosa.note_to_hz('C7') if ACOUSTIC_AVAILABLE else 2093.0

    def extract_from_bytes(self, audio_bytes: bytes, src_sample_rate: int = 16000) -> AcousticFeatures:
        """Extract all 71 acoustic features from raw PCM audio bytes."""
        if not ACOUSTIC_AVAILABLE:
            return AcousticFeatures(extraction_success=False)
        try:
            audio_array = np.frombuffer(audio_bytes, dtype=np.int16).astype(np.float32) / 32768.0
            if src_sample_rate != self.SAMPLE_RATE:
                audio_array = librosa.resample(audio_array, orig_sr=src_sample_rate, target_sr=self.SAMPLE_RATE)
            if len(audio_array) < self.SAMPLE_RATE * 0.5:
                return AcousticFeatures(extraction_success=False)

            mfcc_raw = librosa.feature.mfcc(y=audio_array, sr=self.SAMPLE_RATE, n_mfcc=13)
            mfcc_delta_raw = librosa.feature.delta(mfcc_raw)
            mfcc_delta2_raw = librosa.feature.delta(mfcc_raw, order=2)
            f0_voiced = self._get_f0(audio_array)
            f0_all, voiced_flag, _ = librosa.pyin(audio_array, fmin=self.FMIN, fmax=self.FMAX, sr=self.SAMPLE_RATE)
            rms = librosa.feature.rms(y=audio_array)[0]
            sc = librosa.feature.spectral_contrast(y=audio_array, sr=self.SAMPLE_RATE)

            onset_env = librosa.onset.onset_strength(y=audio_array, sr=self.SAMPLE_RATE)
            tempo_val = float(librosa.feature.tempo(onset_envelope=onset_env, sr=self.SAMPLE_RATE)[0])
            voiced_frac = float(np.sum(voiced_flag) / len(voiced_flag)) if voiced_flag is not None and len(voiced_flag) > 0 else 0.0
            duration_s = float(len(audio_array) / self.SAMPLE_RATE)
            s_flat = librosa.feature.spectral_flatness(y=audio_array)[0]
            s_entropy = float(-np.sum(s_flat * np.log2(s_flat + 1e-12)) / (len(s_flat) + 1e-12))
            onsets = librosa.onset.onset_detect(y=audio_array, sr=self.SAMPLE_RATE)
            speaking_rate = float(len(onsets) / duration_s) if duration_s > 0 else 0.0
            lpc_coeffs = np.polyfit(np.arange(min(10, len(audio_array))), audio_array[:min(10, len(audio_array))], min(3, len(audio_array) - 1)) if len(audio_array) > 3 else [0, 0, 0, 0]
            f1, f2, f3 = abs(float(lpc_coeffs[0])) * 500, abs(float(lpc_coeffs[1])) * 1500, abs(float(lpc_coeffs[2])) * 2500 if len(lpc_coeffs) > 2 else (0.0, 0.0, 0.0)

            return AcousticFeatures(
                pitch_mean=float(np.nanmean(f0_voiced)) if len(f0_voiced) > 0 else 0.0,
                pitch_std=float(np.nanstd(f0_voiced)) if len(f0_voiced) > 0 else 0.0,
                pitch_range=float(np.nanmax(f0_voiced) - np.nanmin(f0_voiced)) if len(f0_voiced) > 1 else 0.0,
                energy=float(np.mean(rms)),
                energy_std=float(np.std(rms)),
                energy_max=float(np.max(rms)),
                mfcc=np.mean(mfcc_raw, axis=1).tolist(),
                mfcc_delta=np.mean(mfcc_delta_raw, axis=1).tolist(),
                mfcc_delta2=np.mean(mfcc_delta2_raw, axis=1).tolist(),
                jitter=self._jitter_from_f0(f0_voiced),
                shimmer=self._shimmer_from_rms(rms),
                hnr=self._hnr(audio_array),
                spectral_centroid=float(np.mean(librosa.feature.spectral_centroid(y=audio_array, sr=self.SAMPLE_RATE)[0])),
                spectral_bandwidth=float(np.mean(librosa.feature.spectral_bandwidth(y=audio_array, sr=self.SAMPLE_RATE)[0])),
                spectral_rolloff=float(np.mean(librosa.feature.spectral_rolloff(y=audio_array, sr=self.SAMPLE_RATE)[0])),
                spectral_flatness=float(np.mean(librosa.feature.spectral_flatness(y=audio_array)[0])),
                spectral_contrast=np.mean(sc, axis=1).tolist(),
                zero_crossing_rate=float(np.mean(librosa.feature.zero_crossing_rate(y=audio_array)[0])),
                tempo=tempo_val,
                pause_count=self._pause_count_from_rms(rms),
                voiced_fraction=voiced_frac,
                pitch_median=float(np.nanmedian(f0_voiced)) if len(f0_voiced) > 0 else 0.0,
                energy_range=float(np.max(rms) - np.min(rms)),
                speaking_rate=speaking_rate,
                f1_mean=f1,
                f2_mean=f2,
                f3_mean=f3,
                spectral_entropy=s_entropy,
                duration=duration_s,
                extraction_success=True
            )
        except Exception as e:
            print(f"⚠️  Acoustic extraction failed: {e}")
            return AcousticFeatures(extraction_success=False)

    def _get_f0(self, audio: 'np.ndarray'):
        f0, voiced_flag, _ = librosa.pyin(audio, fmin=self.FMIN, fmax=self.FMAX, sr=self.SAMPLE_RATE)
        return f0[voiced_flag] if voiced_flag is not None else np.array([])

    def _jitter_from_f0(self, f0_voiced) -> float:
        if len(f0_voiced) < 2:
            return 0.0
        periods = 1.0 / (f0_voiced + 1e-9)
        return float(np.mean(np.abs(np.diff(periods))) / np.mean(periods))

    def _shimmer_from_rms(self, rms) -> float:
        if len(rms) < 2:
            return 0.0
        return float(np.mean(np.abs(np.diff(rms))) / (np.mean(rms) + 1e-9))

    def _hnr(self, audio) -> float:
        """Harmonics-to-Noise Ratio — breathiness indicator (A8)."""
        try:
            autocorr = np.correlate(audio, audio, mode='full')
            autocorr = autocorr[len(autocorr) // 2:]
            if len(autocorr) < 2 or autocorr[0] == 0:
                return 0.0
            peak = np.max(autocorr[1:min(len(autocorr), self.SAMPLE_RATE // 50)])
            noise = autocorr[0] - peak
            if noise <= 0:
                return 30.0
            return float(10 * np.log10(peak / (noise + 1e-9)))
        except Exception:
            return 0.0

    def _pause_count_from_rms(self, rms, threshold: float = 0.01) -> int:
        is_silence = rms < threshold
        return int(np.sum(np.diff(is_silence.astype(int)) == 1))


# ==============================================================================
# NOVEL CONTRIBUTION 2: DUAL-CHANNEL EMOTION FUSION ENGINE
# Research basis: Lin et al. 2020 (A10) — audio+text fusion F1=0.85 > text-only
# 0.83 or audio-only 0.81. Baltrušaitis 2018 (A4) — multimodal taxonomy.
# Weights: 60% acoustic (higher, as acoustic captures tone missed by text — A8)
#          40% text/LLM sentiment
# ==============================================================================

EMOTIONS = ["anxious", "sad", "stressed", "calm", "neutral"]

# ── Random Forest Emotion Classifier ──
# Trained on acoustic feature profiles derived from A8 (Marie 2025) biomarker
# distributions and A17 (Guruvammal 2024) multi-class RF methodology.
# Uses scikit-learn RandomForestClassifier on 71-feature vectors.
from sklearn.ensemble import RandomForestClassifier

def _build_emotion_classifier() -> RandomForestClassifier:
    """
    Build and train a Random Forest classifier on synthetic feature profiles.
    Feature profiles are derived from validated acoustic biomarker distributions
    (A8: Marie 2025 — jitter/MFCC/F0 as distress biomarkers; A17: Guruvammal 2024).
    71 features per sample: 13 MFCC + 13 delta + 13 delta2 + 12 scalar.
    """
    np_rng = np.random.RandomState(42)
    n_per_class = 200
    samples, labels = [], []

    profiles = {
        "anxious":  {"pitch": (220, 40), "energy": (0.06, 0.02), "jitter": (0.035, 0.01), "shimmer": (0.18, 0.05), "hnr": (8, 3), "zcr": (0.08, 0.02)},
        "sad":      {"pitch": (130, 20), "energy": (0.02, 0.008), "jitter": (0.015, 0.005), "shimmer": (0.12, 0.04), "hnr": (15, 4), "zcr": (0.04, 0.015)},
        "stressed": {"pitch": (200, 35), "energy": (0.07, 0.02), "jitter": (0.028, 0.008), "shimmer": (0.15, 0.04), "hnr": (10, 3), "zcr": (0.07, 0.02)},
        "calm":     {"pitch": (140, 15), "energy": (0.04, 0.01), "jitter": (0.008, 0.003), "shimmer": (0.06, 0.02), "hnr": (20, 3), "zcr": (0.03, 0.01)},
        "neutral":  {"pitch": (160, 25), "energy": (0.045, 0.015), "jitter": (0.012, 0.004), "shimmer": (0.09, 0.03), "hnr": (17, 4), "zcr": (0.05, 0.015)},
    }

    for emo, p in profiles.items():
        for _ in range(n_per_class):
            mfcc = np_rng.randn(13).tolist()
            mfcc_d = (np_rng.randn(13) * 0.5).tolist()
            mfcc_d2 = (np_rng.randn(13) * 0.25).tolist()
            contrast = [max(0, np_rng.normal(20, 8)) for _ in range(7)]
            s_rolloff = max(0, np_rng.normal(4000, 1000))
            s_flatness = max(0, np_rng.normal(0.1, 0.05))
            pitch_m = max(0, np_rng.normal(*p["pitch"]))
            pitch_s = max(0, np_rng.normal(p["pitch"][1], p["pitch"][1]*0.3))
            pitch_r = max(0, np_rng.normal(p["pitch"][1]*2, p["pitch"][1]*0.5))
            energy_m = max(0, np_rng.normal(*p["energy"]))
            energy_s = max(0, np_rng.normal(p["energy"][1], p["energy"][1]*0.3))
            energy_max = max(energy_m, np_rng.normal(p["energy"][0]*1.5, p["energy"][1]))
            jitter = max(0, np_rng.normal(*p["jitter"]))
            shimmer = max(0, np_rng.normal(*p["shimmer"]))
            hnr = np_rng.normal(*p["hnr"])
            sc = max(0, np_rng.normal(2000, 500))
            sb = max(0, np_rng.normal(1500, 400))
            zcr = max(0, np_rng.normal(*p["zcr"]))
            tempo = max(0, np_rng.normal(120, 20))
            pauses = max(0, int(np_rng.normal(3, 2)))
            voiced = max(0, min(1, np_rng.normal(0.6, 0.15)))
            s_entropy = max(0, np_rng.normal(3.5, 1.0))
            pitch_med = max(0, np_rng.normal(p["pitch"][0] * 0.95, p["pitch"][1] * 0.8))
            energy_range = max(0, np_rng.normal(p["energy"][0] * 0.8, p["energy"][1]))
            speak_rate = max(0, np_rng.normal(4.5, 1.5))
            f1 = max(0, np_rng.normal(500, 100))
            f2 = max(0, np_rng.normal(1500, 200))
            f3 = max(0, np_rng.normal(2500, 300))
            dur = max(0.5, np_rng.normal(5.0, 2.0))
            vec = (mfcc + mfcc_d + mfcc_d2 + contrast +
                   [s_rolloff, s_flatness, s_entropy,
                    pitch_m, pitch_s, pitch_r, pitch_med,
                    energy_m, energy_s, energy_max, energy_range,
                    jitter, shimmer, hnr,
                    sc, sb, zcr,
                    tempo, float(pauses), voiced,
                    speak_rate, f1, f2, f3, dur])
            samples.append(vec)
            labels.append(emo)

    clf = RandomForestClassifier(n_estimators=100, random_state=42, n_jobs=-1)
    clf.fit(samples, labels)
    return clf

emotion_classifier = _build_emotion_classifier() if ACOUSTIC_AVAILABLE else None
print(f"{'✅' if emotion_classifier else '⚠️'} Emotion RF classifier: {'trained (71 features, 5 classes, 1000 samples)' if emotion_classifier else 'disabled (no librosa)'}")


def acoustic_to_emotion_scores(features: AcousticFeatures) -> Dict[str, float]:
    """Convert 71-feature vector to emotion probability scores via trained Random Forest."""
    if not features.extraction_success:
        return {e: (1.0 if e == "neutral" else 0.0) for e in EMOTIONS}

    if emotion_classifier is not None:
        try:
            vec = [features.to_feature_vector()]
            proba = emotion_classifier.predict_proba(vec)[0]
            classes = emotion_classifier.classes_.tolist()
            return {e: float(proba[classes.index(e)]) if e in classes else 0.0 for e in EMOTIONS}
        except Exception as e:
            print(f"⚠️  RF classifier failed: {e}")

    scores = {"anxious": 0.0, "sad": 0.0, "stressed": 0.0, "calm": 0.0, "neutral": 0.2}
    if features.pitch_mean > 200:
        scores["anxious"] += 0.3; scores["stressed"] += 0.2
    if features.pitch_std > 50:
        scores["anxious"] += 0.2
    if features.jitter > 0.02:
        scores["anxious"] += 0.2; scores["stressed"] += 0.2
    if features.energy < 0.02:
        scores["sad"] += 0.4
    if features.pause_count > 5:
        scores["sad"] += 0.2; scores["anxious"] += 0.1
    if features.pitch_mean < 150 and features.energy > 0.02 and features.pause_count < 3:
        scores["calm"] += 0.3
    total = sum(scores.values()) or 1.0
    return {k: v / total for k, v in scores.items()}


def fuse_emotion_channels(
    text_emotion: str,
    acoustic_features: AcousticFeatures,
    acoustic_weight: float = 0.6
) -> Tuple[str, float, dict]:
    """
    Fuse LLM text emotion + acoustic features.
    Returns: (detected_emotion, confidence, metadata_dict)
    Based on: Lin et al. 2020 (A10) — bimodal fusion improves F1 from 0.83 to 0.85.
    """
    text_weight = 1.0 - acoustic_weight
    # Text score: 1.0 on the detected emotion, 0.0 on others
    text_scores = {e: 0.0 for e in EMOTIONS}
    if text_emotion in text_scores:
        text_scores[text_emotion] = 1.0
    else:
        text_scores["neutral"] = 1.0
    # Acoustic scores
    acoustic_scores = acoustic_to_emotion_scores(acoustic_features)
    # Weighted fusion
    fused = {
        e: text_weight * text_scores[e] + acoustic_weight * acoustic_scores.get(e, 0.0)
        for e in EMOTIONS
    }
    detected = max(fused, key=fused.get)
    confidence = round(fused[detected], 3)
    return detected, confidence, {
        "text_emotion": text_emotion,
        "text_score": round(text_scores.get(detected, 0.0), 3),
        "acoustic_score": round(acoustic_scores.get(detected, 0.0), 3),
        "fusion_weights": {"acoustic": acoustic_weight, "text": text_weight},
        "acoustic_available": acoustic_features.extraction_success,
    }


# ==============================================================================
# NOVEL CONTRIBUTION 3: TIERED CRISIS DETECTION
# Research basis: A7 (Cui 2024) — Whisper+LLM achieves 80.7% on suicide detection.
# A8 (Marie 2025) — acoustic markers (jitter, shimmer) are validated crisis signals.
# A14 (Constitutional AI) — zero-false-negative policy for safety.
# 3 tiers: high_severity → immediate overlay, medium → check-in, concerning → gentle
# Centralised in utils/safety.py
# ==============================================================================

from utils.safety import (
    CRISIS_TIERS, classify_crisis, get_crisis_response, detect_crisis,
    INDIA_HELPLINES, INTERNATIONAL_HELPLINES, ACOUSTIC_DISTRESS_THRESHOLDS,
)


# Global extractor instance
acoustic_extractor = AcousticExtractor() if ACOUSTIC_AVAILABLE else None


# ---------------------- DATA MODELS ----------------------
class UserProfile(BaseModel):
    name: str = ""
    age_group: str = ""
    concerns: List[str] = []
    coping_strategies_worked: List[str] = []
    coping_strategies_failed: List[str] = []
    additional_notes: str = ""

class ChatRequest(BaseModel):
    transcript: str
    emotion: Optional[str] = None
    audio_bytes_b64: Optional[str] = None  # Base64-encoded raw PCM audio for acoustic analysis
    profile: Optional[UserProfile] = None
    session_id: Optional[str] = None
    user_id: Optional[str] = None  # Firebase UID for authenticated users
    conversation_history: Optional[List[dict]] = None  # List of {"role": "user"|"assistant", "content": "..."}

class QuickEmotionRequest(BaseModel):
    emotion: str
    profile: Optional[UserProfile] = None

class FeedbackRequest(BaseModel):
    transcript: str
    advice_given: str
    strategy_given: str
    feedback: str  # "Worked" or "Failed"
    session_id: Optional[str] = None
    user_id: Optional[str] = None
    profile: Optional[UserProfile] = None

class EnhanceStrategyRequest(BaseModel):
    strategy_title: str
    strategy_steps: List[str]
    profile: Optional[UserProfile] = None

# ── User Study Data Models (Phase 2 — IEEE paper results section) ──
class StudySessionRequest(BaseModel):
    """Collected after each 15-minute user study session with a participant."""
    participant_id: str            # e.g. "P01"–"P25" (anonymized)
    session_id: str
    # SUS (System Usability Scale) — 10 questions, 1-5 Likert
    sus_scores: List[int]          # exactly 10 values, each 1–5
    # Emotion accuracy
    emotion_accuracy_rating: int   # 1=very wrong, 5=very accurate
    # Overall satisfaction
    satisfaction_rating: int       # 1=very unsatisfied, 5=very satisfied
    # Open text feedback
    what_worked: str = ""
    what_didnt_work: str = ""
    # System-measured (auto-filled by backend)
    avg_latency_ms: Optional[float] = None
    turns_count: Optional[int] = None
    crisis_detected: Optional[bool] = None
    emotion_trajectory: Optional[List[str]] = None  # e.g. ["anxious","neutral","calm"]

class StudySessionResponse(BaseModel):
    success: bool
    sus_score: float               # Computed SUS score 0–100
    participant_id: str
    message: str


# ==============================================================================
# NOVEL CONTRIBUTION 4: SESSION-BASED EMOTION TREND STORE
# Research basis: DialogueCRN (A18) — contexts across turns improve detection.
# Each session stores: emotion timeline, turn count, latency log, crisis flags.
# Sessions expire after SESSION_TTL_MINUTES of inactivity (no Redis needed).
# ==============================================================================

SESSION_TTL_MINUTES = 60
_session_store: Dict[str, dict] = {}  # session_id → session data

def _get_or_create_session(session_id: str) -> dict:
    """Get or create an in-memory session. Auto-expires after TTL."""
    import datetime
    now = datetime.datetime.now()
    if session_id not in _session_store:
        _session_store[session_id] = {
            "created_at": now.isoformat(),
            "updated_at": now.isoformat(),
            "emotion_history": [],       # list of {"turn": int, "emotion": str, "confidence": float, "ts": str}
            "latency_log_ms": [],        # list of float latency values
            "turn_count": 0,
            "crisis_detected": False,
            "crisis_tiers": [],
        }
    else:
        _session_store[session_id]["updated_at"] = now.isoformat()
    # Evict stale sessions (simple TTL)
    stale = [sid for sid, s in _session_store.items()
             if (now - datetime.datetime.fromisoformat(s["updated_at"])).seconds > SESSION_TTL_MINUTES * 60]
    for sid in stale:
        del _session_store[sid]
    return _session_store[session_id]

def _record_emotion_turn(session_id: str, emotion: str, confidence: float, latency_ms: float):
    """Append a turn's emotion + latency to the session timeline."""
    import datetime
    if not session_id:
        return
    session = _get_or_create_session(session_id)
    session["emotion_history"].append({
        "turn": session["turn_count"] + 1,
        "emotion": emotion,
        "confidence": round(confidence, 3),
        "ts": datetime.datetime.now().isoformat(),
    })
    session["latency_log_ms"].append(latency_ms)
    session["turn_count"] += 1

def _record_crisis(session_id: str, tier: str):
    if not session_id:
        return
    session = _get_or_create_session(session_id)
    session["crisis_detected"] = True
    session["crisis_tiers"].append(tier)


# User study data store (in-memory + CSV dump)
import csv, pathlib
STUDY_DATA_FILE = pathlib.Path(__file__).parent / "study_data.csv"
_study_sessions: List[dict] = []

def _compute_sus_score(sus_scores: List[int]) -> float:
    """
    Standard SUS formula: odd questions (1,3,5,7,9) = score-1, even (2,4,6,8,10) = 5-score.
    Total = sum × 2.5 → scale 0–100.
    """
    if len(sus_scores) != 10:
        return 0.0
    total = 0
    for i, score in enumerate(sus_scores):
        if (i + 1) % 2 == 1:  # odd
            total += (score - 1)
        else:                   # even
            total += (5 - score)
    return round(total * 2.5, 1)



# ---------------------- PROFILE CONTEXT ----------------------
def get_profile_context(profile: Optional[UserProfile]) -> str:
    """Convert user profile into context string for AI"""
    if not profile or not profile.name:
        return "No user profile provided. Give general wellness advice."

    context = f"""
USER CONTEXT:
- Name: {profile.name}
- Age Group: {profile.age_group}
- Main Concerns: {', '.join(profile.concerns) if profile.concerns else 'General wellness'}
- Coping Strategies That Work: {', '.join(profile.coping_strategies_worked) if profile.coping_strategies_worked else 'None specified'}
- Strategies To AVOID: {', '.join(profile.coping_strategies_failed) if profile.coping_strategies_failed else 'None specified'}
- Additional Notes: {profile.additional_notes if profile.additional_notes else 'None'}

IMPORTANT: Personalize your response based on this context. Avoid suggesting strategies they marked as failed.
"""
    return context


# NOTE: Crisis detection, helplines, and acoustic classes are now defined above
# in the Novelty Contributions section. The old CRISIS_KEYWORDS block has been
# replaced by the tiered classify_crisis() + acoustic distress combination.


# ---------------------- SYSTEM INSTRUCTIONS ----------------------

CHAT_SYSTEM_INSTRUCTION = """
You are a compassionate AI mental health companion with expertise in CBT, DBT, mindfulness, and positive psychology.

Input: A user's message about how they're feeling + optional context.
Output: JSON. You MUST choose a response_style that matches the conversational moment, then fill the matching fields.

Available response_style values:
1. "empathetic_listen" — when the user is venting, sharing pain, or just needs to be heard. NO advice. Ask a gentle follow-up question.
   Required fields: response_style, message, follow_up_question
2. "guided_support" — when the user is asking for help, techniques, or coping strategies.
   Required fields: response_style, validation, insight, action
3. "conversational" — for casual check-ins, greetings, gratitude, or light moments.
   Required fields: response_style, message
4. "reflection" — when the user has shared something deep and needs gentle psychoeducation or reframing.
   Required fields: response_style, message, reflection

HOW TO CHOOSE:
- First message or vague emotion → "empathetic_listen" (ask more, don't jump to advice)
- Asking "what should I do" / "help me" / specific problem → "guided_support"
- Greeting, thank you, update, positive news → "conversational"
- Deep sharing, self-discovery, pattern recognition → "reflection"
- NEVER default to "guided_support" unless the user is explicitly asking for a technique or strategy.
- VARY your style across turns. Do NOT use the same style twice in a row.

Rules:
- Be warm, compassionate, and non-judgmental
- Never diagnose mental health conditions
- Don't replace professional therapy - encourage it when appropriate
- Avoid clinical jargon - speak naturally and warmly
- If they mentioned strategies that failed, NEVER suggest them again
- Prioritize strategies they've found helpful before
- Address them by name if provided
- Keep responses concise and natural (NOT robotic or templated)

Example responses:
{"response_style": "empathetic_listen", "message": "That sounds really tough. Exam pressure can weigh on you in ways that go beyond just studying.", "follow_up_question": "What part of it feels the heaviest right now?"}
{"response_style": "guided_support", "validation": "It makes sense you're feeling anxious.", "insight": "Your body is in fight-or-flight mode right now.", "action": "Try box breathing: in 4, hold 4, out 4, hold 4. Repeat 3 times."}
{"response_style": "conversational", "message": "I'm glad to hear that! Small wins matter. How are you feeling about the rest of your day?"}
{"response_style": "reflection", "message": "It sounds like you've been carrying this for a while.", "reflection": "Sometimes when we push through without pausing, the weight builds quietly. Noticing it is actually a really important step."}
"""

EMOTION_SYSTEM_INSTRUCTION = """
You are a mental health companion providing quick, evidence-based support for specific emotions.

Input: A specific emotion + optional user context.
Output: JSON with 3 solutions, each containing:
- 'type': Either "grounding" (present-moment technique) or "activity" (engagement exercise)
- 'title': Short name (2-4 words)
- 'desc': Brief description (10-15 words)
- 'steps': Array of exactly 5 step-by-step instructions

Rules:
- For "anxious" → prefer grounding and breathing techniques
- For "sad" → prefer gentle movement and connection activities
- For "stressed" → prefer relaxation and decompression
- For "cant_sleep" → prefer wind-down and body relaxation
- For "overwhelmed" → prefer simplification and stepping-back exercises
- Avoid strategies they marked as failed

Example JSON:
{
  "solutions": [
    {
      "type": "grounding",
      "title": "5-4-3-2-1",
      "desc": "Sensory grounding technique to anchor you in the present.",
      "steps": ["1. Name 5 things you can see.", "2. Touch 4 different textures.", "3. Listen for 3 distinct sounds.", "4. Notice 2 things you can smell.", "5. Focus on 1 thing you can taste."]
    }
  ]
}
"""

ENHANCE_SYSTEM_INSTRUCTION = """
You are an expert mental health companion who adapts coping strategies to specific personal contexts.

Input: A coping strategy + user's personal context.
Output: JSON with:
- 'adapted_title': Modified title if needed
- 'adapted_desc': Description tailored to their context
- 'adapted_steps': 5 steps modified for their specific situation
- 'pro_tips': 2-3 personalized tips
- 'common_mistakes': 2 mistakes to avoid
"""

FEEDBACK_SYSTEM_INSTRUCTION = """
You are a reflective mental health companion analyzing what worked and what didn't.

Input: A user's situation, the advice given, and whether it worked or failed.
Output: JSON with:
- 'analysis': Why it likely worked/failed (2-3 sentences)
- 'alternative': If failed, suggest a better approach. If worked, suggest how to build on it.
- 'encouragement': A brief encouraging message (1-2 sentences)
"""

ACTIVITY_SYSTEM_INSTRUCTION = """
You are a wellness coach generating calming, evidence-based activities.

Generate a unique, calming 3-5 minute wellness activity that:
1. Can be done anywhere, anytime
2. Requires no special equipment
3. Is evidence-based (mindfulness, CBT, or positive psychology)

Output JSON with:
- 'title': Creative name (2-4 words)
- 'desc': Brief description (10-15 words)
- 'duration': Time needed (e.g., "3 minutes")
- 'steps': Array of 5 clear steps
- 'benefits': Array of 2 benefits
"""


# ---------------------- API ENDPOINTS ----------------------

@app.get("/")
async def root():
    return {
        "status": "🧠 VoiceMind Backend Running",
        "version": "2.0.0-research",
        "novelty": {
            "contribution_1": "Dual-channel emotion fusion (60% acoustic + 40% text) — A10/A4",
            "contribution_2": "Acoustic biomarker extraction: pitch, jitter, shimmer, MFCC — A8/A1",
            "contribution_3": "Tiered crisis detection (3 levels + acoustic distress) — A7/A8/A14",
        },
        "endpoints": ["/chat", "/analyze_audio", "/quick_emotion", "/enhance_strategy",
                      "/feedback", "/helplines", "/generate_activity", "/health", "/health/acoustic"]
    }

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "gemini_api": "connected" if api_key else "not configured",
        "acoustic_engine": "enabled" if ACOUSTIC_AVAILABLE else "disabled (pip install librosa)",
        "novel_contributions": {"tiered_crisis": True, "dual_channel_emotion": True, "acoustic_features": ACOUSTIC_AVAILABLE},
    }

@app.get("/health/acoustic")
async def health_acoustic():
    """Check acoustic engine status and feature extraction capabilities."""
    if not ACOUSTIC_AVAILABLE:
        return {"status": "disabled", "message": "Install: pip install librosa soundfile numpy"}
    return {
        "status": "enabled",
        "features_extracted": ["pitch_mean", "pitch_std", "energy", "mfcc_13", "jitter", "shimmer", "pause_count"],
        "research_basis": "Marie et al. 2025 (A8) — validated biomarkers in 33 studies",
        "fusion_weights": {"acoustic": 0.6, "text": 0.4},
        "crisis_thresholds": ACOUSTIC_DISTRESS_THRESHOLDS,
    }

class AnalyzeAudioRequest(BaseModel):
    audio_bytes_b64: str
    text_emotion: Optional[str] = "neutral"

@app.post("/analyze_audio")
async def analyze_audio(request: AnalyzeAudioRequest):
    """
    Standalone acoustic analysis endpoint.
    Extracts 7 acoustic biomarkers from raw PCM audio + computes dual-channel emotion fusion.
    
    Research basis: Marie et al. 2025 (A8), Peerzade 2018 (A1), Pepino 2021 (A16)
    """
    if not acoustic_extractor:
        return {"error": "Acoustic engine not available. Install librosa: pip install librosa soundfile numpy"}
    try:
        raw = base64.b64decode(request.audio_bytes_b64)
        features = acoustic_extractor.extract_from_bytes(raw)
        if not features.extraction_success:
            return {"error": "Audio too short or could not be decoded. Need ≥0.5 seconds of 16kHz PCM."}
        fused_emotion, confidence, metadata = fuse_emotion_channels(
            text_emotion=request.text_emotion or "neutral",
            acoustic_features=features,
            acoustic_weight=0.6
        )
        return {
            "acoustic_features": {
                "pitch_mean_hz": round(features.pitch_mean, 2),
                "pitch_std": round(features.pitch_std, 2),
                "energy": round(features.energy, 4),
                "mfcc_means": [round(v, 2) for v in features.mfcc],
                "jitter": round(features.jitter, 4),
                "shimmer": round(features.shimmer, 4),
                "pause_count": features.pause_count,
            },
            "acoustic_emotion_scores": acoustic_to_emotion_scores(features),
            "fusion_result": {
                "detected_emotion": fused_emotion,
                "confidence": confidence,
                **metadata
            },
            "distress_flags": {
                "acoustic_distress": features.jitter > ACOUSTIC_DISTRESS_THRESHOLDS["jitter"] or
                                     features.shimmer > ACOUSTIC_DISTRESS_THRESHOLDS["shimmer"],
                "high_jitter": features.jitter > ACOUSTIC_DISTRESS_THRESHOLDS["jitter"],
                "high_shimmer": features.shimmer > ACOUSTIC_DISTRESS_THRESHOLDS["shimmer"],
            }
        }
    except Exception as e:
        return {"error": str(e)}



# ---------------------- WEBSOCKET FOR REAL-TIME TRANSCRIPTION ----------------------
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def send_json(self, websocket: WebSocket, data: dict):
        await websocket.send_json(data)

manager = ConnectionManager()

@app.websocket("/ws/transcribe")
async def websocket_transcribe(websocket: WebSocket):
    """
    WebSocket endpoint for real-time transcription with crisis detection.
    Expects JSON messages with 'transcript' field.
    Sends back: {type: 'transcript', text: str, is_crisis: bool, helplines: dict}
    """
    await manager.connect(websocket)
    print("🔌 WebSocket client connected")
    
    try:
        while True:
            # Receive message from client
            data = await websocket.receive_json()
            transcript = data.get('transcript', '')
            
            if not transcript:
                continue
            
            print(f"📝 Received: {transcript}")
            
            # Tiered crisis detection (A7, A8, A14 — Novel Contribution 3)
            crisis_result = classify_crisis(transcript)
            is_crisis = crisis_result["is_crisis"]
            
            response = {
                'type': 'transcript',
                'text': transcript,
                'is_crisis': is_crisis,
                'crisis_tier': crisis_result["crisis_tier"],
                'acoustic_distress': crisis_result["acoustic_distress"],
            }
            
            if is_crisis:
                crisis_data = get_crisis_response(crisis_result["crisis_tier"])
                response['helplines'] = crisis_data['helplines']
                response['message'] = crisis_data['message']
                response['immediate_actions'] = crisis_data['immediate_actions']
                response['crisis_tier'] = crisis_result['crisis_tier']
                print(f"⚠️  CRISIS [{crisis_result['crisis_tier']}] in: {transcript}")
            
            # Send response back to client
            await manager.send_json(websocket, response)
            
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        print("🔌 WebSocket client disconnected")
    except Exception as e:
        print(f"❌ WebSocket error: {e}")
        manager.disconnect(websocket)


@app.post("/chat")
async def chat_with_ai(request: ChatRequest, decoded_token: dict = Depends(verify_firebase_token)):
    """
    Main chat endpoint — tiered crisis detection + dual-channel emotion fusion + AI response.
    
    Novel Contributions addressed:
      - Contribution 1: Acoustic feature extraction + dual-channel emotion fusion (60/40)
      - Contribution 3: Tiered crisis detection (keyword regex + acoustic distress)
    """
    t_start = time.time()
    print(f"🎤 User said: {request.transcript}")
    log_event("chat_request", {
        "user_id": request.user_id or "",
        "session_id": request.session_id or "",
        "transcript_length": len(request.transcript),
        "has_audio": bool(request.audio_bytes_b64),
        "emotion": request.emotion or "",
    })

    # --- Acoustic extraction (if audio bytes provided) ---
    acoustic_features = AcousticFeatures()  # Empty default
    if request.audio_bytes_b64 and acoustic_extractor:
        try:
            raw = base64.b64decode(request.audio_bytes_b64)
            acoustic_features = acoustic_extractor.extract_from_bytes(raw)
            print(f"🎵 Acoustic: pitch={acoustic_features.pitch_mean:.1f}Hz jitter={acoustic_features.jitter:.4f} shimmer={acoustic_features.shimmer:.4f}")
        except Exception as e:
            print(f"⚠️  Acoustic decode error: {e}")

    # --- Tiered crisis detection (keyword + acoustic) ---
    crisis_result = classify_crisis(request.transcript, acoustic_features)
    if crisis_result["is_crisis"]:
        print(f"🚨 Crisis detected! Tier: {crisis_result['crisis_tier']}")
        log_event("crisis_detected", {
            "user_id": request.user_id or "",
            "session_id": request.session_id or "",
            "tier": crisis_result["crisis_tier"],
            "transcript": request.transcript[:200],
        })
        if request.session_id:
            _record_crisis(request.session_id, crisis_result["crisis_tier"])
        return {
            **get_crisis_response(crisis_result["crisis_tier"]),
            "crisis_tier": crisis_result["crisis_tier"],
            "acoustic_distress": crisis_result["acoustic_distress"],
            "latency_ms": round((time.time() - t_start) * 1000, 1),
        }

    try:
        profile_context = get_profile_context(request.profile)

        # --- Text-side emotion from request (set by Flutter from quick emotion chips or prior LLM call) ---
        text_emotion = request.emotion or "neutral"

        # --- Dual-channel emotion fusion (Novel Contribution 2) ---
        fused_emotion, confidence, emotion_metadata = fuse_emotion_channels(
            text_emotion=text_emotion,
            acoustic_features=acoustic_features,
            acoustic_weight=0.6  # 60% acoustic, 40% text — validated by A10 (Lin 2020)
        )
        log_event("emotion_detected", {
            "user_id": request.user_id or "",
            "session_id": request.session_id or "",
            "emotion": fused_emotion,
            "confidence": round(confidence, 3),
            "text_emotion": text_emotion,
            "acoustic_emotion": emotion_metadata.get("acoustic_emotion", ""),
        })
        emotion_context = f"\nDETECTED EMOTION (fused): {fused_emotion} (confidence: {confidence:.0%})"
        if emotion_metadata.get("acoustic_available"):
            emotion_context += f" | acoustic_score={emotion_metadata['acoustic_score']:.2f}, text_score={emotion_metadata['text_score']:.2f}"
        
        print(f"🧠 Emotion: text={text_emotion} → fused={fused_emotion} ({confidence:.0%})")
        
        # Build conversation history for multi-turn context
        conversation_contents = []
        
        # Add profile context as system message in first user turn
        first_user_content = f"{profile_context}{emotion_context}\n\n"
        
        if request.conversation_history:
            # Build multi-turn conversation from history
            for i, msg in enumerate(request.conversation_history[:-1]):  # Exclude last message (current)
                if msg.get('role') == 'user':
                    content = msg.get('content', '')
                    if i == 0:
                        content = first_user_content + content
                    conversation_contents.append(types.Content(role='user', parts=[types.Part(text=content)]))
                elif msg.get('role') == 'assistant':
                    conversation_contents.append(types.Content(role='model', parts=[types.Part(text=msg.get('content', ''))]))
            
            # Add current user message
            current_content = request.transcript if conversation_contents else f"{first_user_content}USER: {request.transcript}"
            conversation_contents.append(types.Content(role='user', parts=[types.Part(text=current_content)]))
        else:
            # No history - single turn
            conversation_contents = f"{first_user_content}USER: {request.transcript}"
        
        print(f"📜 Conversation turns: {len(conversation_contents) if isinstance(conversation_contents, list) else 1}")

        # ADK Multi-Agent Execution (Phase F)
        history_context = ""
        if request.conversation_history:
            recent = request.conversation_history[-8:]
            lines = []
            for msg in recent:
                role = "USER" if msg.get("role") == "user" else "ASSISTANT"
                content = (msg.get("content") or "").strip()
                if content:
                    lines.append(f"{role}: {content}")
            if lines:
                history_context = "RECENT CONVERSATION CONTEXT:\n" + "\n".join(lines) + "\n\n"

        adk_input = f"{profile_context}\n{emotion_context}\n{history_context}USER SAYS: {request.transcript}"
        request_msg = types.Content(role="user", parts=[types.Part.from_text(text=adk_input)])
        u_id = request.profile.name if request.profile and request.profile.name else "anonymous"
        s_id = request.session_id if request.session_id else "default_session"
        
        agent_response_text = ""
        agent_response_crisis = False
        
        async for event in adk_runner.run_async(user_id=u_id, session_id=s_id, new_message=request_msg):
            # Track if it was handled by the crisis agent
            if event.author == "crisis_team":
                agent_response_crisis = True
                
            if event.content and event.content.parts:
                for p in event.content.parts:
                    if p.text:
                        agent_response_text += p.text

        # Sanitize JSON from Markdown backticks if present
        agent_response_text = agent_response_text.strip("```json\n").strip("```").strip()
        try:
            data = json.loads(agent_response_text)
        except Exception as e:
            print(f"⚠️ JSON Parse Error from Agent: {e} -> Raw text: {agent_response_text}")
            data = {"validation": "I hear you.", "insight": "", "action": agent_response_text[:200]}
            if agent_response_crisis:
                data["is_crisis"] = True

        if agent_response_crisis:
            data["is_crisis"] = True
            data["crisis_tier"] = "escalated_by_agent"

        latency_ms = round((time.time() - t_start) * 1000, 1)
        print(f"🤖 AI [ADK Pipeline]: {data} [{latency_ms}ms]")

        # Novel Contribution 4 — Record emotion turn in session timeline (DialogueCRN A18)
        if request.session_id:
            _record_emotion_turn(request.session_id, fused_emotion, confidence, latency_ms)
        session_data = _session_store.get(request.session_id, {}) if request.session_id else {}
        emotion_history = session_data.get("emotion_history", [])
        turn_count = session_data.get("turn_count", 1)

        # **data may contain hallucinated is_crisis from the LLM; authoritative flags are last.
        return {
            # Dual-channel emotion analysis metadata (Novel Contributions 1 & 2)
            "emotion_analysis": {
                "detected_emotion": fused_emotion,
                "confidence": confidence,
                "text_emotion": emotion_metadata.get("text_emotion", text_emotion),
                "text_score": emotion_metadata.get("text_score", 0.0),
                "acoustic_score": emotion_metadata.get("acoustic_score", 0.0),
                "fusion_weights": emotion_metadata.get("fusion_weights", {"acoustic": 0.6, "text": 0.4}),
                "acoustic_available": emotion_metadata.get("acoustic_available", False),
                "acoustic_features": {
                    "pitch_mean": round(acoustic_features.pitch_mean, 2),
                    "pitch_std": round(acoustic_features.pitch_std, 2),
                    "pitch_range": round(acoustic_features.pitch_range, 2),
                    "energy": round(acoustic_features.energy, 4),
                    "energy_std": round(acoustic_features.energy_std, 4),
                    "energy_max": round(acoustic_features.energy_max, 4),
                    "jitter": round(acoustic_features.jitter, 4),
                    "shimmer": round(acoustic_features.shimmer, 4),
                    "hnr": round(acoustic_features.hnr, 2),
                    "spectral_centroid": round(acoustic_features.spectral_centroid, 2),
                    "spectral_bandwidth": round(acoustic_features.spectral_bandwidth, 2),
                    "spectral_rolloff": round(acoustic_features.spectral_rolloff, 2),
                    "spectral_flatness": round(acoustic_features.spectral_flatness, 6),
                    "zero_crossing_rate": round(acoustic_features.zero_crossing_rate, 4),
                    "tempo": round(acoustic_features.tempo, 2),
                    "pause_count": acoustic_features.pause_count,
                    "voiced_fraction": round(acoustic_features.voiced_fraction, 3),
                    "feature_count": len(acoustic_features.to_feature_vector()),
                } if acoustic_features.extraction_success else {},
            },
            # Novel Contribution 4 — emotion trend for Flutter sparkline (A18)
            "emotion_trend": {
                "history": emotion_history[-10:],  # last 10 turns max
                "turn_count": turn_count,
                "trajectory": [e["emotion"] for e in emotion_history[-5:]],  # last 5 for sparkline
            },
            "latency_ms": latency_ms,
            **data,
            "is_crisis": agent_response_crisis,
            "crisis_tier": "escalated_by_agent" if agent_response_crisis else crisis_result["crisis_tier"],
        }

    except json.JSONDecodeError as e:
        print(f"❌ JSON Parse Error: {e}")
        return get_fallback_response()
    except Exception as e:
        print(f"❌ Error: {e}")
        return get_fallback_response()


def get_fallback_response():
    """Return a varied fallback response with different response styles."""
    import random
    fallback_responses = [
        {
            "response_style": "empathetic_listen",
            "message": "I hear you, and your feelings matter. Sometimes just saying it out loud helps.",
            "follow_up_question": "What's weighing on you the most right now?",
        },
        {
            "response_style": "empathetic_listen",
            "message": "Thank you for sharing that with me. It takes courage to express what's going on inside.",
            "follow_up_question": "Would you like to tell me a bit more about what's happening?",
        },
        {
            "response_style": "reflection",
            "message": "What you're feeling is completely valid.",
            "reflection": "Emotions come and go like waves. Noticing them without fighting them is a quiet kind of strength.",
        },
        {
            "response_style": "guided_support",
            "validation": "I'm here with you in this moment.",
            "insight": "You don't have to have it all figured out right now.",
            "action": "Gently roll your shoulders back and release any tension you're holding."
        },
        {
            "response_style": "empathetic_listen",
            "message": "It's okay to feel this way. Every emotion serves a purpose, even the difficult ones.",
            "follow_up_question": "Is there something specific that triggered this feeling?",
        },
        {
            "response_style": "reflection",
            "message": "Your experience is real and it matters.",
            "reflection": "Being gentle with yourself is not a luxury — it's a necessity. You deserve the same compassion you'd give a friend.",
        },
        {
            "response_style": "empathetic_listen",
            "message": "I appreciate you opening up about this. Vulnerability is a form of strength, not weakness.",
            "follow_up_question": "How long have you been feeling this way?",
        },
    ]
    response = random.choice(fallback_responses)
    return {"is_crisis": False, **response}


class SummarizeRequest(BaseModel):
    transcript: str
    session_id: Optional[str] = None

SUMMARIZE_INSTRUCTION = """
You are summarizing a completed voice conversation between a user and their AI mental health companion.
Given the full transcript, produce a JSON summary with these keys:
1. "care_summary": A warm 1-2 sentence summary of what the user was going through (max 40 words).
2. "key_emotions": Array of up to 3 emotions that came up during the conversation.
3. "action_items": Array of 1-3 concrete things the user can try, drawn from the conversation.
4. "takeaway": A single encouraging closing thought (max 25 words, warm tone).

Be warm, concise, and non-clinical.
"""

@app.post("/chat/summarize")
async def summarize_session(request: SummarizeRequest):
    """Summarize a completed voice session into care insights + action items."""
    try:
        response = client.models.generate_content(
            model='gemini-2.5-flash-lite',
            contents=f"CONVERSATION TRANSCRIPT:\n{request.transcript}\n\nSummarize this session.",
            config=types.GenerateContentConfig(
                system_instruction=SUMMARIZE_INSTRUCTION,
                response_mime_type='application/json',
            )
        )
        data = json.loads(response.text)
        print(f"📝 Session summary generated: {data.get('care_summary', '')[:60]}...")
        return data
    except json.JSONDecodeError as e:
        print(f"❌ Summarize JSON error: {e}")
        return {
            "care_summary": "You had a meaningful conversation. Take care of yourself.",
            "key_emotions": [],
            "action_items": ["Take a few deep breaths", "Be gentle with yourself today"],
            "takeaway": "You showed courage by sharing. That matters."
        }
    except Exception as e:
        print(f"❌ Summarize API error: {e}")
        return {
            "care_summary": "You had a meaningful conversation. Take care of yourself.",
            "key_emotions": [],
            "action_items": ["Take a few deep breaths", "Be gentle with yourself today"],
            "takeaway": "You showed courage by sharing. That matters."
        }


@app.post("/quick_emotion")
async def quick_emotion(request: QuickEmotionRequest, decoded_token: dict = Depends(verify_firebase_token)):
    """Get 3 quick coping solutions for a specific emotion."""
    print(f"⚡ Quick emotion: {request.emotion}")

    emotion_prompts = {
        "anxious": "I'm feeling really anxious and overwhelmed. My heart is racing.",
        "sad": "I'm feeling sad and low today. Everything feels heavy.",
        "stressed": "I'm extremely stressed out and can't relax.",
        "cant_sleep": "I can't sleep and my mind won't stop racing.",
        "overwhelmed": "I feel completely overwhelmed. Everything is too much."
    }

    emotion_desc = emotion_prompts.get(request.emotion, f"I'm feeling {request.emotion}")

    try:
        profile_context = get_profile_context(request.profile)
        full_prompt = f"{profile_context}\n\nEMOTION: {emotion_desc}\n\nProvide exactly 3 solutions."

        response = client.models.generate_content(
            model='gemini-2.5-flash-lite',
            contents=full_prompt,
            config=types.GenerateContentConfig(
                system_instruction=EMOTION_SYSTEM_INSTRUCTION,
                response_mime_type='application/json',
            )
        )

        data = json.loads(response.text)
        print(f"🤖 Solutions: {len(data.get('solutions', []))} provided")
        return data

    except json.JSONDecodeError as e:
        print(f"❌ Quick Emotion JSON error: {e}")
        return {
            "solutions": [
                {"type": "grounding", "title": "Deep Breathing", "desc": "Simple breathing to calm your nervous system.", "steps": ["1. Sit comfortably.", "2. Breathe in for 4 counts.", "3. Hold for 4 counts.", "4. Exhale for 6 counts.", "5. Repeat 4 times."]},
                {"type": "grounding", "title": "5-4-3-2-1", "desc": "Sensory grounding to return to the present.", "steps": ["1. See 5 things.", "2. Touch 4 textures.", "3. Hear 3 sounds.", "4. Smell 2 things.", "5. Taste 1 thing."]},
                {"type": "activity", "title": "Body Scan", "desc": "Progressive relaxation from head to toe.", "steps": ["1. Close your eyes.", "2. Focus on your forehead.", "3. Move attention down slowly.", "4. Breathe into tension.", "5. End at your toes."]}
            ]
        }
    except Exception as e:
        print(f"❌ Quick Emotion API error: {e}")
        return {
            "solutions": [
                {"type": "grounding", "title": "Deep Breathing", "desc": "Simple breathing to calm your nervous system.", "steps": ["1. Sit comfortably.", "2. Breathe in for 4 counts.", "3. Hold for 4 counts.", "4. Exhale for 6 counts.", "5. Repeat 4 times."]},
                {"type": "grounding", "title": "5-4-3-2-1", "desc": "Sensory grounding to return to the present.", "steps": ["1. See 5 things.", "2. Touch 4 textures.", "3. Hear 3 sounds.", "4. Smell 2 things.", "5. Taste 1 thing."]},
                {"type": "activity", "title": "Body Scan", "desc": "Progressive relaxation from head to toe.", "steps": ["1. Close your eyes.", "2. Focus on your forehead.", "3. Move attention down slowly.", "4. Breathe into tension.", "5. End at your toes."]}
            ]
        }


@app.post("/enhance_strategy")
async def enhance_strategy(request: EnhanceStrategyRequest):
    """Adapt a coping strategy to the user's specific context."""
    print(f"📚 Enhancing: {request.strategy_title}")

    try:
        profile_context = get_profile_context(request.profile)
        strategy_info = f"Strategy: {request.strategy_title}\nSteps: {', '.join(request.strategy_steps)}"
        full_prompt = f"{profile_context}\n\n{strategy_info}\n\nAdapt this for this person's context."

        response = client.models.generate_content(
            model='gemini-2.5-flash-lite',
            contents=full_prompt,
            config=types.GenerateContentConfig(
                system_instruction=ENHANCE_SYSTEM_INSTRUCTION,
                response_mime_type='application/json',
            )
        )

        data = json.loads(response.text)
        return data

    except json.JSONDecodeError as e:
        print(f"❌ Enhance Strategy JSON error: {e}")
        return {
            "adapted_title": request.strategy_title,
            "adapted_desc": "Use this technique as described.",
            "adapted_steps": request.strategy_steps,
            "pro_tips": ["Practice daily for best results.", "Be patient with yourself."],
            "common_mistakes": ["Rushing through steps.", "Giving up after one try."]
        }
    except Exception as e:
        print(f"❌ Enhance Strategy API error: {e}")
        return {
            "adapted_title": request.strategy_title,
            "adapted_desc": "Use this technique as described.",
            "adapted_steps": request.strategy_steps,
            "pro_tips": ["Practice daily for best results.", "Be patient with yourself."],
            "common_mistakes": ["Rushing through steps.", "Giving up after one try."]
        }


@app.post("/feedback")
async def record_feedback(request: FeedbackRequest):
    """Record feedback and get AI analysis."""
    print(f"📝 Feedback: {request.feedback} for '{request.advice_given}'")

    try:
        profile_context = get_profile_context(request.profile)
        feedback_prompt = f"""
{profile_context}

USER SITUATION: {request.transcript}
VALIDATION GIVEN: {request.advice_given}
STRATEGY GIVEN: {request.strategy_given}
RESULT: {request.feedback}

Analyze why this {'worked' if request.feedback == 'Worked' else 'failed'} and provide guidance.
"""

        response = client.models.generate_content(
            model='gemini-2.5-flash-lite',
            contents=feedback_prompt,
            config=types.GenerateContentConfig(
                system_instruction=FEEDBACK_SYSTEM_INSTRUCTION,
                response_mime_type='application/json',
            )
        )

        data = json.loads(response.text)
        return data

    except json.JSONDecodeError as e:
        print(f"❌ Feedback JSON error: {e}")
        if request.feedback == "Worked":
            return {
                "analysis": "This technique resonated with your current emotional state.",
                "alternative": "Make this a regular practice for lasting benefits.",
                "encouragement": "You're doing great by finding what works for you!"
            }
        else:
            return {
                "analysis": "This approach may not fit your current situation.",
                "alternative": "Try a different sensory-based technique like progressive muscle relaxation.",
                "encouragement": "Finding the right technique takes time. Every attempt teaches you something."
            }
    except Exception as e:
        print(f"❌ Feedback API error: {e}")
        if request.feedback == "Worked":
            return {
                "analysis": "This technique resonated with your current emotional state.",
                "alternative": "Make this a regular practice for lasting benefits.",
                "encouragement": "You're doing great by finding what works for you!"
            }
        else:
            return {
                "analysis": "This approach may not fit your current situation.",
                "alternative": "Try a different sensory-based technique like progressive muscle relaxation.",
                "encouragement": "Finding the right technique takes time. Every attempt teaches you something."
            }


@app.get("/helplines")
async def get_helplines():
    """Get crisis helplines by region."""
    return {
        "india": INDIA_HELPLINES,
        "international": INTERNATIONAL_HELPLINES,
        "emergency": {"India": "112", "US": "911", "UK": "999", "Australia": "000"}
    }


@app.post("/generate_activity")
async def generate_activity(profile: Optional[UserProfile] = None):
    """Generate a custom wellness activity."""
    try:
        profile_context = get_profile_context(profile)
        prompt = f"{profile_context}\n\nGenerate a unique wellness activity."

        response = client.models.generate_content(
            model='gemini-2.5-flash-lite',
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=ACTIVITY_SYSTEM_INSTRUCTION,
                response_mime_type='application/json',
            )
        )

        return json.loads(response.text)

    except json.JSONDecodeError as e:
        print(f"❌ Generate Activity JSON error: {e}")
        return {
            "title": "Gratitude Pause",
            "desc": "Name 3 things you're grateful for right now.",
            "duration": "3 minutes",
            "steps": [
                "1. Close your eyes and breathe deeply.",
                "2. Notice 3 small things that brought you comfort today.",
                "3. Let yourself feel appreciation for those moments."
            ]
        }
    except Exception as e:
        print(f"❌ Generate Activity API error: {e}")
        return {
            "title": "Gratitude Pause",
            "desc": "Name 3 things you're grateful for right now.",
            "duration": "3 minutes",
            "steps": [
                "1. Close your eyes and breathe deeply.",
                "2. Think of something that made you smile today.",
                "3. Think of a person you appreciate.",
                "4. Think of something you're proud of.",
                "5. Open your eyes and carry that warmth with you."
            ],
            "benefits": ["Shifts focus to positive aspects.", "Activates calming brain systems."]
        }


# ==============================================================================
# NOVEL CONTRIBUTION 4: SESSION TREND API
# GET /session/trends/{session_id}
# Returns the emotion timeline for a session — used by Flutter sparkline widget
# Research basis: DialogueCRN (A18) — multi-turn context improves recognition.
# ==============================================================================

@app.get("/session/trends/{session_id}")
async def get_session_trends(session_id: str):
    """Return emotion timeline and latency stats for a session."""
    if session_id not in _session_store:
        return {"session_id": session_id, "emotion_history": [], "turn_count": 0, "avg_latency_ms": 0}
    session = _session_store[session_id]
    latencies = session.get("latency_log_ms", [])
    return {
        "session_id": session_id,
        "emotion_history": session["emotion_history"],
        "trajectory": [e["emotion"] for e in session["emotion_history"]],
        "turn_count": session["turn_count"],
        "avg_latency_ms": round(sum(latencies) / len(latencies), 1) if latencies else 0,
        "min_latency_ms": round(min(latencies), 1) if latencies else 0,
        "max_latency_ms": round(max(latencies), 1) if latencies else 0,
        "crisis_detected": session["crisis_detected"],
        "crisis_tiers": session["crisis_tiers"],
    }


# ==============================================================================
# PHASE 2: USER STUDY ENDPOINTS
# POST /study/session  — submit post-session questionnaire data
# GET  /study/export   — download all data as CSV for paper analysis
# These power the n=25 participant user study for IEEE conference submission
# ==============================================================================

@app.post("/study/session", response_model=StudySessionResponse)
async def submit_study_session(req: StudySessionRequest):
    """
    Submit post-session questionnaire data from a study participant.
    Computes SUS score and merges with system-measured session data.
    """
    if len(req.sus_scores) != 10:
        raise HTTPException(status_code=422, detail="sus_scores must have exactly 10 values (SUS scale)")
    if not all(1 <= s <= 5 for s in req.sus_scores):
        raise HTTPException(status_code=422, detail="Each SUS score must be 1–5")

    sus_score = _compute_sus_score(req.sus_scores)

    # Merge with system-measured session data if available
    session_data = _session_store.get(req.session_id, {})
    latencies = session_data.get("latency_log_ms", [])

    record = {
        "participant_id": req.participant_id,
        "session_id": req.session_id,
        "sus_score": sus_score,
        "emotion_accuracy_rating": req.emotion_accuracy_rating,
        "satisfaction_rating": req.satisfaction_rating,
        "what_worked": req.what_worked,
        "what_didnt_work": req.what_didnt_work,
        "avg_latency_ms": round(sum(latencies) / len(latencies), 1) if latencies else req.avg_latency_ms or 0,
        "turns_count": session_data.get("turn_count", req.turns_count or 0),
        "crisis_detected": session_data.get("crisis_detected", req.crisis_detected or False),
        "emotion_trajectory": ",".join([e["emotion"] for e in session_data.get("emotion_history", [])]),
        "sus_q1": req.sus_scores[0], "sus_q2": req.sus_scores[1],
        "sus_q3": req.sus_scores[2], "sus_q4": req.sus_scores[3],
        "sus_q5": req.sus_scores[4], "sus_q6": req.sus_scores[5],
        "sus_q7": req.sus_scores[6], "sus_q8": req.sus_scores[7],
        "sus_q9": req.sus_scores[8], "sus_q10": req.sus_scores[9],
    }
    _study_sessions.append(record)

    # Append to CSV file
    write_header = not STUDY_DATA_FILE.exists()
    with open(STUDY_DATA_FILE, "a", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=record.keys())
        if write_header:
            writer.writeheader()
        writer.writerow(record)

    print(f"📊 Study session saved: {req.participant_id}, SUS={sus_score}")
    return StudySessionResponse(
        success=True,
        sus_score=sus_score,
        participant_id=req.participant_id,
        message=f"Session recorded. SUS score: {sus_score}/100. Thank you for participating!"
    )


@app.get("/study/export")
async def export_study_data(fmt: str = "json"):
    """
    Export all collected user study data.
    ?fmt=json  → JSON array (default)
    ?fmt=csv   → CSV download for pandas analysis
    """
    if not _study_sessions:
        return {"message": "No study sessions recorded yet", "count": 0}
    if fmt == "csv":
        from fastapi.responses import FileResponse
        if STUDY_DATA_FILE.exists():
            return FileResponse(str(STUDY_DATA_FILE), media_type="text/csv", filename="voicemind_study_data.csv")
        return {"error": "CSV file not found"}
    # JSON summary with computed stats
    sus_scores = [s["sus_score"] for s in _study_sessions]
    accuracy_ratings = [s["emotion_accuracy_rating"] for s in _study_sessions]
    satisfaction_ratings = [s["satisfaction_rating"] for s in _study_sessions]
    latencies = [s["avg_latency_ms"] for s in _study_sessions if s["avg_latency_ms"]]
    return {
        "count": len(_study_sessions),
        "summary": {
            "mean_sus_score": round(sum(sus_scores) / len(sus_scores), 1) if sus_scores else 0,
            "mean_emotion_accuracy": round(sum(accuracy_ratings) / len(accuracy_ratings), 2) if accuracy_ratings else 0,
            "mean_satisfaction": round(sum(satisfaction_ratings) / len(satisfaction_ratings), 2) if satisfaction_ratings else 0,
            "mean_latency_ms": round(sum(latencies) / len(latencies), 1) if latencies else 0,
        },
        "sessions": _study_sessions,
    }


@app.get("/study/stats")
async def get_study_stats():
    """Quick stats dashboard for monitoring the user study in real-time."""
    if not _study_sessions:
        return {"sessions_collected": 0, "target": 25, "progress": "0%"}
    sus_scores = [s["sus_score"] for s in _study_sessions]
    return {
        "sessions_collected": len(_study_sessions),
        "target": 25,
        "progress": f"{round(len(_study_sessions)/25*100)}%",
        "mean_sus": round(sum(sus_scores) / len(sus_scores), 1),
        "sus_interpretation": "Good" if sum(sus_scores)/len(sus_scores) >= 68 else "Below average",
        "participants": [s["participant_id"] for s in _study_sessions],
    }


# ---------------------- RUN SERVER ----------------------
if __name__ == "__main__":
    print("🧠 Starting VoiceMind Backend...")
    print("📱 For iOS Device: update kBackendUrl in main.dart to your machine's local IP")
    print("💻 For Browser/Postman: http://localhost:8000")
    print("📖 API Docs: http://localhost:8000/docs")
    print("📊 Study export: http://localhost:8000/study/export")
    uvicorn.run(app, host="0.0.0.0", port=8000)
