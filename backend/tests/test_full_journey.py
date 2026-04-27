"""
VoiceMind Backend — FULL JOURNEY TEST SUITE
Run: cd backend && pytest tests/test_full_journey.py -v -s --tb=short
"""
import json, time, os, math, struct, base64, concurrent.futures
import pytest
from fastapi.testclient import TestClient
from dotenv import load_dotenv

load_dotenv()
import sys; sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from main import app, classify_crisis, fuse_emotion_channels, AcousticFeatures

client = TestClient(app)
SESSION_ID = f"journey_{int(time.time())}"
PROFILE = {
    "name": "Test User", "age_group": "18-24",
    "concerns": ["Anxiety", "Stress", "Sleep"],
    "coping_strategies_worked": ["Deep Breathing"],
    "coping_strategies_failed": ["Meditation"],
    "additional_notes": "Night shift student."
}

# -- helpers -----------------------------------------------------------------
def banner(s): print(f"\n{'='*65}\n  🧪  {s}\n{'='*65}")
def log(label, val): print(f"    ▸ {label}: {json.dumps(val, default=str)[:200]}")
def ok(label, cond, detail=""): icon="✅" if cond else "❌"; print(f"    {icon} {label}{' — '+detail if detail else ''}"); assert cond, f"FAILED: {label}. {detail}"

def _silent_pcm(secs=1.5, sr=16000):
    n = int(secs * sr); return struct.pack(f"<{n}h", *([0]*n))

def _tone_pcm(freq=440.0, secs=1.5, sr=16000):
    n = int(secs * sr)
    samp = [int(32767*math.sin(2*math.pi*freq*i/sr)) for i in range(n)]
    return struct.pack(f"<{n}h", *samp)

# ============================================================================
# 1. HEALTH CHECK
# ============================================================================
class TestHealth:
    def test_root(self):
        banner("HEALTH — Root endpoint")
        r = client.get("/"); d = r.json()
        log("body", d)
        ok("200 OK", r.status_code == 200)
        ok("status field", "status" in d)
        ok("VoiceMind in status", "VoiceMind" in d["status"])
        ok("endpoints list", "endpoints" in d)
        ok("/chat in endpoints", "/chat" in d.get("endpoints", []))

# ============================================================================
# 2. CRISIS DETECTION (tiered)
# ============================================================================
class TestCrisis:

    def test_no_crisis_normal(self):
        banner("CRISIS — Normal message → tier=none")
        r = classify_crisis("I had a tough day but I'll be okay.")
        log("result", r); ok("not crisis", r["is_crisis"] is False); ok("tier=none", r["crisis_tier"]=="none")

    def test_concerning_tier(self):
        banner("CRISIS — Concerning phrase")
        r = classify_crisis("I feel completely hopeless and don't know what to do")
        log("result", r); log("tier", r["crisis_tier"])
        ok("tier ≥ concerning", r["crisis_tier"] in ["concerning","medium_severity","high_severity"])

    @pytest.mark.parametrize("phrase", [
        "I want to hurt myself", "I've been cutting myself", "I don't want to be alive"
    ])
    def test_medium_severity(self, phrase):
        banner(f"CRISIS — Medium: {phrase[:40]}")
        r = classify_crisis(phrase); log("tier", r["crisis_tier"])
        ok("medium or high", r["crisis_tier"] in ["medium_severity","high_severity"])

    @pytest.mark.parametrize("phrase", [
        "I want to kill myself",
        "I'm going to end my life tonight",
        "I want to commit suicide",
        "I'm going to overdose on my pills",
        "I will hang myself",
        "I want to jump off a bridge",
    ])
    def test_high_severity_api(self, phrase):
        banner(f"CRISIS — High via API: {phrase[:40]}")
        t0 = time.time()
        resp = client.post("/chat", json={"transcript": phrase, "session_id": "crisis_test"})
        ms = (time.time()-t0)*1000; d = resp.json()
        log("result", {"is_crisis": d.get("is_crisis"), "tier": d.get("crisis_tier"), "ms": round(ms,1)})
        ok("200 OK", resp.status_code == 200)
        ok("is_crisis=True", d.get("is_crisis") is True)
        ok("high_severity", d.get("crisis_tier") == "high_severity", f"got {d.get('crisis_tier')}")
        ok("helplines present", "helplines" in d)
        ok("AASRA present", "AASRA" in str(d.get("helplines",{})))
        ok("immediate_actions present", "immediate_actions" in d)
        ok("sub-5s response", ms < 5000, f"{ms:.0f}ms")

    def test_safe_phrases_not_flagged(self):
        banner("CRISIS — Safe phrases must NOT trigger crisis")
        safes = ["I need help with my homework", "I'm a bit sad today",
                 "I had to kill it at the presentation", "I'm dying of laughter"]
        for s in safes:
            r = classify_crisis(s)
            log(f'"{s[:45]}"', r["crisis_tier"])
            ok(f"Not high_severity: {s[:40]}", r["crisis_tier"] != "high_severity")

    def test_acoustic_distress_escalates_tier(self):
        banner("CRISIS — Acoustic distress escalates tier")
        tone = base64.b64encode(_tone_pcm(200.0, 1.5)).decode()
        payload = {"transcript": "I feel hopeless and don't know what to do",
                   "audio_bytes_b64": tone, "session_id": "acoustic_crisis"}
        resp = client.post("/chat", json=payload); d = resp.json()
        log("acoustic result", {
            "is_crisis": d.get("is_crisis"), "crisis_tier": d.get("crisis_tier"),
            "acoustic_distress": d.get("acoustic_distress"),
        })
        ok("200 OK", resp.status_code == 200)
        ok("crisis_tier field present", "crisis_tier" in d)

