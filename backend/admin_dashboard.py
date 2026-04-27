"""
VoiceMind Admin Dashboard — comprehensive research monitoring.
No authentication required — open access for local/dev use.
"""

from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from typing import Optional
import datetime as dt

router = APIRouter(prefix="/admin", tags=["admin"])

fs_db = None

def init(firestore_db, firebase_auth=None):
    global fs_db
    fs_db = firestore_db


# ── Data API endpoints ──

@router.get("/api/overview")
async def api_overview():
    """Dashboard overview KPIs."""
    if not fs_db:
        return {"error": "Firestore not available"}
    try:
        users_ref = fs_db.collection("users")
        users = list(users_ref.stream())
        
        events_ref = fs_db.collection("admin_events")
        now = dt.datetime.now(dt.timezone.utc)
        day_ago = now - dt.timedelta(days=1)
        week_ago = now - dt.timedelta(days=7)
        
        all_events = list(events_ref.order_by("timestamp", direction="DESCENDING").limit(5000).stream())
        
        total_sessions = sum(1 for e in all_events if e.to_dict().get("type") == "session_started")
        crisis_events = [e for e in all_events if e.to_dict().get("type") == "crisis_detected"]
        user_turns = [e for e in all_events if e.to_dict().get("type") == "user_turn"]
        
        # Emotion distribution
        emotions = {}
        for e in all_events:
            d = e.to_dict()
            if d.get("type") == "emotion_detected":
                em = d.get("emotion", "unknown")
                emotions[em] = emotions.get(em, 0) + 1
        
        # Platform breakdown from user data
        platforms = {}
        for u in users:
            ud = u.to_dict()
            p = ud.get("platform", "unknown")
            platforms[p] = platforms.get(p, 0) + 1
        
        return {
            "total_users": len(users),
            "total_sessions": total_sessions,
            "total_turns": len(user_turns),
            "crisis_count": len(crisis_events),
            "emotion_distribution": emotions,
            "platform_breakdown": platforms,
            "events_last_24h": sum(1 for e in all_events if e.to_dict().get("timestamp") and e.to_dict()["timestamp"].replace(tzinfo=dt.timezone.utc) > day_ago),
        }
    except Exception as e:
        return {"error": str(e)}


@router.get("/api/users")
async def api_users():
    """All registered users."""
    if not fs_db:
        return {"error": "Firestore not available"}
    try:
        users = []
        for doc in fs_db.collection("users").stream():
            d = doc.to_dict()
            d["uid"] = doc.id
            # Count sessions
            sessions = list(fs_db.collection("users").document(doc.id).collection("sessions").stream())
            d["session_count"] = len(sessions)
            users.append(d)
        return {"users": users}
    except Exception as e:
        return {"error": str(e)}




@router.get("/api/user/{uid}/sessions")
async def api_user_sessions(uid: str):
    """Sessions for a specific user."""
    if not fs_db:
        return {"error": "Firestore not available"}
    try:
        sessions = []
        for doc in fs_db.collection("users").document(uid).collection("sessions").order_by("updatedAt", direction="DESCENDING").limit(50).stream():
            d = doc.to_dict()
            d["id"] = doc.id
            sessions.append(d)
        return {"sessions": sessions}
    except Exception as e:
        return {"error": str(e)}


@router.get("/api/events")
async def api_events(limit: int = 200, event_type: Optional[str] = None):
    """Admin events log (traces)."""
    if not fs_db:
        return {"error": "Firestore not available"}
    try:
        ref = fs_db.collection("admin_events").order_by("timestamp", direction="DESCENDING").limit(limit)
        if event_type:
            ref = fs_db.collection("admin_events").where("type", "==", event_type).order_by("timestamp", direction="DESCENDING").limit(limit)
        events = []
        for doc in ref.stream():
            d = doc.to_dict()
            d["id"] = doc.id
            if "timestamp" in d and d["timestamp"]:
                d["timestamp"] = d["timestamp"].isoformat()
            events.append(d)
        return {"events": events}
    except Exception as e:
        return {"error": str(e)}


@router.get("/api/crisis")
async def api_crisis():
    """Crisis events."""
    if not fs_db:
        return {"error": "Firestore not available"}
    try:
        events = []
        for doc in fs_db.collection("admin_events").where("type", "==", "crisis_detected").order_by("timestamp", direction="DESCENDING").limit(200).stream():
            d = doc.to_dict()
            d["id"] = doc.id
            if "timestamp" in d and d["timestamp"]:
                d["timestamp"] = d["timestamp"].isoformat()
            events.append(d)
        return {"events": events}
    except Exception as e:
        return {"error": str(e)}


