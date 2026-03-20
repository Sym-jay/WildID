# Quick Reference: Authentication & SMS

## Your 3 Questions Answered Simply

### Q: Does the app store user data?
**YES** - On the device in 2 places:
1. **Secure encrypted storage** - Email/password (like device's vault)
2. **SQLite database** - Sighting records (like phone's photo gallery)

Both survive app restart. It's like your phone remembering your login next time you turn it on.

---

### Q: What authentication does it have?
**Currently (FREE):**
- ✅ Email + password login
- ✅ Secure encryption (Keychain/Keystore)
- ✅ OTP code generation (6 digits)

**Optional to add:**
- ⚠️ SMS-based 2FA (₹1.50 per login)
- ⚠️ SMS alerts (₹1.50 per alert)

---

### Q: Does SMS cost money?
**YES - but only if enabled:**

| Feature | Cost | Monthly (Example) |
|---------|------|------------------|
| Email-based 2FA | FREE ✅ | $0 |
| SMS 2FA | ₹1.50 each | ₹450/month (300 logins) |
| Endangered alerts | ₹1.50 each | ₹225/month (150 alerts) |
| **Total if all SMS** | | **₹675/month (~$8)** |

**No subscription** - you only pay when SMS is sent

---

## The 3 Features Explained

### Feature 1: Email/Password Login (FREE ✅)

```
First time:
You → Email + Password → Encrypted on phone → Remember for next time

Next time:
App opens → Finds saved email → Auto-login (no password needed)

Cost: $0
```

### Feature 2: SMS 2FA (₹1.50 per login)

```
Login with SMS 2FA:
You → Email + Password → 
  Server asks: SMS or Email verification? →
  You get 6-digit code →
  You enter code →
  Access granted ✅

Without 2FA next time:
App auto-logins (no need to verify again)

Cost: Only if user enables it
Average: ₹15-30 per user per month
```

### Feature 3: Endangered Species Alerts (₹1.50 per SMS)

```
User takes photo
    ↓
Identifies endangered animal (e.g., Tiger)
    ↓
System checks: "Is this endangered?"
    ↓
Sends SMS to experts: "🐅 Tiger spotted at location"

Cost: ₹1.50 per SMS
Average: ₹7-15 per endangered sighting
Optional: User can disable in settings
```

---

## Cost Comparison

### Cheapest Option (No SMS)
```
Email-based login: FREE
Email-based 2FA: FREE
In-app notifications: FREE
─────────────────────
Total: ₹0/month
```

### Most Secure (SMS Everything)
```
Email login: FREE
SMS 2FA: ₹450-900/month (300-600 logins)
SMS alerts: ₹225-450/month (150-300 alerts)
─────────────────────
Total: ₹675-1,350/month
```

### Recommended (Balanced)
```
Email login: FREE
Email-based 2FA: FREE
SMS alerts (optional, user opt-in): ₹50-150/month
─────────────────────
Total: ₹50-150/month (~$0.60-1.80)
```

---

## What ZSI Needs to Decide

Before starting: **Choose your setup**

```
[ ] Email-only (FREE)
     - Login: Email + password
     - 2FA: Optional email code
     - Alerts: In-app only
     Monthly cost: ₹0

[ ] Email + SMS Alerts (CHEAP)
     - Login: Email + password  
     - 2FA: Optional email code
     - Alerts: SMS for endangered species only
     Monthly cost: ₹225-450

[ ] Full SMS (MOST SECURE)
     - Login: Email + password
     - 2FA: SMS code required
     - Alerts: SMS for all events
     Monthly cost: ₹675-1,500

[ ] Other (your choice):
     ___________________________________
```

---

## Implementation Timeline

If starting today:

```
Week 1 (6-8 hours):
- Add SMS service to backend
- Add users table to database
- Test locally

Week 2 (4-6 hours):
- Add 2FA screens to app
- Update login flow
- Test end-to-end

Week 3 (4-6 hours):
- Add endangered species alerts
- Set up SMS permissions
- User testing

Week 4 (6-8 hours):
- Integrate ensemble models
- Deploy to production
- Monitor SMS costs

Total: 20-28 hours = 3-4 days of focused work
```

---

## Data Security

Your data is protected like this:

```
📱 Phone Storage (Encrypted)
├─ Email address: 🔐 AES-256 encrypted
├─ Password: 🔐 Hashed (bcrypt)
├─ OTP tokens: 🔐 Encrypted
└─ Sightings: 🔐 SQLite (on-device)

☁️ Cloud Storage (Optional)
├─ Only when you submit sightings
├─ HTTPS encrypted (in transit)
└─ Can be deleted anytime

✅ Security Level: Military-grade
✅ Standard: iPhone Keychain + Android Keystore
✅ Compliance: Follows Indian data privacy laws
```

---

## SMS Provider Options

If you enable SMS:

### Option 1: Government SMS API (RECOMMENDED FOR ZSI)
```
Provider: sms.gov.in
Cost: ₹1.50 per SMS
Setup time: 2-4 weeks (requires gov approval)
Best for: ZSI (government organization)
```

### Option 2: Twilio
```
Provider: Twilio
Cost: $0.01-0.02 per SMS (~₹0.75-1.50)
Setup time: 5 minutes
Best for: Quick testing, international
```

### Option 3: Email Only
```
Provider: SMTP (your own)
Cost: FREE
Setup time: Already done
Best for: Always-free solution
```

---

## Frequently Asked Questions

**Q: If I uninstall the app, will my login still work?**
A: No - all data deleted. You'll need to login again after reinstalling.

**Q: Can another app read my sightings?**
A: No - each app has isolated storage (security feature).

**Q: If SMS fails, what happens?**
A: Email sent as backup. User always gets notification.

**Q: Can users see the SMS cost?**
A: No - ZSI pays for SMS. Users don't see direct cost.

**Q: Is internet required for 2FA?**
A: First login: yes (to send OTP). After that: no (if offline).

**Q: Can I disable 2FA later?**
A: Yes - users can toggle it in settings anytime.

**Q: How secure is email-based 2FA?**
A: Almost as secure as SMS, but user needs internet for email.

---

## Decision Template for You

Print this and fill it out before starting:

```
┌─────────────────────────────────────────┐
│  ZSI Authentication Setup Decision      │
├─────────────────────────────────────────┤
│ Date: _______________                   │
│ Approved by: _______________            │
│                                         │
│ Features to implement:                  │
│ ☐ Email login (mandatory)              │
│ ☐ Email 2FA (recommended)              │
│ ☐ SMS 2FA (optional, cost: ₹450-900)  │
│ ☐ SMS alerts (optional, cost: ₹225-450)│
│                                         │
│ SMS Provider (if SMS enabled):          │
│ ☐ Government API                        │
│ ☐ Twilio                                │
│ ☐ Other: _______________               │
│                                         │
│ Monthly Budget for SMS:                 │
│ ₹ _______________                       │
│                                         │
│ Priority (1=first, 3=last):             │
│ ___ Ensemble models                     │
│ ___ 2FA implementation                  │
│ ___ SMS alerts                          │
└─────────────────────────────────────────┘
```

---

## What You Have vs What You Need

### What You Have Today (FREE) ✅
- Email/password authentication
- Secure encrypted storage
- OTP generation
- SQLite database for sightings
- Session management

### What You're Adding
- [ ] SMS service backend (NEW)
- [ ] 2FA implementation (NEW or upgrade)
- [ ] SMS alert triggers (NEW)
- [ ] Ensemble model integration (NEW)

### Timeline
- **To add all features**: 3-4 weeks
- **To add 2FA only**: 1-2 weeks  
- **To add ensemble only**: 1-2 weeks

---

## Bottom Line Summary

| Aspect | Status | Cost |
|--------|--------|------|
| Does app have auth? | ✅ YES | FREE |
| Does data persist? | ✅ YES | FREE |
| Is it secure? | ✅ YES | FREE |
| Do I need SMS? | ⚠️ OPTIONAL | ₹0-1,500/mo |
| Do I need 2FA? | ⚠️ RECOMMENDED | ₹0 (email) |
| Do I need ensemble? | ✅ YES | FREE |

**Recommendation:**
1. Add email-based 2FA (FREE)
2. Integrate ensemble models (FREE)
3. Add SMS alerts later (when ZSI budget approved)

Cost: **₹0-300/month** (just SMS if enabled)
Effort: **20-28 hours** (3-4 days)

---

**Questions?** See `Auth_strategy.md` for detailed information.

Last updated: 2026-03-20