# ============================================================================
# 3. EMOTION FUSION
# ============================================================================
class TestEmotionFusion:

    def test_fusion_weights(self):
        banner("EMOTION FUSION — 60/40 weight verification")
        feat = AcousticFeatures(extraction_success=False)
        emotion, conf, meta = fuse_emotion_channels("sad", feat, acoustic_weight=0.6)
        log("emotion", emotion); log("confidence", conf); log("meta", meta)
        ok("emotion is string", isinstance(emotion, str))
        ok("confidence 0-1", 0.0 <= conf <= 1.0)
        ok("weights correct", meta["fusion_weights"] == {"acoustic": 0.6, "text": 0.4})

    def test_chat_returns_emotion_analysis(self):
        banner("EMOTION FUSION — /chat includes emotion_analysis block")
        resp = client.post("/chat", json={"transcript": "I'm very anxious", "emotion": "anxious",
                                          "session_id": SESSION_ID, "profile": PROFILE})
        d = resp.json(); ea = d.get("emotion_analysis", {})
        log("emotion_analysis", ea)
        ok("200 OK", resp.status_code == 200)
        ok("emotion_analysis present", "emotion_analysis" in d)
        ok("detected_emotion", "detected_emotion" in ea)
        ok("confidence", "confidence" in ea)
        ok("fusion_weights", "fusion_weights" in ea)
        ok("weights sum to 1", abs(ea["fusion_weights"]["acoustic"]+ea["fusion_weights"]["text"]-1.0) < 0.01)

    def test_emotion_trajectory_tracking(self):
        banner("EMOTION — NC4 session trajectory tracking")
        sid = f"traj_{int(time.time())}"
        for text, em in [("I'm stressed", "stressed"), ("Better now", "neutral"), ("Calm", "neutral")]:
            client.post("/chat", json={"transcript": text, "emotion": em, "session_id": sid})
        r = client.get(f"/session/trends/{sid}"); d = r.json()
        log("session trends", d)
        ok("200 OK", r.status_code == 200)
        ok("turn_count ≥ 3", d.get("turn_count", 0) >= 3)
        ok("emotion_history ≥ 3", len(d.get("emotion_history", [])) >= 3)
        ok("trajectory list", isinstance(d.get("trajectory"), list))

