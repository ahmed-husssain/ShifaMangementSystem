# Shifa Management System (SMS) 🏥

[![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.6+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-3.x-2B579A?logo=flutter&logoColor=white)](https://riverpod.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Database%20%26%20Realtime-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](#)

> A high-performance, clinical-grade healthcare operating platform engineered for **Shifa Home Health Care**. Streamlines patient intake, clinical care team coordination, dynamic plan renewal tracking, real-time invoicing, staff payouts, and executive financial reporting.

---

## 📖 About the Platform

**Shifa Management System (SMS)** is an end-to-end clinical and administrative operating software tailored specifically for home health, palliative care, and private healthcare agencies. 

In traditional home healthcare operations, patient coverage is distributed across field caregivers (nurses, visiting physicians, physiotherapists, attendants) with variable plan durations (from 10-day acute post-surgical care to 30-day chronic care). Managing these cycles manually leads to billing discrepancies, missed renewal dates, and sudden care interruptions.

SMS bridges this gap by unifying clinical operations, staff accountability, and financial accounting into a single, intuitive interface accessible across desktop, web, and mobile devices:

- **Zero Care Gaps:** Automated plan expiration alerts ensure patient service contracts are renewed days before coverage lapses.
- **1-Click Communication:** Instant WhatsApp messaging and telephony dialer pre-populated with patient diagnosis and renewal dates.
- **Streamlined Billing:** Complete invoicing cycle from auto-filled renewal dates to professional PDF invoices and thermal receipt printing.
- **Role-Based Governance:** Secure access boundaries separating staff members from sensitive administrative analytics.

---

## 🌟 Key Features & Modules

### 1. 🔔 Intelligent Notification & Plan Renewal System (Phase 1)
- **Dynamic Duration Engine:** Automatically tracks dynamic plan lengths (e.g. 10-day post-op plans, 15-day recovery plans, 30-day chronic care) for both invoiced patients and new patient registrations.
- **7-Day Advance Countdown:** Calibrated window notifies staff during days 24–30 (on a 30-day plan) or days 4–10 (on a 10-day plan), avoiding premature alarm fatigue while ensuring timely renewals.
- **Registration-to-Invoice Handover:** New patient intake automatically monitors care duration from registration date until the first invoice is issued, after which invoice coverage dates seamlessly take over.
- **Executive UI/UX Card:**
  - **Left Urgency Accent Strip:** Color-coded border (🔴 Expired, 🟡 Today, 🔵 Upcoming, 🟣 Scheduled) for peripheral scanning.
  - **Clinical Context Box:** Groups MR number, direct phone, selected services, location address, and care team badge.
  - **Single-Line Balanced Action Bar:**
    - `[ 🧾 Issue Invoice ➔ ]`: Pre-populates the exact plan days in the billing form.
    - `[ WhatsApp ]`: 1-tap personalized renewal message.
    - `[ 📞 Call ]`: Direct telephony dialer.
    - `[ ✓ Done ]`: Mark as Handled with instant visual triage.
    - `[ 🗑 ]`: Dismiss/Delete with floating **`UNDO`** option.

### 2. 🩺 Patient Intake & Clinical Records
- Fast patient registration with Medical Record (MR) number generation.
- Interactive multi-service package selection (Home Nursing, Elderly Attendant, Physiotherapy, Doctor Visits).
- Real-time caregiver roster management (assigned Doctor, Nurse, Caretaker).
- Soft deletion and reactivation safeguards to preserve patient history.

### 3. 🧾 Smart Invoicing & Financial Accounting
- Generate official invoices with itemized healthcare services, staff payment splits, and profit margins.
- Export and print high-resolution PDF invoices and thermal receipts.
- Automatic revenue tracking, paid vs. unpaid invoice triage, and payment deduplication.

### 4. 👥 Multi-Tier Role-Based Access Control (RBAC)
- **Admin Tier:** Full operational visibility, system metrics, user role management, and hospital-wide analytics.
- **Staff Tier:** Scoped visibility limited strictly to assigned patients, care schedules, and relevant invoices.

### 5. 📊 Live Dashboard & Activity Tracking
- Real-time revenue metrics, active patient counts, and system activity logs.
- Online presence indicator showing real-time staff status across devices.

---

## 🗺 5-Phase Notification Roadmap

```
┌────────────────────────────────────────────────────────────────────────┐
│                        5-PHASE ENHANCEMENT ROADMAP                     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
  ┌─────────────────────────────────┼─────────────────────────────────┐
  ▼                                 ▼                                 ▼
Phase 1: Dynamic Engine           Phase 2: Date Continuity          Phase 3: RBAC Filtering
[COMPLETED & VERIFIED]            [UP NEXT]                         [PLANNED]
• Dynamic 10d vs 30d window       • Pre-fill exact next date        • Staff patient filtering
• 7-day advance countdown         • 0 billing gaps/overlaps         • Doctor/Nurse scoping
• Single-line executive action bar• Service package carry-over      • Global admin metrics
• Triage: Done/Delete + Undo

  ┌─────────────────────────────────┴─────────────────────────────────┐
  ▼                                                                   ▼
Phase 4: Custom Snooze                                            Phase 5: Push Alerts
[PLANNED]                                                         [PLANNED]
• "Tomorrow morning", "In 3 days"                                 • Background push notifications
• Persistent Supabase sync                                        • Audit log of all renewal actions
```

---

## 🏗 Technical Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Framework** | [Flutter SDK](https://flutter.dev) (3.27+) | Multi-platform UI (Web, Windows Desktop, Android, iOS) |
| **Language** | [Dart](https://dart.dev) (3.6+) | Core application logic and async streams |
| **State Management** | [Riverpod](https://riverpod.dev) (3.x) | Reactive dependency injection, Notifiers & StreamProviders |
| **Database & Realtime** | [Supabase](https://supabase.com) | PostgreSQL database, realtime streams, and scheduled notifications |
| **Authentication** | [Supabase Auth](https://supabase.com/auth) | JWT authentication, secure session handling, and role metadata |
| **Documents & Printing**| `pdf` & `printing` | Dynamic vector PDF invoice generation and thermal receipt printing |
| **Communication** | `url_launcher` | Native WhatsApp URL scheme integration and telephony dialer |

---

## 🧪 Verification & Automated Testing

The core business logic and dynamic notification engine are fully verified by automated unit tests:

```bash
# Run plan expiration test suite
flutter test test/features/dashboard/plan_expiration_test.dart

# Run all feature tests
flutter test test/features/
```

### Verified Test Cases:
- ✅ 30-Day Invoice: Day 10 (20 days remaining) does NOT trigger notification.
- ✅ 30-Day Invoice: Day 23 (7 days remaining) triggers Upcoming notification.
- ✅ 30-Day Invoice: Day 29.5 (12 hours remaining) triggers Today notification.
- ✅ 30-Day Invoice: Day 32 (expired 2 days ago) triggers Expired notification.
- ✅ New Patient (10 days): Day 2 (8 days left) does NOT notify.
- ✅ New Patient (10 days): Day 3 (7 days left) triggers Upcoming First Invoice alert.
- ✅ New Patient (10 days): Day 11 triggers Expired First Invoice alert.
- ✅ Handover: Once invoice is created for new patient, invoice coverage takes 100% precedence.
- ✅ Discontinued or soft-deleted patients are safely excluded.

---

## 🚀 Getting Started

### 1. Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.27.0 or higher)
- [Dart SDK](https://dart.dev/get-dart) (3.6.0 or higher)
- Chrome / Edge (for Web) or Visual Studio (for Windows Desktop)

### 2. Installation
```bash
# Clone the repository
git clone https://github.com/your-org/shifa-management.git
cd shifa-management

# Install dependencies
flutter pub get
```

### 3. Static Analysis
Verify code correctness and ensure zero analyzer issues:
```bash
dart analyze
```

### 4. Running the Application
```bash
# Run on Chrome
flutter run -d chrome

# Run on Windows Desktop
flutter run -d windows
```

---

## 🔒 Security & Best Practices
- **No Hardcoded Secrets:** Credentials, API keys, and environment tokens are managed through environment variables and secure stores.
- **RBAC Validation:** Strict database and UI checks prevent non-admin staff from accessing restricted billing reports or patient records outside their assignment.
- **Safe Handover:** Billing deduplication ensures patient renewals cannot be issued with overlapping active dates.\n