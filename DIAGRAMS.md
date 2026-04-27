# VoiceMind: A Voice-Based Agent AI Companion for Mental Health Support — Project Diagrams

> All diagrams use [Mermaid](https://mermaid.js.org/) syntax. Render in any Markdown viewer with Mermaid support (GitHub, VS Code with Mermaid extension, etc.).

---

## 1. System Architecture (High Level)

```mermaid
graph TB
    subgraph Flutter["Flutter Client (iOS / Android / Web / macOS)"]
        UI[Chat UI / Coping Toolbox]
        Audio[Audio Capture / STT]
        STTFlow[Turn-based STT → /chat → TTS]
        Offline[Offline Engine<br>10 categories]
        Auth[Firebase Auth<br>Google Sign-In]
    end

    subgraph Backend["FastAPI Backend (:8000)"]
        REST["/chat /quick_emotion<br>/feedback /helplines"]
        WS["/ws/transcribe"]
        Acoustic["Acoustic Analysis<br>71 features · librosa"]
        ADK["ADK Multi-Agent<br>Triage → Therapist / Crisis"]
        Admin["/admin<br>Research Dashboard"]
    end

    subgraph Google["Google Cloud"]
        Gemini[Gemini 2.5 Flash]
        Firestore[(Cloud Firestore)]
        FireAuth[Firebase Auth]
    end

    UI --> Audio
    UI --> STTFlow
    UI <--> Offline
    Audio -->|JSON HTTP| REST
    Auth --> FireAuth

    REST --> ADK
    REST --> Acoustic
    ADK --> Gemini
    Acoustic -->|Events| Firestore
    Admin -->|Reads| Firestore

    style Flutter fill:#E3F2FD,stroke:#1565C0
    style Backend fill:#FFF3E0,stroke:#E65100
    style Google fill:#FCE4EC,stroke:#C62828
```

---

## 2. Audio Pipeline Flow

```mermaid
sequenceDiagram
    participant U as User
    participant F as Flutter Client
    participant BE as FastAPI /chat
    participant FS as Firestore

    U->>F: Tap mic / Shake phone
    F->>F: Device STT captures speech
    F->>BE: POST /chat transcript
    BE-->>F: validation + insight + action
    F->>U: Play AI response with device TTS
    F->>F: Update EmotionChip + Sparkline
```

---

## 3. Crisis Detection — 3-Tier Architecture

```mermaid
flowchart TD
    Input[User Input<br>Voice or Text] --> T1

    subgraph Tier1["Tier 1 — Client-Side (<1ms)"]
        T1{Dart regex match<br>34 crisis phrases?}
        T1 -->|Yes| Crisis1[Vibration 3×500ms<br>Full-screen helpline modal<br>One-tap calling]
        T1 -->|No| T2
    end

    subgraph Tier2["Tier 2 — REST Pre-check (<5ms)"]
        T2["/chat → classify_crisis()"]
        T2 --> T2Check{Crisis detected?}
        T2Check -->|High/Medium| Crisis2[Static crisis response<br>No API cost incurred]
        T2Check -->|No| ADK[Route to ADK Pipeline]
    end

    subgraph Tier3["Tier 3 — WebSocket Accumulator"]
        WSAccum[Accumulate speech turns]
        WSAccum --> T3Check{Crisis phrase<br>in accumulated text?}
        T3Check -->|Yes| Crisis3[Emit crisis_alert JSON<br>Interrupt AI playback]
        T3Check -->|No| Continue[Continue session]
    end

    ADK -.-> WSAccum

    subgraph Helplines["Emergency Resources"]
        H1["🇮🇳 AASRA: 9820466726"]
        H2["🇮🇳 Vandrevala: 1860-2662-345"]
        H3["🇺🇸 988 Suicide Lifeline"]
        H4["🇬🇧 Samaritans: 116 123"]
    end

    Crisis1 --> Helplines
    Crisis2 --> Helplines
    Crisis3 --> Helplines

    style Tier1 fill:#FFEBEE,stroke:#C62828
    style Tier2 fill:#FFF3E0,stroke:#E65100
    style Tier3 fill:#FFF8E1,stroke:#F57F17
    style Helplines fill:#E8F5E9,stroke:#2E7D32
```

---

## 4. ADK Multi-Agent Pipeline

```mermaid
flowchart LR
    Input["User Message<br>+ Emotion Score<br>+ Profile"] --> Triage

    subgraph ADK["Google ADK Runtime (InMemorySessionService)"]
        Triage["🔀 Triage Agent<br>gemini-2.5-flash"]
        Therapist["💚 Therapist Agent<br>gemini-2.5-flash<br>CBT / DBT / Mindfulness"]
        Crisis["🚨 Crisis Agent<br>gemini-2.5-flash<br>De-escalation only"]
    end

    Triage -->|Life-threatening| Crisis
    Triage -->|Normal| Therapist

    Therapist --> Styles

    subgraph Styles["Dynamic Response Styles"]
        S1["empathetic_listen<br>Warm ack + follow-up Q"]
        S2["guided_support<br>Validation → Insight → Action"]
        S3["conversational<br>Natural dialogue"]
        S4["reflection<br>Psychoeducational reframe"]
    end

    Crisis --> CrisisResp["Safety-first response<br>Helpline instructions<br>De-escalation script"]

    style ADK fill:#E3F2FD,stroke:#1565C0
    style Styles fill:#F3E5F5,stroke:#6A1B9A
```

---

## 5. Dual-Channel Emotion Fusion

```mermaid
flowchart LR
    Voice["🎤 Voice Input<br>(raw PCM)"] --> AcousticPipe
    Voice --> TextPipe

    subgraph AcousticPipe["Acoustic Channel (60%)"]
        FeatExtract["librosa Feature Extraction<br>71 features"]
        RF["Random Forest<br>100 trees · scikit-learn"]
        FeatExtract --> RF
        RF --> Sa["s_a ∈ [0,1]"]
    end

    subgraph TextPipe["Text Channel (40%)"]
        Transcript["Speech-to-Text<br>Transcript"]
        Gemini["Gemini 2.5 Flash Lite<br>Emotion inference"]
        Transcript --> Gemini
        Gemini --> St["s_t ∈ [0,1]"]
    end

    Sa --> Fusion["Fusion: s = 0.6·s_a + 0.4·s_t"]
    St --> Fusion

    Fusion --> Label["Fused Emotion Label<br>+ Confidence %"]
    Label --> Chip["EmotionAnalysisChip<br>in chat UI"]
    Label --> Sparkline["EmotionSparkline<br>emoji timeline"]
    Label --> ADK["Injected into<br>ADK agent context"]

    subgraph AcousticFeatures["71 Acoustic Features"]
        M["MFCC (13 + Δ + ΔΔ)"]
        P["Pitch (F0 mean/std)"]
        J["Jitter · Shimmer"]
        H["HNR"]
        E["Energy (RMS)"]
        SC["Spectral Centroid/Contrast"]
        PC["Pause Count"]
    end

    FeatExtract -.-> AcousticFeatures

    style AcousticPipe fill:#E8F5E9,stroke:#2E7D32
    style TextPipe fill:#E3F2FD,stroke:#1565C0
    style AcousticFeatures fill:#FFF3E0,stroke:#E65100
```

---

## 6. User Journey / App Flow

```mermaid
stateDiagram-v2
    [*] --> AppLaunch

    state AppLaunch {
        [*] --> CheckAuth
        CheckAuth --> GoogleSignIn: Not authenticated
        CheckAuth --> CheckOnboarding: Authenticated
        GoogleSignIn --> CheckOnboarding: Sign-in success
    }

    state CheckOnboarding {
        [*] --> OnboardingScreen: First time
        [*] --> MainApp: Onboarding complete
        OnboardingScreen --> ProfileSetup
        ProfileSetup --> MainApp
    }

    state MainApp {
        [*] --> ChatScreen
        ChatScreen --> CopingToolbox: Tab nav
        ChatScreen --> ProfilePage: Tab nav
        CopingToolbox --> ChatScreen: Tab nav
        ProfilePage --> ChatScreen: Tab nav

        state ChatScreen {
            [*] --> Idle
            Idle --> Recording: Tap mic / Shake
            Recording --> Processing: Release / Pause
            Processing --> AIResponse: Response received
            AIResponse --> Idle: Response complete

            state Processing {
                [*] --> TurnBasedVoice
                TurnBasedVoice --> [*]: STT text to /chat, then device TTS
            }
        }

        state CopingToolbox {
            state "Guided Breathing" as Breathing
            state "Grounding Exercises" as Grounding
            state "CBT Techniques" as CBT
            state "Mindfulness" as Mindfulness
            state "Self-Compassion" as SelfCompassion
            state "Somatic Release" as Somatic
        }

        state ProfilePage {
            state "Name / Age / Concerns" as EditProfile
            state "Voice Companion (30 HD voices)" as VoiceSelect
            state "Strategy Tracking" as CopingHistory
            state "Firestore Sync" as CloudSync
        }
    }

    MainApp --> CrisisModal: Crisis detected (any tier)
    CrisisModal --> MainApp: Dismissed after viewing helplines
```

---

## 7. Admin Research Dashboard — Data Flow

```mermaid
flowchart TB
    subgraph Sources["Event Sources"]
        App["Flutter App"]
        Backend["FastAPI Backend"]
    end

    subgraph Events["Firestore: admin_events"]
        E1["session_started"]
        E2["user_turn"]
        E3["agent_turn"]
        E4["emotion_detected"]
        E5["crisis_detected"]
        E6["voice_turn_started"]
        E7["acoustic_analysis"]
        E8["voice_mode_active"]
        E9["feedback_submitted"]
    end

    subgraph Dashboard["/admin Dashboard (10 tabs)"]
        T1["📊 Overview<br>DAU · Sessions · Crisis"]
        T2["👤 Users<br>Per-user activity"]
        T3["💬 Sessions<br>Transcripts · Duration"]
        T4["😊 Emotions<br>Distribution · Heatmap"]
        T5["🚨 Crisis<br>Real-time log · Tiers"]
        T6["📈 Funnel<br>Signup → Session → Return"]
        T7["⏱ Engagement<br>Session time · Retention"]
        T8["📋 Study<br>SUS scores · Satisfaction"]
        T9["🔍 Traces<br>Full event log"]
        T10["📝 Logs<br>System events"]
    end

    App --> E1 & E2 & E9
    Backend --> E3 & E4 & E5 & E6 & E7 & E8

    E1 & E2 & E3 & E4 & E5 & E6 & E7 & E8 & E9 --> Dashboard

    subgraph Viz["Chart.js Visualizations"]
        Doughnut["Emotion doughnut"]
        Bar["Platform bar chart"]
        Line["Trend line chart"]
        Heatmap["Emotion heatmap"]
    end

    Dashboard --> Viz

    style Sources fill:#E3F2FD,stroke:#1565C0
    style Events fill:#FFF3E0,stroke:#E65100
    style Dashboard fill:#E8F5E9,stroke:#2E7D32
    style Viz fill:#F3E5F5,stroke:#6A1B9A
```

---

## 8. Firestore Data Model

```mermaid
erDiagram
    USERS {
        string uid PK "Firebase UID"
        string name
        string age_range
        string concerns
        string voice_preference
        string platform
        timestamp created_at
        timestamp last_active
    }

    USER_PROFILE {
        string uid FK "→ users"
        list worked_strategies
        list failed_strategies
        string voice_preference
        boolean has_seen_onboarding
    }

    USER_SESSIONS {
        string session_id PK "session_{epoch_ms}"
        string uid FK "→ users"
        timestamp started_at
        timestamp ended_at
        int turn_count
        string dominant_emotion
    }

    ADMIN_EVENTS {
        string id PK "auto-generated"
        string type "session_started | user_turn | crisis_detected | ..."
        timestamp timestamp
        string room "optional session / correlation id"
        string text "transcript excerpt"
        string tier "crisis tier (if applicable)"
        map features "acoustic features (if applicable)"
        map metadata "additional data"
    }

    USERS ||--|| USER_PROFILE : "has"
    USERS ||--o{ USER_SESSIONS : "has many"
    USERS ||--o{ ADMIN_EVENTS : "generates"
```

---

## 9. Offline Coping Engine

```mermaid
flowchart TB
    Input["User utterance"] --> KW["Keyword matching<br>10 emotion categories"]

    KW --> Cat{Matched category}

    Cat --> C1["😰 Anxious"]
    Cat --> C2["😢 Sad"]
    Cat --> C3["😠 Angry"]
    Cat --> C4["😫 Stressed"]
    Cat --> C5["😴 Sleep"]
    Cat --> C6["😞 Lonely"]
    Cat --> C7["😨 Overwhelmed"]
    Cat --> C8["😟 Worried"]
    Cat --> C9["💔 Worthless"]
    Cat --> C10["😐 Numb"]
    Cat --> C0["❓ Default"]

    C1 & C2 & C3 & C4 & C5 & C6 & C7 & C8 & C9 & C10 & C0 --> Resp["Random response<br>2-3 per category"]

    Resp --> Tools["Suggest Coping Tool"]

    subgraph CopingTools["20 Coping Tools × 6 Categories"]
        T1["🫁 Breathing (4 exercises)"]
        T2["🌍 Grounding (4 exercises)"]
        T3["🧘 Somatic Release (3 exercises)"]
        T4["🧠 CBT (3 techniques)"]
        T5["🕯 Mindfulness (3 techniques)"]
        T6["💕 Self-Compassion (3 techniques)"]
    end

    Tools --> CopingTools

    subgraph Wellness["18 Wellness Activities × 7 Categories"]
        W1["🧘 Meditation"]
        W2["🏃 Movement"]
        W3["📝 Journaling"]
        W4["🌿 Nature"]
        W5["🎨 Creative"]
        W6["🛁 Self-Care"]
        W7["👫 Social"]
    end

    Tools --> Wellness

    style CopingTools fill:#E8F5E9,stroke:#2E7D32
    style Wellness fill:#E3F2FD,stroke:#1565C0
```

---

## 10. Test Architecture

```mermaid
flowchart LR
    subgraph Flutter["Flutter Tests (160)"]
        UT["Unit Tests (test/)"]
        WT["Widget Tests (test/)"]
        IT["Integration Tests<br>(integration_test/)"]

        subgraph UTDetails["Unit Test Coverage"]
            UT1["OfflineEngine responses"]
            UT2["Crisis detection (34 phrases)"]
            UT3["SUS score calculation"]
            UT4["UserProfile lifecycle"]
            UT5["Coping tool data integrity"]
            UT6["Emotion category coverage"]
        end

        subgraph ITDetails["Integration Test Coverage"]
            IT1["Full user journey"]
            IT2["Profile persistence"]
            IT3["Emotion sparkline"]
            IT4["Breathing session math"]
            IT5["Wellness activity validation"]
        end

        UT --> UTDetails
        IT --> ITDetails
    end

    subgraph Backend["Backend Tests (89)"]
        BE1["Endpoint tests<br>health, chat, helplines"]
        BE2["Acoustic feature tests<br>71-feature extraction"]
        BE3["ADK agent tests<br>triage, therapist, crisis"]
        BE4["Full journey tests<br>E2E with auth + turn-based voice flow"]
    end

    style Flutter fill:#E3F2FD,stroke:#1565C0
    style Backend fill:#FFF3E0,stroke:#E65100
```

---

## 11. Deployment Architecture

```mermaid
flowchart TB
    subgraph Client["Client Platforms"]
        iOS["📱 iOS"]
        Android["📱 Android"]
        Web["🌐 Web (Chrome)"]
        macOS["💻 macOS"]
    end

    subgraph GCP["Google Cloud Platform"]
        CR["Cloud Run<br>FastAPI Backend"]
        FS["Cloud Firestore<br>Data + Events"]
        FBAuth["Firebase Auth<br>Google Sign-In"]
        GAI["Google AI<br>Gemini 2.5 Flash"]
    end

    subgraph Serverless["Serverless Billing"]
        S1["Cloud Run: per-request"]
        S2["Firestore: per-read/write"]
        S3["Gemini API: per-token"]
    end

    iOS & Android & Web & macOS --> CR
    iOS & Android & Web & macOS --> FBAuth

    CR --> GAI & FS

    GCP -.-> Serverless

    style Client fill:#E3F2FD,stroke:#1565C0
    style GCP fill:#E8F5E9,stroke:#2E7D32
    style Serverless fill:#FFF8E1,stroke:#F57F17
```

---

## 12. Research Contribution Mapping

```mermaid
mindmap
    root((VoiceMind))
        NC1[Dual-Channel Fusion]
            71 acoustic features
            60% acoustic / 40% text
            79.1% accuracy
            Lin 2020 · Marie 2025
            Baltrušaitis 2018
        NC2[Crisis Detection]
            34 phrases · 3 tiers
            Zero false-negative
            Client + REST + WS
            < 1ms Tier 1 latency
            Cui 2024 · Bai 2022
        NC3[ADK Multi-Agent]
            Triage → Therapist / Crisis
            4 response styles
            ReAct paradigm
            Constitutional AI safety
            Yao 2023 · Touvron 2023
        NC4[Offline Engine]
            10 emotion categories
            20 coping tools
            18 wellness activities
            Zero network latency
        NC5[Voice-first turn loop]
            User speaks with STT
            /chat returns empathic response
            Device TTS reads response
            Same-stack acoustic + crisis
```