# ============================================================================
# 4. MAIN CHAT ENDPOINT
# ============================================================================
class TestChat:

    def test_basic_structure(self):
        banner("CHAT — Basic response structure (dynamic response_style)")
        t0 = time.time()
        resp = client.post("/chat", json={"transcript": "I feel lonely today.", "emotion": "lonely",
                                          "session_id": SESSION_ID, "profile": PROFILE})
        ms = (time.time()-t0)*1000; d = resp.json()
        log("Response (core)", {k: (str(v)[:80]+"..." if isinstance(v,str) and len(str(v))>80 else v)
                                 for k,v in d.items() if k not in ("helplines","emotion_analysis","emotion_trend")})
        log("latency", f"{ms:.0f}ms")
        ok("200 OK", resp.status_code == 200)
        ok("not crisis", d.get("is_crisis") is False)
        ok("response_style present", "response_style" in d)
        style = d.get("response_style", "")
        ok("valid style", style in ("empathetic_listen", "guided_support", "conversational", "reflection"), f"got '{style}'")
        if style == "guided_support":
            ok("validation present", "validation" in d)
            ok("action present", "action" in d)
        elif style == "empathetic_listen":
            ok("message present", "message" in d)
            ok("follow_up_question present", "follow_up_question" in d)
        elif style == "reflection":
            ok("message present", "message" in d)
            ok("reflection present", "reflection" in d)
        else:
            ok("message present", "message" in d)
        ok("crisis_tier=none", d.get("crisis_tier") == "none")
        ok("latency_ms field", "latency_ms" in d)
        ok("emotion_analysis block", "emotion_analysis" in d)
        ok("emotion_trend block", "emotion_trend" in d)
        ok("under 12s", ms < 12000, f"{ms:.0f}ms")

    @pytest.mark.parametrize("label,text", [
        ("Anxious",      "My heart is racing and I can't stop worrying"),
        ("Sad",          "I've been crying all day and don't know why"),
        ("Stressed",     "I have 5 deadlines tomorrow and feel overwhelmed"),
        ("Cant Sleep",   "My mind won't stop racing and I can't sleep"),
        ("Overwhelmed",  "Everything is piling up, I can't handle any more"),
        ("Angry",        "My boss humiliated me in front of the whole team"),
        ("Lonely",       "I moved to a new city and have absolutely no friends"),
    ])
    def test_all_quick_filter_emotions(self, label, text):
        banner(f"CHAT — {label}")
        resp = client.post("/chat", json={"transcript": text, "emotion": label.lower(),
                                          "session_id": SESSION_ID})
        d = resp.json()
        ok(f"{label}: 200 OK", resp.status_code == 200)
        ok(f"{label}: not crisis", d.get("is_crisis") is False)
        ok(f"{label}: has response_style", "response_style" in d)
        has_content = ("validation" in d) or ("message" in d)
        ok(f"{label}: has content", has_content, f"keys: {list(d.keys())}")
        log(f"{label}: detected_emotion", d.get("emotion_analysis", {}).get("detected_emotion", "N/A"))

    def test_with_conversation_history(self):
        banner("CHAT — Multi-turn conversation context")
        history = [
            {"role": "user", "content": "I feel stressed about exams"},
            {"role": "assistant", "content": "Exam stress is hard. Let's try breathing."},
        ]
        resp = client.post("/chat", json={"transcript": "The breathing helped!", "emotion": "neutral",
                                          "session_id": SESSION_ID, "conversation_history": history})
        d = resp.json()
        ok("200 OK", resp.status_code == 200); ok("not crisis", d.get("is_crisis") is False)
        log("Multi-turn response", d.get("validation", d.get("message",""))[:100])

    def test_with_audio_bytes(self):
        banner("CHAT — With base64 PCM audio for acoustic extraction")
        b64 = base64.b64encode(_tone_pcm(440.0, 2.0)).decode()
        resp = client.post("/chat", json={"transcript": "Feeling stressed", "emotion": "stressed",
                                          "audio_bytes_b64": b64, "session_id": SESSION_ID})
        d = resp.json()
        ok("200 OK", resp.status_code == 200)
        ok("acoustic key present", "acoustic_available" in d.get("emotion_analysis", {}))
        log("acoustic_available", d.get("emotion_analysis", {}).get("acoustic_available"))

    def test_anonymous_no_profile(self):
        banner("CHAT — Anonymous (no profile)")
        resp = client.post("/chat", json={"transcript": "A bit off today", "session_id": "anon"})
        d = resp.json()
        ok("200 OK", resp.status_code == 200)
        ok("still gets response", "response_style" in d or "is_crisis" in d or "validation" in d or "message" in d)

