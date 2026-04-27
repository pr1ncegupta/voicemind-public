import pytest
from fastapi.testclient import TestClient
from main import app
import os
from dotenv import load_dotenv

# Ensure environment variables are loaded for DB/GenAI integration
load_dotenv()

client = TestClient(app)

def test_health_check():
    """Verify the server is up and returning successful initialization states."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "status" in data
    assert data["status"] == "🧠 VoiceMind Backend Running"
    assert "endpoints" in data

def test_chat_therapist_flow():
    """Send a normal emotional chat and verify the ADK therapist responds with a dynamic response style."""
    payload = {
        "transcript": "I'm having a lot of trouble sleeping lately due to my upcoming exams.",
        "emotion": "anxious",
        "session_id": "test_session_123",
        "profile": {
            "name": "Integration Test User",
            "age_group": "18-24",
            "concerns": ["Anxiety", "Sleep"],
            "coping_strategies_worked": ["Breathing"],
            "coping_strategies_failed": [],
            "additional_notes": "None"
        }
    }
    
    response = client.post("/chat", json=payload)
    assert response.status_code == 200
    data = response.json()
    print("Therapist Response:", data)
    
    # Verify the router did NOT flag this as an immediate life-threatening crisis
    assert data.get("is_crisis") is False
    
    # Verify the therapist responded with a valid response_style
    assert "response_style" in data, "Missing response_style"
    assert data["response_style"] in ("empathetic_listen", "guided_support", "conversational", "reflection"), \
        f"Unknown response_style: {data['response_style']}"
    
    # Verify style-specific fields are present
    style = data["response_style"]
    if style == "empathetic_listen":
        assert "message" in data, "empathetic_listen missing message"
        assert "follow_up_question" in data, "empathetic_listen missing follow_up_question"
    elif style == "guided_support":
        assert "validation" in data, "guided_support missing validation"
        assert "action" in data, "guided_support missing action"
    elif style == "conversational":
        assert "message" in data, "conversational missing message"
    elif style == "reflection":
        assert "message" in data, "reflection missing message"
        assert "reflection" in data, "reflection missing reflection"
    
    # Verify that the dual-channel emotion was tracked
    assert "emotion_analysis" in data
    assert "detected_emotion" in data["emotion_analysis"]
    
def test_chat_crisis_flow_keyword():
    """Send a strictly distressed phrase and ensure the hardcoded regex pre-check catches it instantly."""
    payload = {
        "transcript": "I want to kill myself, I can't do this anymore.",
        "emotion": "depressed",
        "session_id": "test_session_crisis",
    }
    response = client.post("/chat", json=payload)
    assert response.status_code == 200
    data = response.json()
    
    assert data.get("is_crisis") is True
    assert data.get("crisis_tier") == "high_severity"
    # The pre-check ensures helplines are immediately injected prior to GenAI call
    assert "helplines" in data
    
def test_quick_emotion_api():
    """Verify that quick emotion chips return formatted tools."""
    payload = {
        "emotion": "lonely",
        "profile": {
            "name": "Lonely Test User"
        }
    }
    response = client.post("/quick_emotion", json=payload)
    assert response.status_code == 200
    data = response.json()
    
    assert "solutions" in data
    assert len(data["solutions"]) == 3
    
    # Check struct of a solution
    first_sol = data["solutions"][0]
    assert "title" in first_sol
    assert "steps" in first_sol


# ── Admin Dashboard Endpoints ──

def test_admin_dashboard_html():
    """GET /admin serves the dashboard HTML page."""
    response = client.get("/admin")
    assert response.status_code == 200
    assert "VoiceMind Admin" in response.text

def test_admin_api_overview():
    """GET /admin/api/overview returns 200 (no auth required)."""
    response = client.get("/admin/api/overview")
    assert response.status_code == 200

def test_admin_api_users():
    """GET /admin/api/users returns 200."""
    response = client.get("/admin/api/users")
    assert response.status_code == 200

def test_admin_api_events():
    """GET /admin/api/events returns 200."""
    response = client.get("/admin/api/events")
    assert response.status_code == 200

def test_admin_api_crisis():
    """GET /admin/api/crisis returns 200."""
    response = client.get("/admin/api/crisis")
    assert response.status_code == 200

def test_admin_api_emotions():
    """GET /admin/api/emotions returns 200."""
    response = client.get("/admin/api/emotions")
    assert response.status_code == 200

def test_admin_api_study():
    """GET /admin/api/study returns 200."""
    response = client.get("/admin/api/study")
    assert response.status_code == 200

def test_admin_api_funnel():
    """GET /admin/api/funnel returns 200."""
    response = client.get("/admin/api/funnel")
    assert response.status_code == 200
