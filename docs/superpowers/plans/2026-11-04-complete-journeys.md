# Complete Journeys Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver connected, persisted customer and technician simulation from entry to review.
**Architecture:** Shared local JourneyStore models catalog, bookings and notices. CustomerExperienceScreen and TechnicianWorkspaceScreen use it while ProviderDemoStore retains explicit package onboarding. Real authentication remains a separate path.
**Tech Stack:** Existing Flutter, Riverpod, SharedPreferences; GitHub Actions for Flutter execution.
**Spec:** docs/superpowers/specs/2026-11-04-complete-journeys-design.md

## Global Constraints
- Version 1.9.0+13; no new dependencies.
- No real payment, email, location or authentication mutations from simulation.
- Packages 100/200/300, service limits 3/10/25, no default choice.
- Simulation shared only on this device, clearly labelled in both languages.

## Review Focus
- Stale store instances and repeated transitions must not overwrite newer bookings.
- Reopening and switching roles must retain customer history and never impersonate a real session.
- Double taps and identical appointments must not create duplicate bookings or reviews.
- Deleted or disabled services must preserve historical receipt values.
- Narrow Arabic screens and large text must keep actions reachable.

### Task 1: Shared journey domain
**Files:** Create lib/services/journey_store.dart and lib/models/journey_models.dart; test test/journey_store_test.dart.
**Interfaces:** JourneyStore.load(); search(); registerCustomer(); book(); transition(); reschedule(); settle(); rate(); saveService(); dueReminders(); selectRole(); leave(). Typed JourneyService, JourneyBooking, JourneyNotice.
- [ ] Write tests for complete lifecycle, search, persistence, preconditions, stale transitions, duplicates, historical snapshots, reminders and limits.
- [ ] Run failing Flutter tests remotely before implementation; local VM restriction is already proven in 1.8.
- [ ] Implement the domain and verify all tests via CI.

### Task 2: Customer and technician interface
**Files:** Create lib/screens/experience_screen.dart and lib/screens/journey_booking_screen.dart; modify auth_gate.dart, auth_screen.dart, role_select_screen.dart, provider_demo_screen.dart; test test/experience_test.dart, test/localization_test.dart, test/widget_test.dart.
**Interfaces:** CustomerExperienceScreen(); TechnicianWorkspaceScreen({required onPlans, required onRealLogin, required onExit}); JourneyBookingScreen({required bookingId, required technician}).
- [ ] Add UI tests for customer entry, booking to completion and role switch, explicit packages, Arabic narrow rendering and real-account escape.
- [ ] Implement catalog, profile, favorites, booking form, appointments, notifications, provider service management and lifecycle detail/payment/review pages.
- [ ] Integrate role persistence with real-token precedence; run regression suite.

### Task 3: Delivery and evidence
**Files:** Modify lib/l10n/catalog.dart, pubspec.yaml, .github/workflows/android-apk.yml, README_AR.md; create docs/superpowers/verification-complete-journeys.md.
- [ ] Translate all added static strings and document remaining production requirements.
- [ ] Review the full change with a fresh reviewer and fix important findings with regression tests.
- [ ] Run Node suite, Flutter analysis/tests and build APK. Verify local/remote source tree equality and artifact checksums.
- [ ] Publish a GitHub prerelease with arm64 and arm32 APKs and report actual limitations.