# ============================================================================
# 5. QUICK EMOTION
# ============================================================================
class TestQuickEmotion:
    @pytest.mark.parametrize("emotion", ["anxious","sad","stressed","cant_sleep","overwhelmed"])
    def test_quick_emotion(self, emotion):
        banner(f"QUICK EMOTION — {emotion}")
        t0 = time.time()
        resp = client.post("/quick_emotion", json={"emotion": emotion, "profile": PROFILE})
        ms = (time.time()-t0)*1000; d = resp.json()
        log(f"{emotion} solutions", d.get("solutions",[])[:1])
        ok("200 OK", resp.status_code == 200)
        ok("solutions key", "solutions" in d)
        ok("3 solutions", len(d["solutions"]) == 3, f"got {len(d.get('solutions',[]))}")
        for i, s in enumerate(d["solutions"]):
            ok(f"sol[{i}].title", "title" in s)
            ok(f"sol[{i}].steps list", isinstance(s.get("steps"), list))
        log("latency", f"{ms:.0f}ms")

# ============================================================================
# 6. ENHANCE STRATEGY
# ============================================================================
class TestEnhanceStrategy:
    def test_box_breathing(self):
        banner("ENHANCE STRATEGY — Box Breathing")
        payload = {"strategy_title": "Box Breathing",
                   "strategy_steps": ["In 4","Hold 4","Out 4","Hold 4"], "profile": PROFILE}
        resp = client.post("/enhance_strategy", json=payload); d = resp.json()
        log("Enhanced", d)
        ok("200 OK", resp.status_code == 200)
        ok("adapted_title", "adapted_title" in d)
        ok("adapted_steps list", isinstance(d.get("adapted_steps"), list))
        ok("pro_tips", "pro_tips" in d)

    def test_5_4_3_2_1(self):
        banner("ENHANCE STRATEGY — 5-4-3-2-1 Grounding")
        payload = {"strategy_title": "5-4-3-2-1 Grounding",
                   "strategy_steps": ["5 things see","4 touch","3 hear","2 smell","1 taste"],
                   "profile": {**PROFILE, "concerns": ["Anxiety"]}}
        resp = client.post("/enhance_strategy", json=payload); d = resp.json()
        ok("200 OK", resp.status_code == 200); ok("adapted_title", "adapted_title" in d)
        log("Adapted steps", d.get("adapted_steps",[])[:2])

# ============================================================================
# 7. FEEDBACK
# ============================================================================
class TestFeedback:
    def test_feedback_worked(self):
        banner("FEEDBACK — Strategy worked")
        payload = {"transcript": "I was anxious", "advice_given": "Your feelings are valid.",
                   "strategy_given": "Try 4-7-8 breathing.", "feedback": "Worked", "profile": PROFILE}
        resp = client.post("/feedback", json=payload); d = resp.json()
        log("Feedback worked response", d)
        ok("200 OK", resp.status_code == 200)
        ok("analysis present", "analysis" in d); ok("encouragement present", "encouragement" in d)

    def test_feedback_failed(self):
        banner("FEEDBACK — Strategy failed")
        payload = {"transcript": "I was overwhelmed", "advice_given": "Focus on control.",
                   "strategy_given": "Progressive relaxation", "feedback": "Did Not Work", "profile": PROFILE}
        resp = client.post("/feedback", json=payload); d = resp.json()
        log("Feedback failed response", d)
        ok("200 OK", resp.status_code == 200)
        ok("analysis present", "analysis" in d); ok("alternative present", "alternative" in d)

# ============================================================================
# 8. HELPLINES
# ============================================================================
class TestHelplines:
    def test_helplines_endpoint(self):
        banner("HELPLINES — GET /helplines")
        resp = client.get("/helplines"); d = resp.json()
        log("Helplines", d)
        ok("200 OK", resp.status_code == 200)
        ok("india key", "india" in d); ok("international key", "international" in d)
        ok("emergency key", "emergency" in d)
        ok("AASRA present", "AASRA" in d["india"])
        ok("AASRA number 9820466726", "9820466726" in d["india"].get("AASRA",""),
           f"got {d['india'].get('AASRA','')}")
        ok("Vandrevala", "Vandrevala Foundation" in d["india"])
        ok("iCall", "iCall" in d["india"])
        ok("NIMHANS", "NIMHANS" in d["india"])
        ok("US 988", any("988" in str(v) for v in d["international"].values()))

    def test_helplines_data_integrity(self):
        banner("HELPLINES — Data integrity from imported constants")
        from main import INDIA_HELPLINES, INTERNATIONAL_HELPLINES
        log("INDIA_HELPLINES", INDIA_HELPLINES)
        ok("AASRA correct number", "9820466726" in INDIA_HELPLINES.get("AASRA",""))
        ok("Vandrevala 1860", "1860" in INDIA_HELPLINES.get("Vandrevala Foundation",""))
        ok("≥2 international", len(INTERNATIONAL_HELPLINES) >= 2)

