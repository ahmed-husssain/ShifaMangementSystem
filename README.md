# Shifa Management System (SMS) 🏥

[![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.6+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-3.x-2B579A?logo=flutter&logoColor=white)](https://riverpod.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Database%20%26%20Realtime-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Tests](https://img.shields.io/badge/Tests-93%20Passing-brightgreen.svg)](#)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](#)

> A high-performance, clinical-grade healthcare operating platform engineered for **Shifa Home Health Care**. Streamlines patient intake, clinical care team coordination, dynamic plan renewal tracking, real-time invoicing, staff payouts, and executive financial reporting.

---

## 📖 About the Platform

**Shifa Management System (SMS)** is an end-to-end clinical and administrative operating software tailored specifically for home health, palliative care, and private healthcare agencies. 

In traditional home healthcare operations, patient coverage is distributed across field caregivers (nurses, visiting physicians, physiotherapists, attendants) with variable plan durations (from 10-day acute post-surgical care to 30-day chronic care). Managing these cycles manually leads to billing discrepancies, missed renewal dates, and sudden care interruptions.

SMS bridges this gap by unifying clinical operations, staff accountability, and financial accounting into a single, intuitive interface accessible across desktop, web, and mobile devices:

- **Zero Care Gaps:** Automated plan expiration alerts ensure patient service contracts are renewed days before coverage lapses.
- **1-Click Communication:** Instant WhatsApp messaging and telephony dialer pre-populated with patient diagnosis and renewal dates.
- **Smart Continuity Invoicing:** Consecutive renewal billing with zero gap and zero overlap, featuring itemized healthcare services and inline editable custom service rows.
- **Role-Based Governance (RBAC):** Strict data and UI boundaries ensuring staff only access assigned patient records while administrators retain full clinical oversight.
- **Dual-Environment Architecture:** Isolated Staging and Production databases with zero leak of production invoice sequences or patient records during testing.

---

## 🌟 Key Features & Modules

### 1. 🔔 Intelligent Notification & Plan Renewal System
- **Dynamic Duration Engine:** Automatically tracks dynamic plan lengths (e.g., 10-day post-op plans, 15-day recovery plans, 30-day chronic care) for both invoiced patients and new patient registrations.
- **7-Day Advance Countdown:** Calibrated window notifies staff during days 24–30 (on a 30-day plan) or days 4–10 (on a 10-day plan), avoiding premature alarm fatigue while ensuring timely renewals.
- **Registration-to-Invoice Handover:** New patient intake automatically monitors care duration from registration date until the first invoice is issued, after which invoice coverage dates seamlessly take over.
- **Role-Based Scoping:** Staff members only receive notifications for patients explicitly assigned to them or created by them; Administrators receive hospital-wide renewal feeds.
- **Executive UI/UX Card:**
  - **Left Urgency Accent Strip:** Color-coded border (🔴 Expired, 🟡 Today, 🔵 Upcoming, 🟣 Scheduled) for peripheral scanning.
  - **Clinical Context Box:** Groups MR number, direct phone, selected services, location address, and care team badge.
  - **Single-Line Action Bar:**
    - `[ 🧾 Issue Invoice ➔ ]`: Pre-populates the exact plan days and consecutive renewal dates in the billing form.
    - `[ WhatsApp ]`: 1-tap personalized renewal message.
    - `[ 📞 Call ]`: Direct telephony dialer.
    - `[ ✓ Done ]`: Mark as Handled with instant visual triage.
    - `[ 🗑 ]`: Dismiss/Delete with floating **`UNDO`** option.

### 2. 🧾 Smart Invoicing & Financial Accounting
- **Smart Zero-Gap Continuity:** Automatic date calculation for renewal invoices ($ToDate_{prev} + 1\text{ day}$), eliminating coverage overlaps and gaps.
- **Inline Custom Service Editing:** Select "Custom Service" to directly enter custom clinical service names within the exact single-row layout without breaking or wrapping on mobile screens ($320\text{px} - 412\text{px}$).
- **Concurrency-Safe Atomic Counter:** High-reliability PostgreSQL Security Definer RPC (`create_invoice_atomic`) guaranteeing strictly sequential `SHHC` invoice numbers.
- **Itemized Payout & Margin Tracking:** Configurable daily service rates, staff payments, and gross profit margin calculations.
- **Export & Print:** High-resolution vector PDF generation, image export, and thermal receipt printing.

### 3. 🩺 Patient Intake & Clinical Records
- Fast patient registration with Medical Record (MR) number generation.
- Interactive multi-service package selection (Home Nursing, Elderly Attendant, Physiotherapy, Doctor Visits).
- Real-time caregiver roster management (assigned Doctor, Nurse, Caretaker).
- Soft deletion and reactivation safeguards to preserve patient history.

### 4. 👥 Multi-Tier Role-Based Access Control (RBAC)
- **Admin Tier:** Full operational visibility, staff activation/deactivation, hospital-wide revenue analytics, and system audit logs.
- **Staff Tier:** Scoped visibility limited strictly to assigned patients, care schedules, and relevant invoices.

### 5. 📊 Live Dashboard & Realtime Activity
- Real-time revenue metrics, active patient counts, and system activity logs via Supabase Realtime streams.
- Online presence indicator showing real-time staff status across devices.

---

## 🗺 System Enhancement Roadmap

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ENHANCEMENT & DELIVERY ROADMAP                  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
  ┌─────────────────────────────────┼─────────────────────────────────┐
  ▼                                 ▼                                 ▼
Phase 1: Dynamic Engine           Phase 2: Date Continuity          Phase 3: RBAC Filtering
[COMPLETED & VERIFIED]            [COMPLETED & VERIFIED]            [COMPLETED & VERIFIED]
• Dynamic 10d vs 30d window       • Consecutive date calculation    • Staff patient isolation
• 7-day advance countdown         • 0 billing gaps/overlaps         • Role-scoped notifications
• Single-line action bar          • Service package carry-over      • Admin-only metrics & users
• Triage: Done/Delete + Undo      • Inline custom service editing   • Account toggle & deletion

  ┌─────────────────────────────────┴─────────────────────────────────┐
  ▼                                                                   ▼
Phase 4: Multi-Environment Isolation                              Phase 5: Background Push
[COMPLETED & VERIFIED]                                            [UP NEXT]
• Staging & Production separation                                 • Native background push alerts
• Automatic release APK switching                                 • Scheduled cloud cron triggers
• Master idempotent parity sync                                   • Patient notification audit logs
```

---

## 🏗 Technical Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Framework** | [Flutter SDK](https://flutter.dev) (3.27+) | Multi-platform UI (Web, Windows Desktop, Android, iOS) |
| **Language** | [Dart](https://dart.dev) (3.6+) | Core application logic and async streams |
| **State Management** | [Riverpod](https://riverpod.dev) (3.x) | Reactive dependency injection, Notifiers & StreamProviders |
| **Database & Realtime** | [Supabase](https://supabase.com) | PostgreSQL 15, Row Level Security, Realtime CDC streams |
| **Authentication** | [Supabase Auth](https://supabase.com/auth) | JWT authentication, secure session handling, and role metadata |
| **Documents & Printing**| `pdf` & `printing` | Dynamic vector PDF invoice generation and thermal receipt printing |
| **Communication** | `url_launcher` | Native WhatsApp URL scheme integration and telephony dialer |

---

## 🧪 Verification & Automated Testing

The complete business logic, financial accounting, notification scoping, and UI layouts are validated by **93 passing automated tests**:

```bash
# Run full automated test suite
flutter test

# Run invoice calculation and layout tests
flutter test test/features/invoices/

# Run plan expiration and notification tests
flutter test test/features/dashboard/
```

### Verified Test Categories:
- ✅ **Dynamic Plan Expiration:** Validated across 10-day, 15-day, and 30-day lifecycles.
- ✅ **Zero-Gap Continuity:** Automatic consecutive date sequencing verified with leap years and month crossovers.
- ✅ **Inline Custom Service Editing:** Verified on small mobile viewports ($360\times640$) without layout breaking.
- ✅ **Staff Scoping & RBAC:** Data isolation confirmed between administrators and staff roles.
- ✅ **Financial Calculations:** Subtotal, discount clamping, grand total, and operational margins.
- ✅ **Adversarial Resilience:** Verified against sub-millicent numbers, extreme values, and rapid state cycles.

---

## 🚀 Getting Started

### 1. Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.27.0 or higher)
- [Dart SDK](https://dart.dev/get-dart) (3.6.0 or higher)
- Android Studio / VS Code with Flutter extension

### 2. Installation
```bash
# Clone the repository
git clone https://github.com/ahmed-husssain/ShifaMangementSystem.git
cd ShifaMangementSystem

# Install dependencies
flutter pub get
```

### 3. Static Analysis & Verification
Verify code correctness and ensure zero analyzer errors:
```bash
dart analyze
flutter test
```

### 4. Running the Application
```bash
# Run in debug mode (defaults to Staging database for safe testing)
flutter run

# Build production release APK (automatically connects to Production database)
flutter build apk --release
```

---

## 🔒 Security & Best Practices
- **No Hardcoded Secrets:** Production credentials strictly limited to public publishable anon keys guarded by PostgreSQL Row Level Security (RLS). Database setup scripts and administrative credentials are systematically excluded from version control.
- **Security Definer RPCs:** Critical administrative operations (atomic invoice creation, staff status toggles, user deletions) execute via backend PostgreSQL functions with strict authorization checks.
- **Isolated Environments:** Staging environment prevents cluttering real patient records and preserves invoice numbering continuity.