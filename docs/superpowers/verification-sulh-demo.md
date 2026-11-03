# Sulh 1.7.0 verification and handoff

Base: `5729a4f6556fd805481d383bf3b9c70037d1b300` in TalalAzdeen/Upyogi.

Implemented: normalized Arabic/city search, database catalog generation (24 services, eight categories, three cities), booking autofill, saved simulation Requested → Accepted → OnTheWay → Completed, payment preview and persistent skip, resume from appointments, Arabic/English copy, platform display name صلح, version 1.7.0+11.

## Verified

- `node --test backend/supabase/functions/upyogi-api/*.test.mjs`: 12 passed, 0 failed. Requires Node 24. Handler tests substitute the Supabase transport; transition correctness is tested independently in actual Postgres.
- `backend/tests/demo_scenario_assertions.sql`: executed successfully on the connected database in a rollback transaction. Checks seed count and idempotency, ownership, sequential stages, stale retries, early skip, skip idempotency, External payment status/no Stripe intent, unflagged/cancelled records, execution privileges, email suppression, normalized Arabic/city search and exclusion of demos.
- Catalog persisted: 24 services / 8 categories / 3 cities under sulh-demo-v2. No test bookings from assertions retained.
- Existing `upyogi-api` deployed as version 7 with its own auth checks (gateway JWT setting remains false for existing public endpoints).
- Live HTTP smoke: health reports demoScenarioVersion 2; Arabic search الكَهرباء returns 3 services, جدة returns 8; unauthenticated catalog generation returns 401.
- All 60 Dart source/test files pass a tree-sitter syntax parse. This is not Flutter compilation or type analysis.
- `git diff --check` passed.
- Independent code review found no Critical/Important issues. Corrected the demo booking payment instructions noted in that review.

## Not verified / environment blockers

- Flutter SDK 3.47.7 was retrieved, but its Dart VM crashes before package resolution (`Failed to retrieve stack bounds`). Flutter analysis, widget tests and APK builds did not run successfully. No APK is delivered or claimed.
- `deno check` could not fetch the pinned Supabase package due to outbound npm connectivity. TypeScript source transpilation/syntax and actual deployment passed; full Deno type-check remains pending.
- GitHub integration returned 403 `Resource not accessible by integration` for both tree writes and branch creation on the owner's connection. The signed-in GitHub browser UI successfully created `codex/sulh-demo-checkout` and uploaded the implementation without changing app permissions. Remote validation is tracked on the pull request; the original connector permission remains unchanged.
- Authenticated live UI journey needs execution on a device after building; no real payment was performed.

## Existing security configuration

Database advisor reports private tables with RLS and no direct-client policies (intentional: server-only access). It also reports leaked password protection disabled in Auth; not changed by this feature. See [Supabase password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## Apply and verify

Apply the supplied patch to the base checkout. Backend migration `demo_scenario.sql` and API version 7 are already applied to the connected project; do not re-run blindly. For a different environment apply the SQL after existing 1.6 schema files, provision its dedicated test provider using supported Auth administration, then deploy all three Edge files (`index.ts`, `domain.mjs`, `demo.mjs`).

On a machine with Flutter 3.47.7:

```sh
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test --reporter expanded
flutter build apk --release --split-per-abi --target-platform android-arm64,android-arm --split-debug-info=build/symbols
```

Generate catalog as a customer, select a newly generated service, fill demo details, confirm, simulate each stage and skip checkout. Close/reopen and confirm the saved skipped state. Test actual technician and customer flows separately; demo controls are never available for ordinary bookings.