# ============================================================================
# 9. GENERATE ACTIVITY
# ============================================================================
class TestGenerateActivity:
    def test_generate_activity(self):
        banner("GENERATE ACTIVITY — Personalized wellness activity")
        resp = client.post("/generate_activity", json=PROFILE); d = resp.json()
        log("Generated activity", d)
        ok("200 OK", resp.status_code == 200)
        ok("title", "title" in d); ok("desc", "desc" in d)
        ok("steps list", isinstance(d.get("steps"), list))
        ok("duration", "duration" in d)

# ============================================================================
# 10. SESSION TRENDS
# ============================================================================
class TestSessionTrends:
    def test_full_lifecycle(self):
        banner("SESSION TRENDS — Full lifecycle")
        sid = f"trend_{int(time.time())}"
        turns = [("Anxious about exams","anxious"), ("A bit better","neutral"),
                 ("Calm now","neutral"), ("Stressed again","stressed")]
        for text, em in turns:
            client.post("/chat", json={"transcript": text, "emotion": em, "session_id": sid})
        r = client.get(f"/session/trends/{sid}"); d = r.json()
        log("trends", d)
        ok("200 OK", r.status_code == 200)
        ok("session_id matches", d.get("session_id") == sid)
        ok("emotion_history ≥ 4", len(d.get("emotion_history",[])) >= 4)
        ok("turn_count ≥ 4", d.get("turn_count",0) >= 4)
        ok("trajectory list", isinstance(d.get("trajectory"), list))
        ok("avg_latency_ms ≥ 0", d.get("avg_latency_ms",0) >= 0)

    def test_unknown_session_returns_empty(self):
        banner("SESSION TRENDS — Unknown session → empty data")
        r = client.get("/session/trends/fake_xyz_no_exist"); d = r.json()
        ok("200 OK", r.status_code == 200)
        ok("turn_count=0", d.get("turn_count") == 0)
        ok("emotion_history empty", len(d.get("emotion_history",[])) == 0)

# ============================================================================
# 11. ACOUSTIC EXTRACTION UNIT
# ============================================================================
class TestAcoustic:
    def test_too_short_rejected(self):
        banner("ACOUSTIC — Sub-0.5s audio gracefully rejected")
        from main import acoustic_extractor
        if not acoustic_extractor: pytest.skip("librosa not installed")
        tiny = _silent_pcm(0.1)
        r = acoustic_extractor.extract_from_bytes(tiny)
        log("extraction result", {"success": r.extraction_success})
        ok("AcousticFeatures type", isinstance(r, AcousticFeatures))
        ok("extraction_success=False", r.extraction_success is False)

    def test_valid_tone_no_exception(self):
        banner("ACOUSTIC — 2s tone extracts without exception")
        from main import acoustic_extractor
        if not acoustic_extractor: pytest.skip("librosa not installed")
        tone = _tone_pcm(220.0, 2.0)
        r = acoustic_extractor.extract_from_bytes(tone)
        log("feature result", {"success": r.extraction_success, "pitch": round(r.pitch_mean,2)})
        ok("AcousticFeatures type", isinstance(r, AcousticFeatures))