@router.get("/api/emotions")
async def api_emotions():
    """Emotion analytics."""
    if not fs_db:
        return {"error": "Firestore not available"}
    try:
        emotions = {}
        timeline = []
        for doc in fs_db.collection("admin_events").where("type", "==", "emotion_detected").order_by("timestamp", direction="DESCENDING").limit(1000).stream():
            d = doc.to_dict()
            em = d.get("emotion", "unknown")
            emotions[em] = emotions.get(em, 0) + 1
            if d.get("timestamp"):
                timeline.append({"emotion": em, "timestamp": d["timestamp"].isoformat(), "confidence": d.get("confidence", 0)})
        return {"distribution": emotions, "timeline": timeline}
    except Exception as e:
        return {"error": str(e)}


@router.get("/api/study")
async def api_study():
    """Study/SUS data."""
    if not fs_db:
        return {"error": "Firestore not available"}
    try:
        studies = []
        for doc in fs_db.collection("study_sessions").order_by("submitted_at", direction="DESCENDING").stream():
            d = doc.to_dict()
            d["id"] = doc.id
            if "submitted_at" in d and d["submitted_at"]:
                d["submitted_at"] = d["submitted_at"].isoformat()
            studies.append(d)
        
        sus_scores = [s.get("sus_score", 0) for s in studies if s.get("sus_score")]
        return {
            "sessions": studies,
            "count": len(studies),
            "mean_sus": sum(sus_scores) / len(sus_scores) if sus_scores else 0,
        }
    except Exception as e:
        return {"error": str(e)}


@router.get("/api/funnel")
async def api_funnel():
    """User journey funnel."""
    if not fs_db:
        return {"error": "Firestore not available"}
    try:
        users = list(fs_db.collection("users").stream())
        total_signups = len(users)
        
        users_with_sessions = 0
        users_with_multiple = 0
        for u in users:
            sessions = list(fs_db.collection("users").document(u.id).collection("sessions").limit(5).stream())
            if len(sessions) > 0:
                users_with_sessions += 1
            if len(sessions) > 1:
                users_with_multiple += 1
        
        return {
            "signed_up": total_signups,
            "first_session": users_with_sessions,
            "return_session": users_with_multiple,
        }
    except Exception as e:
        return {"error": str(e)}


@router.get("/api/sessions")
async def api_all_sessions():
    """All sessions across all users with duration data."""
    if not fs_db:
        return {"error": "Firestore not available"}
    try:
        sessions = []
        for u in fs_db.collection("users").stream():
            ud = u.to_dict()
            user_name = ud.get("displayName") or ud.get("name", "Unknown")
            for s in fs_db.collection("users").document(u.id).collection("sessions").order_by("updatedAt", direction="DESCENDING").limit(20).stream():
                sd = s.to_dict()
                sd["session_id"] = s.id
                sd["user_id"] = u.id
                sd["user_name"] = user_name
                sessions.append(sd)
        sessions.sort(key=lambda x: x.get("updatedAt", dt.datetime.min) if x.get("updatedAt") else dt.datetime.min, reverse=True)
        return {"sessions": sessions[:200]}
    except Exception as e:
        return {"error": str(e)}


@router.get("/api/engagement")
async def api_engagement():
    """Engagement metrics: session durations, event counts by hour, tab usage."""
    if not fs_db:
        return {"error": "Firestore not available"}
    try:
        events = list(fs_db.collection("admin_events").order_by("timestamp", direction="DESCENDING").limit(5000).stream())
        
        session_durations = []
        hourly_activity = [0] * 24
        tab_usage = {}
        mic_presses = 0
        platforms = {}
        daily_active = {}
        
        for e in events:
            d = e.to_dict()
            ts = d.get("timestamp")
            etype = d.get("type", "")
            
            if ts:
                try:
                    hour = ts.hour
                    hourly_activity[hour] += 1
                    day_key = ts.strftime("%Y-%m-%d")
                    if etype == "session_started":
                        uid = d.get("user_id", "")
                        if uid:
                            daily_active.setdefault(day_key, set()).add(uid)
                except Exception:
                    pass
            
            if etype == "session_ended":
                dur = d.get("duration_seconds", 0)
                if dur > 0:
                    session_durations.append(dur)
            elif etype == "tab_switch":
                tab = d.get("tab", "unknown")
                tab_usage[tab] = tab_usage.get(tab, 0) + 1
            elif etype == "mic_press":
                mic_presses += 1
            
            plat = d.get("platform", "")
            if plat:
                platforms[plat] = platforms.get(plat, 0) + 1
        
        avg_duration = round(sum(session_durations) / len(session_durations), 1) if session_durations else 0
        dau_by_day = {k: len(v) for k, v in daily_active.items()}
        
        return {
            "avg_session_duration_sec": avg_duration,
            "total_mic_presses": mic_presses,
            "tab_usage": tab_usage,
            "hourly_activity": hourly_activity,
            "session_duration_histogram": session_durations[:100],
            "dau_by_day": dau_by_day,
            "platform_events": platforms,
        }
    except Exception as e:
        return {"error": str(e)}


