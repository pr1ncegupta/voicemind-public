import pytest
import numpy as np
import base64
import librosa
from main import AcousticFeatures, acoustic_extractor

# ---------------------------------------------------------
# Test 1: Acoustic Engine Initialization
# ---------------------------------------------------------
def test_acoustic_engine_loaded():
    assert acoustic_extractor is not None, "Acoustic extraction engine failed to load."

# ---------------------------------------------------------
# Test 2: Valid Audio Processing (Real Sine Wave)
# ---------------------------------------------------------
def test_extract_from_valid_audio_bytes():
    # Generate 1 second of 440 Hz sine wave at 16kHz (Standard A4 note)
    sr = 16000
    t = np.linspace(0, 1, sr, endpoint=False)
    audio = 0.5 * np.sin(2 * np.pi * 440 * t)
    
    # Convert numpy array to 16-bit PCM (simulating flutter mic output)
    audio_pcm16 = (audio * 32767).astype(np.int16)
    audio_bytes = audio_pcm16.tobytes()
    
    features = acoustic_extractor.extract_from_bytes(audio_bytes)
    
    assert features.extraction_success is True
    # The extracted pitch mean should be very close to our generated 440Hz sine wave
    assert 400 < features.pitch_mean < 480, f"Expected ~440Hz, got {features.pitch_mean}"
    # Sine waves have very little jitter/shimmer compared to human voices
    assert features.jitter < 0.05
    assert features.shimmer < 0.05

# ---------------------------------------------------------
# Test 3: Invalid/Short Audio Processing
# ---------------------------------------------------------
def test_extract_from_invalid_short_audio():
    # Create less than 0.5 seconds of silence
    short_audio = np.zeros(1000, dtype=np.int16).tobytes()
    features = acoustic_extractor.extract_from_bytes(short_audio)
    
    assert features.extraction_success is False
    assert features.pitch_mean == 0.0