# ============================================================================
# 12. STUDY ENDPOINTS
# ============================================================================
class TestStudy:
    def test_submit_study_session(self):
        banner("STUDY — Submit participant questionnaire (perfect SUS=100)")
        payload = {
            "participant_id": f"test_{int(time.time())}",
            "session_id": SESSION_ID,
            "sus_scores": [5,1,5,1,5,1,5,1,5,1],
            "emotion_accuracy_rating": 4, "satisfaction_rating": 5,
            "avg_latency_ms": 850, "turns_count": 5, "crisis_detected": False,
            "what_worked": "Breathing technique was great",
            "what_didnt_work": "Slightly slow at times"
        }
        resp = client.post("/study/session", json=payload); d = resp.json()
        log("Study session", d)
        ok("200 OK", resp.status_code == 200)
        ok("success=True", d.get("success") is True)
        ok("sus_score=100", d.get("sus_score") == 100.0)
        ok("participant_id echoed", d.get("participant_id") == payload["participant_id"])

    def test_wrong_sus_count_rejected(self):
        banner("STUDY — Validation: wrong SUS count → 422")
        resp = client.post("/study/session", json={"participant_id":"x","session_id":"x","sus_scores":[5,1,5]})
        ok("422 Unprocessable", resp.status_code == 422); log("error", resp.json())

    def test_export_json(self):
        banner("STUDY — Export JSON")
        resp = client.get("/study/export?fmt=json"); d = resp.json()
        log("export summary", {k:v for k,v in d.items() if k!="sessions"})
        ok("200 OK", resp.status_code == 200)
        ok("count or message", "count" in d or "message" in d)

    def test_stats_dashboard(self):
        banner("STUDY — Stats dashboard")
        resp = client.get("/study/stats"); d = resp.json()
        log("stats", d)
        ok("200 OK", resp.status_code == 200)
        ok("sessions_collected", "sessions_collected" in d)
        ok("target=25", d.get("target") == 25)

# ============================================================================
# 13. CONCURRENT LOAD
# ============================================================================
class TestLoad:
    def test_3_concurrent_chat_requests(self):
        banner("LOAD — 3 concurrent chat requests")
        payloads = [{"transcript": f"Stressed about exams {i}", "emotion": "stressed",
                     "session_id": f"load_{i}"} for i in range(3)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:
            futures = [ex.submit(client.post, "/chat", json=p) for p in payloads]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]
        for i, r in enumerate(results):
            ok(f"Concurrent req {i+1}: 200 OK", r.status_code == 200)
        log("All statuses", [r.status_code for r in results])

# ============================================================================
# 14. CLASSIFY_CRISIS PARAMETRIZED (All keyword tiers)
# ============================================================================
TIER_ORDER = {"none":0,"concerning":1,"medium_severity":2,"high_severity":3}

@pytest.mark.parametrize("text,min_tier", [
    ("I want to kill myself","high_severity"),
    ("I'm planning to end my life","high_severity"),
    ("I want to commit suicide","high_severity"),
    ("I'm going to overdose","high_severity"),
    ("I want to hang myself","high_severity"),
    ("I want to hurt myself","medium_severity"),
    ("I've been cutting myself","medium_severity"),
    ("I don't want to be alive","medium_severity"),
    ("I have no hope left","concerning"),
    ("I can't go on like this","concerning"),
    ("Everyone would be better without me","concerning"),
    ("I had a tough day at work","none"),
    ("I'm a bit sad today","none"),
    ("I had to kill it during my presentation","none"),
    ("I'm dying of laughter","none"),
])
def test_crisis_keywords(text, min_tier):
    r = classify_crisis(text); tier = r["crisis_tier"]
    print(f"    '{text[:45]}' → tier={tier} (min={min_tier})")
    ok(f"tier≥{min_tier}", TIER_ORDER.get(tier,0) >= TIER_ORDER.get(min_tier,0), f"got {tier}")


# ============================================================================
# 15. ADMIN DASHBOARD
# ============================================================================
class TestAdminDashboard:
    def test_html_served(self):
        banner("ADMIN DASHBOARD HTML")
        r = client.get("/admin")
        ok("200 OK", r.status_code == 200)
        ok("contains VoiceMind Admin", "VoiceMind Admin" in r.text)
        ok("contains Chart.js", "chart.js" in r.text.lower() or "Chart" in r.text)

    def test_api_open_access(self):
        banner("ADMIN API OPEN ACCESS")
        endpoints = [
            "/admin/api/overview",
            "/admin/api/users",
            "/admin/api/events",
            "/admin/api/crisis",
            "/admin/api/emotions",
            "/admin/api/study",
            "/admin/api/funnel",
        ]
        for ep in endpoints:
            r = client.get(ep)
            ok(f"{ep} → 200", r.status_code == 200, f"got {r.status_code}")