@router.get("/api/heatmap")
async def api_heatmap():
    """Emotion heatmap: emotions by day of week and hour."""
    if not fs_db:
        return {"error": "Firestore not available"}
    try:
        events = list(fs_db.collection("admin_events").where("type", "==", "emotion_detected").order_by("timestamp", direction="DESCENDING").limit(2000).stream())
        
        heatmap = {}
        for e in events:
            d = e.to_dict()
            ts = d.get("timestamp")
            emotion = d.get("emotion", "unknown")
            if ts:
                try:
                    day_name = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][ts.weekday()]
                    hour = ts.hour
                    key = f"{day_name}_{hour}"
                    heatmap[key] = heatmap.get(key, 0) + 1
                except Exception:
                    pass
        
        return {"heatmap": heatmap}
    except Exception as e:
        return {"error": str(e)}


# ── Dashboard HTML ──

@router.get("", response_class=HTMLResponse)
@router.get("/", response_class=HTMLResponse)
async def admin_dashboard():
    """Serve the admin dashboard HTML."""
    return DASHBOARD_HTML


DASHBOARD_HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>VoiceMind Admin</title>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
<style>
body{font-family:'Inter',system-ui,sans-serif;background:#FAF8F5}
.tab-btn{transition:all .2s}.tab-btn.active{background:#D97757;color:#fff}
.card{background:#fff;border-radius:12px;border:1px solid rgba(0,0,0,.06);box-shadow:0 4px 16px rgba(0,0,0,.04);padding:20px}
.kpi{text-align:center}.kpi h3{font-size:2rem;font-weight:800;color:#191918}.kpi p{font-size:.8rem;color:#9CA3AF;margin-top:4px}
table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:8px 12px;border-bottom:1px solid #f0f0eb}th{font-size:.75rem;color:#9CA3AF;text-transform:uppercase;letter-spacing:.05em}
.badge{display:inline-block;padding:2px 8px;border-radius:6px;font-size:.75rem;font-weight:600}
.badge-high{background:#FEE2E2;color:#991B1B}.badge-medium{background:#FEF3C7;color:#92400E}.badge-low{background:#ECFDF5;color:#065F46}
.loader{display:inline-block;width:20px;height:20px;border:3px solid #e5e5e0;border-top-color:#D97757;border-radius:50%;animation:spin .6s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
</style>
</head>
<body>

<div id="app">
<header style="background:#fff;border-bottom:1px solid #e5e5e0;padding:12px 24px;display:flex;align-items:center;justify-content:space-between">
<div style="display:flex;align-items:center;gap:12px">
<div style="width:32px;height:32px;background:linear-gradient(135deg,#C9A88B,#D97757);border-radius:8px;display:flex;align-items:center;justify-content:center;color:#fff;font-size:14px">V</div>
<h1 style="font-size:1.1rem;font-weight:700;color:#191918">VoiceMind Admin Dashboard</h1>
</div>
</header>

<nav style="padding:12px 24px;display:flex;gap:8px;flex-wrap:wrap">
<button class="tab-btn active" onclick="switchTab('overview',this)">Overview</button>
<button class="tab-btn" onclick="switchTab('users',this)">Users</button>
<button class="tab-btn" onclick="switchTab('sessions',this)">Sessions</button>
<button class="tab-btn" onclick="switchTab('emotions',this)">Emotions</button>
<button class="tab-btn" onclick="switchTab('crisis',this)">Crisis</button>
<button class="tab-btn" onclick="switchTab('funnel',this)">Funnel</button>
<button class="tab-btn" onclick="switchTab('engagement',this)">Engagement</button>
<button class="tab-btn" onclick="switchTab('heatmap',this)">Heatmap</button>
<button class="tab-btn" onclick="switchTab('study',this)">Study</button>
<button class="tab-btn" onclick="switchTab('traces',this)">Traces</button>
<button class="tab-btn" onclick="switchTab('logs',this)">Logs</button>
</nav>

<main style="padding:0 24px 40px" id="content">
<div class="loader"></div> Loading...
</main>
</div>

<script>
let currentTab = 'overview';
loadTab('overview');

function switchTab(tab,btn){
  currentTab=tab;
  document.querySelectorAll('.tab-btn').forEach(b=>b.classList.remove('active'));
  if(btn)btn.classList.add('active');
  loadTab(tab);
}

async function loadTab(tab){
  const c=document.getElementById('content');
  c.innerHTML='<div class="loader"></div> Loading...';
  try{
    switch(tab){
      case 'overview': await renderOverview(c);break;
      case 'users': await renderUsers(c);break;
      case 'sessions': await renderSessions(c);break;
      case 'emotions': await renderEmotions(c);break;
      case 'crisis': await renderCrisis(c);break;
      case 'funnel': await renderFunnel(c);break;
      case 'engagement': await renderEngagement(c);break;
      case 'heatmap': await renderHeatmap(c);break;
      case 'study': await renderStudy(c);break;
      case 'traces': await renderTraces(c);break;
      case 'logs': await renderLogs(c);break;
    }
  }catch(e){c.innerHTML=`<div class="card"><p style="color:#C94A4A">Error: ${e.message}</p></div>`}
}

async function api(path){const r=await fetch('/admin/api/'+path);return r.json()}

async function renderOverview(c){
  const [d,eng]=await Promise.all([api('overview'),api('engagement')]);
  const avgDur=eng.avg_session_duration_sec||0;
  const avgMin=Math.floor(avgDur/60);const avgSec=Math.round(avgDur%60);
  c.innerHTML=`
  <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:16px;margin-bottom:24px">
    <div class="card kpi"><h3>${d.total_users||0}</h3><p>Total Users</p></div>
    <div class="card kpi"><h3>${d.total_sessions||0}</h3><p>Total Sessions</p></div>
    <div class="card kpi"><h3>${d.total_turns||0}</h3><p>Total Turns</p></div>
    <div class="card kpi"><h3>${d.crisis_count||0}</h3><p>Crisis Events</p></div>
    <div class="card kpi"><h3>${d.events_last_24h||0}</h3><p>Events (24h)</p></div>
    <div class="card kpi"><h3>${avgMin}m ${avgSec}s</h3><p>Avg Session</p></div>
    <div class="card kpi"><h3>${eng.total_mic_presses||0}</h3><p>Mic Presses</p></div>
  </div>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
    <div class="card"><h4 style="font-weight:700;margin-bottom:12px">Emotion Distribution</h4><canvas id="emotionChart"></canvas></div>
    <div class="card"><h4 style="font-weight:700;margin-bottom:12px">Platform Breakdown</h4><canvas id="platformChart"></canvas></div>
  </div>`;
  const emotions=d.emotion_distribution||{};
  if(Object.keys(emotions).length>0){
    new Chart(document.getElementById('emotionChart'),{type:'doughnut',data:{labels:Object.keys(emotions),datasets:[{data:Object.values(emotions),backgroundColor:['#D97757','#C9A88B','#A8B5A0','#E8A87C','#6B6B66','#3D8C40','#C94A4A','#9CA3AF']}]},options:{responsive:true}});
  }
  const platforms=d.platform_breakdown||{};
  if(Object.keys(platforms).length>0){
    new Chart(document.getElementById('platformChart'),{type:'bar',data:{labels:Object.keys(platforms),datasets:[{label:'Users',data:Object.values(platforms),backgroundColor:'#D97757'}]},options:{responsive:true,scales:{y:{beginAtZero:true}}}});
  }
}

async function renderUsers(c){
  const d=await api('users');
  const users=d.users||[];
  let rows=users.map(u=>`<tr>
    <td>${u.displayName||u.name||'—'}</td>
    <td>${u.email||'—'}</td>
    <td>${u.ageGroup||'—'}</td>
    <td>${u.voicePreference||'—'}</td>
    <td>${u.session_count||0}</td>
    <td>${u.lastActiveAt?new Date(u.lastActiveAt._seconds*1000).toLocaleDateString():'—'}</td>
    <td><button onclick="viewUserSessions('${u.uid}')" style="color:#D97757;border:none;background:none;cursor:pointer;text-decoration:underline">View</button></td>
  </tr>`).join('');
  c.innerHTML=`<div class="card"><table><thead><tr><th>Name</th><th>Email</th><th>Age</th><th>Voice</th><th>Sessions</th><th>Last Active</th><th>Details</th></tr></thead><tbody>${rows||'<tr><td colspan="7" style="text-align:center;color:#9CA3AF">No users yet</td></tr>'}</tbody></table></div>`;
}

async function viewUserSessions(uid){
  switchTab('sessions');
  const c=document.getElementById('content');
  const d=await api('user/'+uid+'/sessions');
  const sessions=d.sessions||[];
  let rows=sessions.map(s=>`<tr>
    <td>${s.id}</td>
    <td>${s.turnCount||0}</td>
    <td>${s.crisisDetected?'<span class="badge badge-high">Yes</span>':'No'}</td>
    <td>${s.updatedAt?new Date(s.updatedAt._seconds*1000).toLocaleString():'—'}</td>
  </tr>`).join('');
  c.innerHTML=`<div class="card"><h4 style="font-weight:700;margin-bottom:12px">Sessions for ${uid}</h4><table><thead><tr><th>Session ID</th><th>Turns</th><th>Crisis</th><th>Last Updated</th></tr></thead><tbody>${rows||'<tr><td colspan="4" style="text-align:center;color:#9CA3AF">No sessions</td></tr>'}</tbody></table></div>`;
}


async function renderSessions(c){
  const d=await api('sessions');
  const sessions=d.sessions||[];
  let rows=sessions.map(s=>{
    const started=s.startedAt?new Date(s.startedAt._seconds*1000).toLocaleString():'—';
    const updated=s.updatedAt?new Date(s.updatedAt._seconds*1000).toLocaleString():'—';
    let duration='—';
    if(s.startedAt&&s.updatedAt){
      const durSec=s.updatedAt._seconds-s.startedAt._seconds;
      if(durSec>=0){const m=Math.floor(durSec/60);const sec=durSec%60;duration=m>0?`${m}m ${sec}s`:`${sec}s`;}
    }
    const emotionCount=(s.emotionTimeline||[]).length;
    return `<tr>
      <td style="font-size:.85rem">${s.user_name||'—'}</td>
      <td style="font-size:.85rem;font-family:monospace">${(s.session_id||'').substring(0,20)}</td>
      <td>${s.turnCount||0}</td>
      <td>${emotionCount}</td>
      <td><span class="badge ${duration==='—'?'':'badge-low'}">${duration}</span></td>
      <td>${s.crisisDetected?'<span class="badge badge-high">Yes</span>':'No'}</td>
      <td style="font-size:.85rem">${started}</td>
      <td style="font-size:.85rem">${updated}</td>
    </tr>`;
  }).join('');
  c.innerHTML=`<div class="card"><h4 style="font-weight:700;margin-bottom:12px">All Sessions (${sessions.length})</h4><table><thead><tr><th>User</th><th>Session</th><th>Turns</th><th>Emotions</th><th>Duration</th><th>Crisis</th><th>Started</th><th>Updated</th></tr></thead><tbody>${rows||'<tr><td colspan="8" style="text-align:center;color:#9CA3AF">No sessions yet</td></tr>'}</tbody></table></div>`;
}

async function renderEmotions(c){
  const d=await api('emotions');
  const dist=d.distribution||{};
  c.innerHTML=`<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
    <div class="card"><h4 style="font-weight:700;margin-bottom:12px">Distribution</h4><canvas id="emDistChart"></canvas></div>
    <div class="card"><h4 style="font-weight:700;margin-bottom:12px">Timeline (last 1000)</h4><canvas id="emTimeChart"></canvas></div>
  </div>`;
  if(Object.keys(dist).length>0){
    new Chart(document.getElementById('emDistChart'),{type:'bar',data:{labels:Object.keys(dist),datasets:[{label:'Count',data:Object.values(dist),backgroundColor:'#C9A88B'}]},options:{responsive:true}});
  }
  const timeline=d.timeline||[];
  if(timeline.length>0){
    const grouped={};
    timeline.forEach(t=>{const day=t.timestamp?.substring(0,10);if(day){grouped[day]=(grouped[day]||0)+1}});
    new Chart(document.getElementById('emTimeChart'),{type:'line',data:{labels:Object.keys(grouped),datasets:[{label:'Emotions/day',data:Object.values(grouped),borderColor:'#D97757',fill:false}]},options:{responsive:true}});
  }
}

async function renderCrisis(c){
  const d=await api('crisis');
  const events=d.events||[];
  let rows=events.map(e=>`<tr>
    <td><span class="badge ${e.tier==='high_severity'?'badge-high':e.tier==='medium_severity'?'badge-medium':'badge-low'}">${e.tier||'—'}</span></td>
    <td>${e.phrase||e.matched_phrase||'—'}</td>
    <td style="max-width:300px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${e.transcript||'—'}</td>
    <td>${e.room||'—'}</td>
    <td>${e.timestamp?new Date(e.timestamp).toLocaleString():'—'}</td>
  </tr>`).join('');
  c.innerHTML=`<div class="card"><h4 style="font-weight:700;margin-bottom:12px">Crisis Events (${events.length})</h4><table><thead><tr><th>Tier</th><th>Trigger</th><th>Transcript</th><th>Room/Session</th><th>Time</th></tr></thead><tbody>${rows||'<tr><td colspan="5" style="text-align:center;color:#9CA3AF">No crisis events</td></tr>'}</tbody></table></div>`;
}

async function renderFunnel(c){
  const d=await api('funnel');
  const steps=[
    {label:'Signed Up',value:d.signed_up||0},
    {label:'First Session',value:d.first_session||0},
    {label:'Return Session',value:d.return_session||0},
  ];
  let bars=steps.map((s,i)=>{
    const pct=steps[0].value>0?Math.round(s.value/steps[0].value*100):0;
    return `<div style="margin-bottom:16px">
      <div style="display:flex;justify-content:space-between;margin-bottom:4px"><span style="font-weight:600">${s.label}</span><span style="color:#6B6B66">${s.value} (${pct}%)</span></div>
      <div style="background:#f0f0eb;border-radius:8px;height:32px;overflow:hidden"><div style="background:linear-gradient(90deg,#C9A88B,#D97757);height:100%;width:${pct}%;border-radius:8px;transition:width .5s"></div></div>
    </div>`;
  }).join('');
  c.innerHTML=`<div class="card"><h4 style="font-weight:700;margin-bottom:16px">User Journey Funnel</h4>${bars}</div>`;
}

async function renderEngagement(c){
  const d=await api('engagement');
  const avgDur=d.avg_session_duration_sec||0;
  const avgMin=Math.floor(avgDur/60);
  const avgSec=Math.round(avgDur%60);
  const tabs=d.tab_usage||{};
  const hourly=d.hourly_activity||Array(24).fill(0);
  const dau=d.dau_by_day||{};
  c.innerHTML=`
  <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:16px;margin-bottom:24px">
    <div class="card kpi"><h3>${avgMin}m ${avgSec}s</h3><p>Avg Session Duration</p></div>
    <div class="card kpi"><h3>${d.total_mic_presses||0}</h3><p>Mic Presses</p></div>
    <div class="card kpi"><h3>${Object.values(tabs).reduce((a,b)=>a+b,0)}</h3><p>Tab Switches</p></div>
  </div>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:16px">
    <div class="card"><h4 style="font-weight:700;margin-bottom:12px">Hourly Activity</h4><canvas id="hourlyChart"></canvas></div>
    <div class="card"><h4 style="font-weight:700;margin-bottom:12px">Daily Active Users</h4><canvas id="dauChart"></canvas></div>
  </div>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
    <div class="card"><h4 style="font-weight:700;margin-bottom:12px">Tab Usage</h4><canvas id="tabChart"></canvas></div>
    <div class="card"><h4 style="font-weight:700;margin-bottom:12px">Session Duration Distribution</h4><canvas id="durChart"></canvas></div>
  </div>`;
  new Chart(document.getElementById('hourlyChart'),{type:'bar',data:{labels:Array.from({length:24},(_,i)=>i+'h'),datasets:[{label:'Events',data:hourly,backgroundColor:'#C9A88B'}]},options:{responsive:true,scales:{y:{beginAtZero:true}}}});
  if(Object.keys(dau).length>0){
    const days=Object.keys(dau).sort();
    new Chart(document.getElementById('dauChart'),{type:'line',data:{labels:days,datasets:[{label:'DAU',data:days.map(d2=>dau[d2]),borderColor:'#D97757',fill:true,backgroundColor:'rgba(217,119,87,0.1)'}]},options:{responsive:true}});
  }
  if(Object.keys(tabs).length>0){
    new Chart(document.getElementById('tabChart'),{type:'doughnut',data:{labels:Object.keys(tabs),datasets:[{data:Object.values(tabs),backgroundColor:['#D97757','#C9A88B','#A8B5A0','#E8A87C','#6B6B66']}]},options:{responsive:true}});
  }
  const durations=d.session_duration_histogram||[];
  if(durations.length>0){
    const buckets={'0-30s':0,'30-60s':0,'1-2m':0,'2-5m':0,'5-10m':0,'10m+':0};
    durations.forEach(s=>{if(s<30)buckets['0-30s']++;else if(s<60)buckets['30-60s']++;else if(s<120)buckets['1-2m']++;else if(s<300)buckets['2-5m']++;else if(s<600)buckets['5-10m']++;else buckets['10m+']++});
    new Chart(document.getElementById('durChart'),{type:'bar',data:{labels:Object.keys(buckets),datasets:[{label:'Sessions',data:Object.values(buckets),backgroundColor:'#A8B5A0'}]},options:{responsive:true,scales:{y:{beginAtZero:true}}}});
  }
}

async function renderHeatmap(c){
  const d=await api('heatmap');
  const heatmap=d.heatmap||{};
  const days=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  const maxVal=Math.max(1,...Object.values(heatmap));
  let grid='';
  grid+='<div style="display:grid;grid-template-columns:60px repeat(24,1fr);gap:2px;font-size:.7rem">';
  grid+='<div></div>';
  for(let h=0;h<24;h++) grid+=`<div style="text-align:center;color:#9CA3AF">${h}</div>`;
  days.forEach(day=>{
    grid+=`<div style="display:flex;align-items:center;font-weight:600;color:#6B6B66">${day}</div>`;
    for(let h=0;h<24;h++){
      const key=day+'_'+h;
      const val=heatmap[key]||0;
      const intensity=val/maxVal;
      const r=Math.round(217-(217-168)*intensity);
      const g=Math.round(119-(119-181)*intensity);
      const b=Math.round(87-(87-160)*intensity);
      grid+=`<div style="aspect-ratio:1;background:rgba(${r},${g},${b},${Math.max(0.1,intensity)});border-radius:3px;display:flex;align-items:center;justify-content:center;font-size:.6rem;color:${intensity>0.5?'#fff':'#9CA3AF'}" title="${day} ${h}:00 — ${val} emotions">${val||''}</div>`;
    }
  });
  grid+='</div>';
  c.innerHTML=`<div class="card"><h4 style="font-weight:700;margin-bottom:16px">Emotion Detection Heatmap (Day × Hour)</h4><p style="color:#9CA3AF;font-size:.85rem;margin-bottom:16px">Color intensity shows when emotions are most detected. Darker = more activity.</p>${grid}<div style="display:flex;align-items:center;gap:8px;margin-top:12px"><span style="font-size:.75rem;color:#9CA3AF">Low</span><div style="display:flex;gap:2px">${[0.1,0.3,0.5,0.7,0.9].map(i=>`<div style="width:24px;height:12px;background:rgba(168,181,160,${i});border-radius:2px"></div>`).join('')}</div><span style="font-size:.75rem;color:#9CA3AF">High</span></div><div style="margin-top:16px;padding-top:12px;border-top:1px solid #f0f0eb"><p style="font-size:.8rem;font-weight:600;color:#6B6B66;margin-bottom:8px">Emotion Legend</p><div style="display:flex;flex-wrap:wrap;gap:8px">${['anxious','sad','stressed','angry','lonely','happy','calm','neutral'].map(e=>{const colors={anxious:'#F59E0B',sad:'#3B82F6',stressed:'#EF4444',angry:'#DC2626',lonely:'#8B5CF6',happy:'#10B981',calm:'#A8B5A0',neutral:'#9CA3AF'};return `<span class="badge" style="background:${colors[e]}20;color:${colors[e]}">${e}</span>`;}).join('')}</div></div></div>`;
}

async function renderStudy(c){
  const d=await api('study');
  const sessions=d.sessions||[];
  c.innerHTML=`<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:16px">
    <div class="card kpi"><h3>${d.count||0}</h3><p>Study Sessions</p></div>
    <div class="card kpi"><h3>${d.mean_sus?d.mean_sus.toFixed(1):'—'}</h3><p>Mean SUS Score</p></div>
  </div>
  <div class="card"><table><thead><tr><th>Participant</th><th>SUS</th><th>Satisfaction</th><th>What Worked</th></tr></thead><tbody>${sessions.map(s=>`<tr><td>${s.participant_id||'—'}</td><td>${s.sus_score||'—'}</td><td>${s.satisfaction_rating||'—'}/5</td><td style="max-width:200px;overflow:hidden;text-overflow:ellipsis">${s.what_worked||'—'}</td></tr>`).join('')||'<tr><td colspan="4" style="text-align:center;color:#9CA3AF">No study data</td></tr>'}</tbody></table></div>`;
}

async function renderTraces(c){
  const d=await api('events?limit=500');
  const events=d.events||[];
  const types={};
  events.forEach(e=>{types[e.type]=(types[e.type]||0)+1});
  let filters=Object.entries(types).map(([t,n])=>`<button onclick="filterTraces('${t}')" class="tab-btn" style="font-size:.75rem;padding:4px 10px">${t} (${n})</button>`).join(' ');
  let rows=events.slice(0,200).map(e=>`<tr>
    <td><span class="badge" style="background:#f0f0eb;color:#525252">${e.type}</span></td>
    <td style="max-width:400px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:.85rem">${JSON.stringify(e).substring(0,120)}...</td>
    <td style="font-size:.85rem">${e.timestamp?new Date(e.timestamp).toLocaleString():'—'}</td>
  </tr>`).join('');
  c.innerHTML=`<div class="card" style="margin-bottom:12px"><div style="display:flex;gap:6px;flex-wrap:wrap">${filters}</div></div><div class="card"><table><thead><tr><th>Type</th><th>Data</th><th>Time</th></tr></thead><tbody>${rows}</tbody></table></div>`;
}

async function filterTraces(type){
  const c=document.getElementById('content');
  c.innerHTML='<div class="loader"></div>';
  const d=await api('events?limit=500&event_type='+type);
  const events=d.events||[];
  let rows=events.map(e=>`<tr>
    <td><span class="badge" style="background:#f0f0eb;color:#525252">${e.type}</span></td>
    <td style="max-width:400px;overflow:hidden;font-size:.85rem"><pre style="margin:0;white-space:pre-wrap">${JSON.stringify(e,null,1).substring(0,300)}</pre></td>
    <td style="font-size:.85rem">${e.timestamp?new Date(e.timestamp).toLocaleString():'—'}</td>
  </tr>`).join('');
  c.innerHTML=`<div class="card"><h4 style="font-weight:700;margin-bottom:12px">Filtered: ${type} (${events.length})</h4><button onclick="loadTab('traces')" style="color:#D97757;border:none;background:none;cursor:pointer;margin-bottom:12px">&larr; Back to all traces</button><table><thead><tr><th>Type</th><th>Data</th><th>Time</th></tr></thead><tbody>${rows}</tbody></table></div>`;
}

async function renderLogs(c){
  const d=await api('events?limit=100');
  const events=d.events||[];
  let rows=events.map(e=>{
    const isError=e.type==='error'||e.type?.includes('error');
    const isWarn=e.type==='warning'||e.type?.includes('crisis');
    const color=isError?'#C94A4A':isWarn?'#92400E':'#191918';
    return `<tr style="color:${color}">
      <td style="font-size:.8rem;white-space:nowrap">${e.timestamp?new Date(e.timestamp).toLocaleTimeString():'—'}</td>
      <td><span class="badge ${isError?'badge-high':isWarn?'badge-medium':'badge-low'}">${e.type}</span></td>
      <td style="font-size:.85rem">${JSON.stringify(e).substring(0,150)}</td>
    </tr>`;
  }).join('');
  c.innerHTML=`<div class="card"><div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px"><h4 style="font-weight:700">Live Logs (last 100)</h4><button onclick="loadTab('logs')" style="background:#D97757;color:#fff;border:none;border-radius:8px;padding:6px 14px;cursor:pointer">Refresh</button></div><table><thead><tr><th>Time</th><th>Type</th><th>Details</th></tr></thead><tbody>${rows||'<tr><td colspan="3" style="text-align:center;color:#9CA3AF">No logs yet</td></tr>'}</tbody></table></div>`;
}
</script>
</body>
</html>"""
