# Security Policy

## Important: VoiceMind is not a medical device

VoiceMind is a research / open-source project. **It is not a substitute for
professional mental health care.** It is not certified, validated, or approved
for clinical use. Anyone in immediate distress should contact a qualified
helpline; a list is hard-coded in
[`lib/src/common/constants.dart`](lib/src/common/constants.dart) and served by
the backend at `GET /helplines`.

If you are in crisis right now:

- **US:** call or text 988 (Suicide & Crisis Lifeline)
- **UK:** call 116 123 (Samaritans)
- **India:** AASRA — +91-9820466726
- Other regions: see [`/helplines`](backend/main.py) endpoint or the in-app
  helpline modal.

## Reporting a security vulnerability

Please **do not open a public GitHub issue** for security problems. Instead:

1. Open a private security advisory via GitHub
   ([repo Security tab → "Report a vulnerability"](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)).
2. Include reproduction steps, affected versions, and any logs you have.

We aim to acknowledge reports within 7 days.

## Things that look like vulnerabilities but are not

- **Crisis-keyword list is in plaintext.** This is intentional. The list lives
  at [`lib/src/common/constants.dart`](lib/src/common/constants.dart) (client)
  and [`backend/utils/safety.py`](backend/utils/safety.py) (server). Both are
  meant to be auditable and contributable. There is no PII in either file.
- **`/admin` dashboard is open by default.** It is meant for local development
  only. If you deploy the backend publicly you **must** put the dashboard
  behind authentication or a VPN/reverse proxy. Setting `ADMIN_EMAIL` in
  `backend/.env` enables Firebase ID-token auth for `/admin/api/*`.

## Secrets and credentials

- `backend/.env` is gitignored. Never commit it.
- `lib/firebase_options.dart` and the platform Firebase config files
  (`google-services.json`, `GoogleService-Info.plist`) are gitignored —
  contributors generate these locally with `flutterfire configure` against
  their own Firebase project.
- The repository has been audited before initial public release; no real
  Gemini, LiveKit, or Firebase Admin secrets exist in any committed file or
  in git history.

## Dependency policy

Run `flutter pub upgrade --major-versions` and `pip install --upgrade -r
backend/requirements.txt` periodically. PRs that bump dependencies to address
CVEs are welcome.
