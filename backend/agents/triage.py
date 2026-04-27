from google.adk.agents import LlmAgent
from .therapist import therapist_agent
from .crisis import crisis_agent

# Triage Agent - Assesses severity and routes to therapist or crisis
triage_agent = LlmAgent(
    name="triage",
    model="gemini-2.5-flash",
    instruction="""You are an initial assessment / triage agent for a mental health app.
Your job is to read the user's input/context and decide if it constitutes an immediate emergency (e.g., self-harm, suicide, severe crisis).
If it is a severe crisis, you MUST immediately transfer control to 'crisis_team'.
Otherwise, you MUST immediately transfer control to 'therapist'.
Do not respond to the user directly unless ABSOLUTELY necessary. Just route the conversation.
""",
    sub_agents=[therapist_agent, crisis_agent]
)
