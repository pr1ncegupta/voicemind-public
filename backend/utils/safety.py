"""
VoiceMind — Shared Crisis Detection & Safety Utilities

Centralised module for tiered crisis detection, helplines, and crisis response.
Imported by main.py (FastAPI).

Research basis:
  A7 (Cui 2024) — Whisper+LLM achieves 80.7% on suicide detection.
  A8 (Marie 2025) — acoustic markers (jitter, shimmer) are validated crisis signals.
  A14 (Constitutional AI) — zero-false-negative policy for safety.
  3 tiers: high_severity → immediate overlay, medium → check-in, concerning → gentle
"""

import re
from typing import Dict, Optional

# ==============================================================================
# CRISIS TIER PATTERNS (regex, word-boundary aware)
# ==============================================================================

CRISIS_TIERS = {
    "high_severity": [
        r"\b(suicide|suicidal)\b",
        r"\bkill\s*(my)?self\b",
        r"\bwant\s*(to\s*)?die\b",
        r"\bend\s*(it|my\s*(life|pain))\b",
        r"\bhurt\s*(my)?self\b",
        r"\bself[\s-]?harm\b",
        r"\b(cut|cutt?ing)\s*(my)?self\b",
        r"\boverdose\b",
        r"\bno\s*reason\s*to\s*live\b",
        r"\bbetter\s*off\s*dead\b",
        r"\bhang\s*(my)?self\b",
        r"\bjump\s*(off|from)\b",
        r"\bcommit\s*suicide\b",
    ],
    "medium_severity": [
        r"\bcan'?t\s*(go|do)\s*(this|on)\b",
        r"\b(hopeless|worthless|helpless)\b",
        r"\bno\s*point\b",
        r"\bgiving\s*up\b",
        r"\bwish\s*i\s*(wasn'?t|were\s*not)\s*(here|alive)\b",
        r"\bno\s*(one|body)\s*(cares|loves\s*me)\b",
        r"\bdon'?t\s*want\s*to\s*be\s*alive\b",
    ],
    "concerning": [
        r"\b(exhausted|drained|empty)\s*(inside)?\b",
        r"\bisolated\b",
        r"\bburden\s*(to|on)\s*(everyone|others|family)\b",
        r"\bcan'?t\s*(sleep|eat|function)\b",
        r"\bno\s*hope\s*(left)?\b",
        r"\beveryone\s*would\s*be\s*better\b",
    ]
}

# Acoustic distress thresholds (A8 — Marie 2025 systematic review)
ACOUSTIC_DISTRESS_THRESHOLDS = {"jitter": 0.03, "shimmer": 0.2}

# ==============================================================================
# HELPLINES
# ==============================================================================

INDIA_HELPLINES = {
    "AASRA": "91-9820466726",
    "Vandrevala Foundation": "1860-2662-345",
    "iCall": "91-22-25521111",
    "NIMHANS": "080-46110007",
    "Sneha India": "91-44-24640050"
}
INTERNATIONAL_HELPLINES = {
    "US (988 Lifeline)": "988",
    "UK (Samaritans)": "116 123",
    "Australia (Lifeline)": "13 11 14",
}


# ==============================================================================
# CLASSIFY_CRISIS — main entry point
# ==============================================================================

def classify_crisis(text: str, features=None) -> Dict:
    """
    Tiered crisis classification combining keyword regex + acoustic distress signals.
    Returns tier ('none', 'concerning', 'medium_severity', 'high_severity') + metadata.

    Args:
        text: User transcript to classify.
        features: Optional AcousticFeatures instance (from main.py). If provided and
                  the features indicate acoustic distress, the tier is escalated.
    """
    text_lower = text.lower()
    detected_tier = "none"
    matched_patterns = []

    for tier in ["high_severity", "medium_severity", "concerning"]:
        for pattern in CRISIS_TIERS[tier]:
            if re.search(pattern, text_lower):
                detected_tier = tier
                matched_patterns.append(pattern)
                break
        if detected_tier == tier and tier in ["high_severity", "medium_severity"]:
            break

    # Acoustic distress escalation (A8): high jitter + shimmer = escalate one tier
    acoustic_distress = False
    if features and getattr(features, "extraction_success", False):
        acoustic_distress = (
            getattr(features, "jitter", 0) > ACOUSTIC_DISTRESS_THRESHOLDS["jitter"] or
            getattr(features, "shimmer", 0) > ACOUSTIC_DISTRESS_THRESHOLDS["shimmer"]
        )
        if acoustic_distress:
            if detected_tier == "none":
                detected_tier = "concerning"
            elif detected_tier == "concerning":
                detected_tier = "medium_severity"
            elif detected_tier == "medium_severity":
                detected_tier = "high_severity"

    is_crisis = detected_tier in ["high_severity", "medium_severity"]
    return {
        "is_crisis": is_crisis,
        "crisis_tier": detected_tier,
        "acoustic_distress": acoustic_distress,
        "matched_patterns": matched_patterns,
    }


def get_crisis_response(tier: str = "high_severity") -> dict:
    """Return a structured crisis response for the given tier."""
    messages = {
        "high_severity": "I'm really concerned about what you're sharing. Your life matters deeply, and there are people who want to help you right now.",
        "medium_severity": "It sounds like you're carrying a lot right now. I want you to know you don't have to go through this alone.",
        "concerning": "I can hear how much you're struggling. That takes courage to share. Would you like to talk about what's making things feel so hard?"
    }
    return {
        "is_crisis": True,
        "crisis_tier": tier,
        "message": messages.get(tier, messages["high_severity"]),
        "helplines": {"India": INDIA_HELPLINES, "International": INTERNATIONAL_HELPLINES},
        "immediate_actions": [
            "Call one of the helplines above — they're available 24/7",
            "If in immediate danger, call 112 (India) or 911 (US)",
            "Reach out to a trusted friend or family member",
            "Go to your nearest emergency room if you feel unsafe"
        ]
    }


# Backward-compatible wrapper (legacy compatibility)
def detect_crisis(text: str) -> bool:
    """Simple boolean check — returns True if crisis detected."""
    return classify_crisis(text)["is_crisis"]
