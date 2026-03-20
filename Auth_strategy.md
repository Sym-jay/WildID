# ZSI Wildlife Identifier - Authentication & SMS Strategy

## Quick Summary

Your app will have **3 authentication & alert features**:

### 1. **Login System** (FREE)
- Email + password login
- Stored securely on device (Keychain/Keystore)
- Remembers login on next app launch
- ✅ Already implemented

### 2. **2FA (2-Factor Authentication)** via SMS (COSTS ₹1.50 per OTP)
- Optional for users who want extra security
- After email login → receive 6-digit OTP via SMS
- Verify OTP to gain access
- Rate limited: 5 failed attempts → 15 min lockout
- Cost: ~₹450-900/month (if 300-600 logins/month)

### 3. **Endangered Species Alerts** via SMS (COSTS ₹1.50 per SMS)
- When user identifies an endangered animal
- Sends SMS to ZSI experts: "🐅 Tiger spotted at location by User"
- Can be toggled on/off by user
- Cost: ~₹150-450/month (if 100-300 endangered species identified/month)

---

## Authentication Data Storage

### Where Data Lives

```
┌─────────────────────────────────┐
│   User's Device (Encrypted)     │
├─────────────────────────────────┤
│ Secure Storage (iOS/Android)    │
│ ├─ Email address (encrypted)    │
│ ├─ Password hash (encrypted)    │
│ ├─ OTP tokens (encrypted)       │
│ └─ Session tokens (encrypted)   │
│                                 │
│ SQLite Database                 │
│ ├─ Sighting records             │
│ ├─ Expert reviews               │
│ ├─ User preferences             │
│ └─ SMS settings                 │
└─────────────────────────────────┘
              ↓
     Next app launch:
     Auto-login from storage
```

### Does Data Persist?

| Data | Persists | Survives Restart | Cloud Backup |
|------|----------|-----------------|--------------|
| Email/Password | ✅ Yes | ✅ Yes | ❌ No* |
| OTP Tokens | ✅ Yes | ✅ Yes | ❌ No |
| Sighting Records | ✅ Yes | ✅ Yes | ⚠️ Optional |
| SMS Preferences | ✅ Yes | ✅ Yes | ⚠️ Optional |

*Only uploaded if user manually submits sightings

---

## SMS Cost Breakdown

### What Costs Money

#### **2FA OTP Login** (If enabled)
```
User logins with SMS 2FA
Cost: ₹1.50 per OTP sent
Frequency: Every login if enabled
Typical: 10-20 logins/month per user
Monthly cost: ₹15-30 per active user
```

#### **Endangered Species Alerts**
```
User identifies endangered animal (Schedule-1)
Cost: ₹1.50 per SMS sent to experts
Frequency: Per identification of endangered species
Typical: 5-10 endangered identifications/day
Monthly cost: ~₹225-450
```

#### **Expert Verification Alerts**
```
Expert verifies user's identification
Cost: ₹1.50 per SMS
Frequency: Per verification
Monthly cost: ~₹90-225
```

### Total Monthly SMS Cost (Estimate)

```
Scenario 1: Small Deployment (100 users, low usage)
├─ 2FA SMS: 50 logins × ₹1.50 = ₹75
├─ Endangered alerts: 50 per month × ₹1.50 = ₹75
└─ Verification alerts: 20 per month × ₹1.50 = ₹30
Total: ~₹180/month

Scenario 2: Medium Deployment (500 users, moderate usage)
├─ 2FA SMS: 500 logins × ₹1.50 = ₹750
├─ Endangered alerts: 200 per month × ₹1.50 = ₹300
└─ Verification alerts: 100 per month × ₹1.50 = ₹150
Total: ~₹1,200/month

Scenario 3: Large Deployment (1000 users, high usage)
├─ 2FA SMS: 1000 logins × ₹1.50 = ₹1,500
├─ Endangered alerts: 500 per month × ₹1.50 = ₹750
└─ Verification alerts: 300 per month × ₹1.50 = ₹450
Total: ~₹2,700/month
```

