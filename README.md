# 📵 ScamShield – Real-Time Spam Call Blocker

## 🧠 Problem

Mobile phone users are constantly bombarded by robocalls, spam calls, and scam attempts. These calls not only **disrupt user focus** but can also lead to **financial fraud**, **phishing**, and **missed legitimate communication**. 

Current call-blocking apps typically:
- Require **manual intervention**
- Depend on **outdated blacklists**
- Do not act **in real-time**
- Fail to **silently reject** harmful calls

---

## ✅ Solution

**ScamShield** is a native mobile solution built with **Flutter** and a **Node.js** backend that offers:

- 🔍 **Real-time spam detection** using the [Hiya Protect API](https://developer.hiya.com/docs/protect/voice-scam-protection/detectscamcall)
- 🔕 **Autonomous call termination or silencing** without user interaction
- ⚡ **Fast and seamless protection**, ensuring spam is handled before it rings
- 📈 **Extensible backend** to support caching, user preferences, and analytics

---

## 💰 Subscription

ScamShield is offered as a **subscription-based service** at just **$2/month**, giving you uninterrupted protection and peace of mind from scammers and robocalls.

---

## 🔁 User Flow (UX Flow)

This represents how the user interacts with the app from installation to protection.

### 👤 User Flow: ScamShield

```plaintext
1. User installs the ScamShield app
    ↓
2. User signs up and subscribes ($2/month)
    ↓
3. App requests necessary permissions:
   - Call access
   - Notification access (optional)
   - Background service (Android)
    ↓
4. ScamShield is now running in the background
    ↓
5. Incoming call is detected
    ↓
6. App checks with backend → Is this number a scam?
    ↓
7. Backend queries Hiya API and sends decision: Block / Allow
    ↓
8a. If Block → App terminates/silences call (automated)
8b. If Allow → Call rings as normal
    ↓
9. User can view recent blocked calls (optional feature)
```

---

## 🧠 Data Flow (Technical Flow)

This shows how data moves through the system — from incoming calls to API responses.

### 🧬 Data Flow: ScamShield Architecture

```plaintext
[Incoming Call Triggered on Device]
        ↓
[Flutter App detects call using native module]
        ↓
[POST Request sent to Node.js API with phoneNumber]
        ↓
[Node.js Backend receives request]
        ↓
[Backend sends request to Hiya Protect API: /detect]
        ↓
[Hiya responds: scam status, score, category]
        ↓
[Backend processes response and returns JSON:
   { action: "block" | "allow" }]
        ↓
[Flutter app receives response]
        ↓
IF "block":
  → Native call control blocks/ends/silences call
ELSE:
  → Call rings normally
```

### 🔄 Real-Time Voice Analysis Flow (Advanced)

```plaintext
[Incoming Call Detected]
        ↓
[Flutter App starts WebSocket connection to backend]
        ↓
[Backend establishes WebSocket connection to Hiya API]
        ↓
[Audio stream flows: Device → Flutter → Backend → Hiya]
        ↓
[Real-time analysis results flow back: Hiya → Backend → Flutter]
        ↓
[If SCAM detected during conversation:]
  → Display warning overlay to user
  → Offer "Hang Up" and "Report" options
  → Log transcript and results for review
```

---

## 🛠️ Tech Stack

| Layer        | Technology              |
|--------------|-------------------------|
| Frontend     | Flutter (Android + iOS)  |
| Backend      | Node.js + Express.js     |
| Call Blocking| Native Android/iOS plugins |
| Spam Lookup  | [Hiya Protect API](https://developer.hiya.com/docs/protect/voice-scam-protection/detectscamcall) |
| Real-time Analysis | WebSocket + Hiya Voice Scam Protection |
| Storage (optional) | MongoDB or PostgreSQL |

---

## 💾 Database & Caching System

ScamShield implements a high-performance local database cache to store known scam/spam numbers, reducing API calls and improving response times.

### 🏗️ Database Architecture

```plaintext
[Incoming Call] → [Check Local DB Cache] → [Found?]
                                              |
                                         [YES] → [Return Cached Result]
                                              |
                                         [NO]  → [Query Hiya API] → [Cache Result] → [Return Result]
```

### 📊 Database Schema

#### **Scam Numbers Collection** (`scam_numbers.json`)

```json
{
  "phoneNumber": "+1234567890",
  "originalNumber": "+1 (234) 567-8900",
  "riskLevel": "HIGH|MEDIUM|LOW",
  "confidence": "HIGH|MEDIUM|LOW|UNKNOWN",
  "category": "scam|suspicious|legitimate",
  "source": "hiya_api|user_report|manual",
  "autoReject": true,
  "scamData": {
    "callScamRisk": "HIGH_SCAM_RISK",
    "callOriginatorRisk": "HIGH",
    "scamDialog": {
      "scamDialogRisk": "SCAM",
      "confidence": "HIGH"
    },
    "syntheticVoice": {
      "syntheticVoiceDetected": "YES",
      "score": 0.85
    }
  },
  "firstSeen": "2025-07-25T09:30:00.000Z",
  "lastSeen": "2025-07-25T11:30:00.000Z",
  "hitCount": 5,
  "userReports": [
    {
      "reportType": "scam",
      "userPhone": "+27000000000",
      "timestamp": "2025-07-25T10:00:00.000Z"
    }
  ]
}
```

#### **User Reports Collection** (`user_reports.json`)

```json
{
  "phoneNumber": "+1234567890",
  "originalNumber": "+1 (234) 567-8900",
  "reportType": "scam|not_scam|spam",
  "userPhone": "+27000000000",
  "timestamp": "2025-07-25T10:00:00.000Z",
  "additionalData": {
    "reason": "Fake bank call asking for PIN",
    "callDuration": 45,
    "userAction": "hung_up"
  }
}
```

#### **Database Statistics** (`db_statistics.json`)

```json
{
  "totalScamNumbers": 1250,
  "totalUserReports": 340,
  "riskLevels": {
    "HIGH": 450,
    "MEDIUM": 600,
    "LOW": 200
  },
  "sources": {
    "hiya_api": 900,
    "user_report": 300,
    "manual": 50
  },
  "autoRejectNumbers": 450,
  "totalHits": 5670,
  "lastUpdated": "2025-07-25T11:30:00.000Z"
}
```

### 🔄 Database Workflow

1. **Call Detection** → Phone number extracted
2. **Cache Check** → Query local database first
3. **Cache Hit** → Return cached result (⚡ **~1ms response**)
4. **Cache Miss** → Query Hiya API (⏱️ **~200ms response**)
5. **Cache Update** → Store API result for future use
6. **User Reports** → Update risk assessment based on community feedback

### 📡 Database API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/db/stats` | GET | Get database statistics and metrics |
| `/db/check/:phoneNumber` | GET | Check if specific number is in database |
| `/db/report` | POST | Add user report for a phone number |
| `/db/cleanup` | POST | Clean up old database entries (admin) |

### 🚀 Performance Benefits

- ✅ **99% faster** responses for known numbers (cache hits)
- ✅ **Reduced API costs** by avoiding duplicate Hiya API calls
- ✅ **Offline capability** for known scam numbers
- ✅ **Community-driven** accuracy through user reports
- ✅ **Automatic cleanup** of old, unused entries

### 🔧 Database Management

```bash
# Get database statistics
curl http://localhost:3000/db/stats | jq

# Check if number is in database
curl http://localhost:3000/db/check/+1666999666 | jq

# Add user report
curl -X POST http://localhost:3000/db/report \
  -H "Content-Type: application/json" \
  -d '{
    "phoneNumber": "+1234567890",
    "reportType": "scam",
    "userPhone": "+27000000000",
    "additionalData": {
      "reason": "Fake bank call"
    }
  }' | jq

# Cleanup old entries (admin)
curl -X POST http://localhost:3000/db/cleanup \
  -H "Content-Type: application/json" \
  -d '{"daysOld": 90}' | jq
```

### 🛡️ Data Privacy & Security

- **Local Storage**: All data stored locally on your server
- **No Cloud Sync**: Numbers never leave your infrastructure
- **Automatic Cleanup**: Old entries automatically removed
- **User Consent**: User reports only with explicit consent
- **Anonymized**: No personal data stored, only phone numbers and risk levels

---

## 🧪 Testing & Verification

ScamShield includes comprehensive flow testing to verify both user experience and data flow integrity.

### Available Test Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/test/comprehensive` | GET | Run all flow tests with different phone number scenarios |
| `/test/user-flow` | POST | Test complete user flow for a specific phone number |
| `/test/data-flow` | GET | Test data flow through the system |
| `/stats` | GET | View system statistics and session data |

### Test Phone Number Scenarios

- **Normal numbers** (e.g., `+1234567890`) → Should be allowed
- **Suspicious numbers** (containing `555`) → Generate privacy warnings
- **Scam numbers** (containing `666` or `999`) → Should be blocked with scam warnings
- **International numbers** (e.g., `+27123456789`) → Handled appropriately

### Running Tests

```bash
# Test all flows comprehensively
curl http://localhost:3000/test/comprehensive | jq

# Test specific phone number
curl -X POST http://localhost:3000/test/user-flow \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "+1666999666"}' | jq

# Test data flow
curl http://localhost:3000/test/data-flow | jq

# View statistics
curl http://localhost:3000/stats | jq
```

### Expected Test Results

✅ **All tests should pass** with the following outcomes:
- **Session creation** and management working correctly
- **Scam detection** logic functioning properly
- **Warning generation** for appropriate risk levels
- **Statistics tracking** accurately
- **Call actions** (block/allow) determined correctly

---

## 🧬 System Architecture

```plaintext
[Flutter App]
   |
   |-- Incoming Call Detected (via platform channel)
   |
   |--> [Node.js API] -----> [Hiya Protect DetectScamCall API]
   |                               |
   |<------ Decision (Block / Allow) ←
   |
   |-- Block / Allow Call (native)
```

---

## 🧩 Key Features

- 📲 Intercept incoming calls via native Flutter plugins
- 🛡️ Query Hiya’s real-time `DetectScamCall` API
- ❌ Automatically block or silence calls marked as spam
- ⚙️ Modular backend architecture for future features
- 🔐 Secure communication using HTTPS & API key management

---

## 🔗 External API Integration

We use the [Hiya Protect – DetectScamCall API](https://developer.hiya.com/docs/protect/voice-scam-protection/detectscamcall) to check in real-time whether a phone number is flagged as spam or a scam.

### Sample Request to Hiya API:
```http
POST /v1/scam-call-detection/detect
Authorization: Bearer <API_TOKEN>
Content-Type: application/json

{
  "phone_number": "+1234567890",
  "country_code": "US"
}
```

### Sample Response:
```json
{
  "scam": true,
  "score": 95,
  "category": "robocall",
  "description": "Likely Scam or Fraud"
}
```

---

## 📱 Flutter Setup

Install dependencies:
```bash
flutter pub get
```

Plugins:
- `flutter_callkit_incoming` or `telephony`
- `http` for network requests
- Platform channels to execute native call handling (block/silence)

Intercepting calls:
```dart
onIncomingCall(String phoneNumber) async {
  final response = await http.post(
    Uri.parse("https://your-node-backend.com/check-call"),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({"phoneNumber": phoneNumber})
  );

  final result = jsonDecode(response.body);
  if (result['action'] == 'block') {
    CallManager.blockCall(); // Platform-specific native function
  }
}
```

---

## 🌐 Node.js Backend Setup

Install dependencies:
```bash
npm install
```

`.env`:
```env
HIYA_API_KEY=your_hiya_api_key
HIYA_BASE_URL=https://api.hiya.com/v1/scam-call-detection/detect
PORT=3000
```

Backend Logic (`index.js`):
```js
const express = require('express');
const axios = require('axios');
require('dotenv').config();

const app = express();
app.use(express.json());

app.post('/check-call', async (req, res) => {
  const { phoneNumber } = req.body;

  try {
    const hiyaRes = await axios.post(
      process.env.HIYA_BASE_URL,
      {
        phone_number: phoneNumber,
        country_code: "ZA" // or dynamically detect
      },
      {
        headers: {
          Authorization: `Bearer ${process.env.HIYA_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const isSpam = hiyaRes.data.scam === true || hiyaRes.data.score > 80;
    res.json({ action: isSpam ? "block" : "allow" });

  } catch (err) {
    console.error("Hiya API error", err.message);
    res.status(500).json({ error: "Lookup failed" });
  }
});

app.listen(process.env.PORT || 3000, () => {
  console.log(`API running on port ${process.env.PORT}`);
});
```

---

## 🛡️ Security

- ✅ Use HTTPS between app and backend
- ✅ Secure your Hiya API key using `.env` and server-side storage
- ✅ Rate-limit calls to `/check-call`
- ✅ Log blocked numbers for analytics (optional)

---

## 📌 Future Improvements

- User-configurable blocking categories (scam, telemarketing, political, etc.)
- SMS spam protection
- Crowdsourced number reporting
- Smart caching of frequent spam numbers
- Admin dashboard for monitoring blocked calls

---

## 👨‍💻 Contributors

- **Thabang Phaleng** — Full Stack Engineer, Architect
- **OpenAI + Hiya Docs** — Integration references

---

## 📝 License

MIT License – free to use with attribution.

---

## 📬 Contact

For commercial use or custom integrations:  
📧 theonlysoftwarehub@gmail.com  
🌐 https://developer.hiya.com/