### How to Reduce SMS Costs

**Option 1: Email-based 2FA (Recommended)**
- Use email OTP instead of SMS for 2FA
- Saves: ₹450-900/month
- Cost: FREE (just SMTP server)
- Trade-off: Users need internet for email

**Option 2: Make 2FA Optional**
- Only users who enable it get SMS
- Default: Email-based 2FA
- Typical savings: 70% reduction

**Option 3: Rate Limit Alerts**
- Only send 1 alert per species per hour
- Prevents spam alerts
- Typical savings: 30-40%

**Option 4: Expert Alerts Only**
- Only send SMS to experts, not users
- Users see in app
- Typical savings: 50-60%

---

## 2FA Implementation

### Flow: How 2FA Works

```
1. User opens app
   ↓
2. Enters email & password
   ↓
3. Server validates credentials
   ↓
4. Server asks: "Verify via SMS or Email?"
   ↓
5. Server sends OTP (6-digit code) to user's phone/email
   ↓
6. User enters OTP in app
   ↓
7. OTP verified ✅
   ↓
8. Access granted, session created
   ↓
9. Next time app opens → auto-login (no OTP needed)
```

### User Experience

**First Login:**
```
Login Screen
├─ Email: user@example.com
├─ Password: ••••••••
└─ [Login]
     ↓
Choose verification method
├─ SMS (faster)
└─ Email (more reliable)
     ↓
OTP Screen
├─ Enter code: [6-digit box]
├─ Time remaining: 4:52 ⏱️
└─ [Verify]
     ↓
✅ Logged in! Home screen
```

**Next Login (Next Day):**
```
Secure Storage has email → Auto-login ✅
Home screen opens directly
No 2FA needed!
```

### Settings: Enable/Disable 2FA

In app settings, users can:
```
Settings
├─ Authentication
│  ├─ 2FA Status: ✅ Enabled
│  ├─ Phone: +91 98765-43210
│  ├─ Method: SMS
│  └─ [Disable 2FA]
│
└─ SMS Preferences
   ├─ Endangered species alerts: ✅ ON
   ├─ Expert verifications: ✅ ON
   ├─ Conservation tips: ⚠️ OFF
   └─ [Manage Preferences]
```

---

## SMS Alert Features

### What Triggers SMS Alerts

#### **Endangered Species Identified**
```
User takes photo → identifies as "Bengal Tiger" (Schedule-1)
System sends SMS to registered experts:
"🐅 Bengal Tiger spotted near Kaziranga NP by User_John123"

SMS Cost: ₹1.50
User sees: In app only
Experts see: SMS notification + app alert
```

#### **Expert Verification Complete**
```
Expert verifies user's identification
System sends SMS to user:
"✅ Your Tiger identification was verified by Expert_Sharma"

SMS Cost: ₹1.50
User sees: In app + SMS notification
```

#### **Conservation Tips** (Optional Weekly)
```
Every Monday: Get conservation tips for nearby endangered species
"Protect Tigers: Use wildlife corridors, avoid poison traps"

SMS Cost: ₹1.50
User sees: In app + SMS
Frequency: Weekly (user can disable)
```

### User Controls SMS Alerts

Users can customize what SMS they receive:

```
Settings → SMS Preferences
├─ Endangered species alerts: ✅ YES / ❌ NO
├─ Verification alerts: ✅ YES / ❌ NO
├─ Conservation tips: ✅ YES / ❌ NO
├─ Summary reports: 
│  ├─ Weekly summary: YES
│  └─ Never (OFF)
└─ Phone number: +91 ________

[Save Preferences]
```

**Note**: If all disabled → 0 SMS cost for that user!

---

## SMS Provider: Government API (sms.gov.in)

### Why Government SMS API?

| Aspect | Government | Twilio | Firebase |
|--------|-----------|--------|----------|
| **Cost** | ₹1.50/SMS | $0.0075-0.02/SMS | $0.01-0.06/SMS |
| **For India** | Perfect (local rates) | Works (international) | Works |
| **Setup** | 2-4 weeks approval* | 5 minutes | 5 minutes |
| **Best For** | ZSI (gov org) | Global apps | Apps using Firebase |

*Requires organization verification with Government of India

### Registration Steps (For ZSI Admin)

```
1. Go to https://sms.gov.in
2. Register as Government Organization
   └─ Provide ZSI ID, official email
3. Wait for approval (2-4 weeks)
4. Get API Key
5. Add API Key to backend
6. Start sending SMS! ✅
```

**Until then**: Use Twilio for testing (costs ~$0.01-0.02/SMS vs ₹1.50)

### SMS Template Examples

```
🐅 Endangered Alert:
"Bengal Tiger spotted near Kaziranga NP (24.59°N, 93.11°E) 
by UserJohn123. View details: app.zsi.org/alert/12345"

✅ Verification Alert:
"Your Tiger identification was verified as CORRECT 
by Expert Sharma. +Expert Note: Rare sighting! Great job!"

📚 Conservation Tip:
"Did you know? Tigers need 50+ sq km territory. 
Protect wildlife corridors for their survival! 🐅"

📊 Weekly Summary:
"This week: 15 sightings, 3 endangered species identified. 
Top species: Elephant (5), Tiger (3), Leopard (2)"
```

---

## Security & Privacy

### How Phone Numbers Are Protected

- ✅ Encrypted in database
- ✅ Sent over HTTPS (not visible on network)
- ✅ Used only for SMS alerts (not shared)
- ✅ Users can change anytime
- ✅ Users can opt-out of SMS

### OTP Security

- ✅ 6-digit random code
- ✅ Expires after 5 minutes
- ✅ One-time use only
- ✅ Not stored in plaintext
- ✅ Rate limited: 5 attempts → 15 min lockout

### Compliance (India)

ZSI must follow:
- **TRAI Guidelines**: Include unsubscribe option
- **Data Privacy**: Encrypted storage, secure transmission
- **Consent**: Users opt-in to 2FA & alerts
- **Annual Audit**: Review SMS usage & costs

---

## Decision Table: Which Features to Enable?

User needs to decide (before implementation starts):

| Feature | Recommended | Cost/Month | Effort |
|---------|-------------|-----------|--------|
| Email/Password Login | ✅ YES | FREE | Low (done) |
| Email-based 2FA | ✅ YES | FREE | Medium |
| SMS 2FA | ⚠️ OPTIONAL | ₹450-900 | Medium |
| Endangered alerts | ✅ YES | ₹225-450 | Medium |
| Expert notifications | ✅ YES | ₹90-225 | Low |
| Biometric unlock | ⚠️ NICE | FREE | Low |
| Social login | ❌ SKIP | FREE | Medium (not needed) |

---

## Summary for You

### What's Already Done ✅
- Email/password login system
- Secure credential storage (Keychain/Keystore)
- SQLite database for user data
- Session management
- Rate limiting (5 failed attempts)

### What Needs Implementation ⚠️
- SMS 2FA (₹1.50 per login)
- Endangered species alerts (₹1.50 per alert)
- Expert verification alerts (₹1.50 per verification)
- User SMS preference settings

### Cost If You Implement Everything
- **Small deployment**: ~₹180-500/month
- **Medium deployment**: ~₹1,200-1,800/month
- **Large deployment**: ~₹2,700+/month

### Cost If You Skip SMS (Recommended First)
- **Email-based 2FA**: FREE
- **App notifications for alerts**: FREE
- **Backend infrastructure**: Already paid (Cloud Run)

### My Recommendation
1. **Phase 1**: Keep email-based auth (no SMS yet) - FREE
2. **Phase 2**: Add 2FA with email OTP - FREE  
3. **Phase 3** (Later): Add SMS alerts when ZSI approves budget - ₹200-500/month

Would you like me to proceed with all SMS features, or start with the FREE email-based approach first?
