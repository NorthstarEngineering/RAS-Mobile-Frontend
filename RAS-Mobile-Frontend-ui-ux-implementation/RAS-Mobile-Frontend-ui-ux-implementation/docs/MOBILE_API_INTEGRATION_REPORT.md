# RAS Sprint Integration Verification Report

**Audit date:** 2026-10-14  
**Verification disposition:** **LOCAL API END-TO-END CHECKS PASSED; FLUTTER DEVICE RUNTIME UNVERIFIED** — no deployment or release decision is made by this report.

## Scope and workspace

- Flutter frontend: `RAS-Mobile-Frontend-ui-ux-implementation/RAS-Mobile-Frontend-ui-ux-implementation`; Flutter with `flutter_bloc`, `get_it`, and `go_router`, Arabic RTL UI.
- Backend: `RAS-Backend-main/RAS-Backend-main`; separate Auth, Branch, and Attendance Go services, PostgreSQL, migrations, Docker Compose, service API docs, and authorization tests.
- Handoff artifacts: workspace-root `api/` includes OpenAPI, mobile integration guide, Postman collection, environment template, and mock fixtures.
- The root and nested components have no Git metadata. Before editing, backups were made for the API client, its test, this report, and the Postman collection. Backups have `.pre-readiness.bak` in their names. No deployment or CI/CD action was taken.

## Verification matrix

Service clients use separate configurable base URLs and append requests to `/api/v1`. All authenticated rows send `Authorization: Bearer <access_token>`. HTTP failures are decoded from the common `{error:{code,message}}` shape when present; Arabic UI messages avoid showing raw server details. The client has a 15-second request timeout and handles empty/204 responses without JSON decoding.

Source review also confirms Arabic error mapping for 400, 401, 403, 404, 409, 429 (including `Retry-After`), and 5xx responses; malformed successful JSON becomes an invalid-response error, and network/timeout exceptions map to a generic connectivity message. These cases were not all exercised against a live service; the API-client automated tests cover representative error, malformed JSON, and 204 responses.

| Connected flow | Mobile request/response mapping | Backend contract and authorization | Outcome |
|---|---|---|---|
| Login and session lifecycle | POST /auth/login sends email and password without bearer auth; session parser reads access_token, refresh_token, token_type, expires_at, and user. Tokens and identity use secure storage. Refresh sends refresh_token; logout sends refresh_token and accepts 204. Change-password sends current_password and new_password. | Auth routes are /api/v1/auth/login, /refresh, /logout, and /change-password; protected routes use bearer JWTs. | LOCAL HTTP VERIFIED: development CEO login and mandatory first-password change returned 200; /me and refresh rotation returned 200; logout returned 204 and the revoked refresh token returned 401. |
| Branch listing | GET /branches returns a direct JSON array mapped to the existing branch fields. | CEO and Branch Manager may read; Branch Manager results are scoped to the branch in the signed token. | LOCAL HTTP VERIFIED: CEO listing returned the seeded development branch; a locally signed Branch Manager token returned only its claimed branch. |
| Employee listing | GET /employees expects {employees,total} and maps the existing roster fields. | CEO may list all; Branch Manager is scoped to own branch. | LOCAL HTTP VERIFIED: CEO and branch-scoped listing returned the seeded employee. |
| Employee editing | PATCH /employees/:id sends the existing edit fields; identifier is the backend employee ID. | Attendance update DTO accepts the fields and service enforces employee and branch rules. | LOCAL HTTP VERIFIED: PATCH returned 200 and the changed name was confirmed in PostgreSQL; a mismatched-branch edit returned 403 and left the employee unchanged. |
| Attendance check-in | POST /attendance/check-in sends employee_id and source=manual from the backend roster; mutations are not replayed after 401. | UUID employee ID and source enum are required. Returns 201 with record and optional deduction; server enforces role and branch scope. | LOCAL HTTP VERIFIED: CEO check-in returned 201 and the record was later closed; mismatched-branch check-in returned 403 without creating a record. |
| Attendance check-out | POST /attendance/check-out sends employee_id from the backend roster; mutations are not replayed after 401. | UUID employee ID required; returns the attendance record and applies server-side role and branch authorization. | LOCAL HTTP VERIFIED: check-out returned 200; PostgreSQL confirmed closed status with a non-null check-out time. |
| Overtime listing | GET /overtime reads {records,total} and joins each employee_id to the existing Employee repository for display data. | CEO sees all; Branch Manager is branch-scoped. | LOCAL HTTP VERIFIED: CEO listing returned a pending overtime fixture inserted directly into the disposable test database. The overtime-creation API and UI were not exercised. |
| Overtime approval | PATCH /overtime/:id/approve sends no body; on success the existing list refreshes. | CEO or same-branch Branch Manager; returns the updated overtime response. | LOCAL HTTP VERIFIED: CEO approval returned 200 and both the refreshed API list and PostgreSQL showed approved; wrong-branch approval returned 403. |

### Intentionally unconnected flows

- Overtime creation remains unconnected: backend requires `employee_id` UUID, `work_date`, positive `hours`, positive `rate_per_hour`, and `source`; the existing screen does not collect all required values.
- Overtime rejection remains unconnected: backend requires a `reason` of 3–500 characters; the existing review UI does not collect it.
- These gaps are intentional. No fields, dialogs, or UI actions were added to bridge them.
- Branch create/edit screens do not provide all backend create requirements. Employee creation, CEO user administration, and profile/email screens remain unconnected. Attendance history, payroll history, fingerprint ingestion, branch transfer, password recovery/OTP, menu, and pricing have no verified matching backend routes.

## Source and contract review

- Inspected Auth session DTOs and route registration; Branch direct-array list response; Attendance employee `{employees,total}` response; check-in 201 `{record,deduction?}` and check-out 200 record responses; and Overtime `{records,total}` plus approval/rejection/create DTOs.
- OpenAPI paths and schemas for these routes are consistent with the inspected backend DTOs for the request/response fields relevant to the connected screens. The mobile contract guide also documents the backend branch check for attendance.
- The Postman collection had a stale check-in request name claiming that a branch-authorization gap existed. Backend source and authorization tests show that the check is present. The request name now says the server enforces branch scope; the example request itself was not changed.
- The API client previously replayed POST/PATCH requests after a 401 even though its comment said mutations are not retried and no idempotency key exists. It now refreshes session state but replays only GET; a mutation that got 401 is surfaced without a second send. A focused regression test verifies one POST attempt and successful session refresh.
- Attendance authorization Go tests and all other existing Go tests passed in this verification, run in isolated Go containers with source mounted read-only.

## Connectivity and backend configuration

- Docker Engine 29.8.2 and Docker Compose v5.6.0 were available. The backend project .env was absent and remained absent; the seven required values were supplied only through a temporary ACL-restricted development env file, then removed. No credentials are recorded here.
- The stock Compose file hardcodes the ras_backend_postgres_data volume and standard ports. A validated temporary override selected project rasverify64d6cad45c30, unique volume rasverify_64d6cad45c304d3591b260f9f245af5d_pgdata, no published PostgreSQL port, and loopback-only API ports 19001, 19002, and 19003. None of the ten volumes present before verification was used or changed.
- PostgreSQL started healthy; the checked-in Goose v3.28.0 migrations ran successfully against the isolated restaurant_db. The guarded database/seeds/dev.sql fixture inserted one local branch and employee. The first role-bootstrap one-off returned zero without SQL output and the app roles were absent; an explicit shell invocation of the existing roles.sql created them. Since migrations had already run before roles existed, their conditional grants had skipped those roles; the exact existing grants from the checked-in migrations were then applied to this test database. No backend files or migrations were changed.
- Compose image builds repeatedly failed with BuildKit RPC Unavailable / EOF while compiling Goose or the Attendance API. The captured RAS build logs contained no Go runtime panic. Auth and Branch images built individually; the exact Goose v3.28.0 binary and Attendance API binary were built in single Go 1.27.2 Alpine containers. Migrations ran with that Goose binary, and the Attendance binary was mounted read-only for the local runtime. This workaround did not change dependencies or source; it does not verify the stock migration or Attendance Docker image build paths.
- All three local service health endpoints returned HTTP 200. After HTTP verification, only the uniquely named test containers and network were removed without -v. The unique test database volume was preserved, and a final check confirmed all ten pre-existing volumes remained present. Temporary credentials, overrides, and logs were removed.
- No API Gateway or remote service was used. No production or staging URL or credentials were configured.
## Flutter and API validation

### Automated/local checks

- flutter analyze --no-pub: passed; no issues found.
- flutter test --no-pub --concurrency=1: passed, 7 tests (six API-client tests and the app smoke test), including the mutation-not-replayed regression.
- flutter pub get passed in the earlier integration run; dependencies and lockfile were unchanged in this verification.
- Existing Go test suites for Auth, Branch, and Attendance all passed sequentially using golang:1.27.2-alpine containers with source mounted read-only. No Go test runtime panic reproduced.
- Compose config was validated with secrets suppressed. The stock multi-image Compose build and individual Goose/Attendance Docker builds failed with BuildKit RPC Unavailable / EOF; the local runtime workaround is described above.
- Redocly lint for the backend OpenAPI and workspace handoff had passed in an earlier integration run. Re-runs in that earlier audit produced no output within 30 seconds and were canceled; no new lint pass is claimed here. OpenAPI files were not changed.
- flutter devices did not complete discovery and was interrupted. adb devices -l failed because the ADB server could not start/connect. No Flutter app session ran against the local APIs and no Android build was produced in this verification.

### Live local HTTP checks

Actual HTTP requests were sent to the isolated Auth, Branch, and Attendance services on localhost; these are not mocked tests and do not imply remote, production, or deployed API availability.

- Health: Auth, Branch, and Attendance each returned HTTP 200.
- Authentication/session: unauthenticated protected reads returned 401; development CEO login, first-login password change, refresh rotation, and /me succeeded; logout returned 204 and refresh with the revoked token returned 401.
- Branch/employee: CEO branch and employee lists succeeded; employee PATCH returned 200 and PostgreSQL confirmed the updated name. A synthetic locally signed Branch Manager JWT listed only its claimed branch and employee.
- Authorization: mismatched-branch employee edit, attendance check-in, and overtime approval each returned 403. The denied employee edit left the database row unchanged. The synthetic Branch Manager JWT was signed with the temporary local key; no Branch Manager account was created.
- Attendance: CEO check-in returned 201; check-out returned 200; PostgreSQL confirmed the record was closed with a non-null check-out time.
- Overtime: a pending fixture was inserted directly into the disposable database, then returned by GET /overtime. CEO approve returned 200; the refreshed list and PostgreSQL confirmed approved status.
- These checks used only disposable local data. Overtime creation and rejection remain unconnected by design because the existing screens lack required backend fields.
## Go runtime trace investigation

- The available Docker Desktop rotated backend log at C:\Users\bolag\AppData\Local\Docker\log\host\com.docker.backend.exe.log.1 records the initial panic at 2026-07-19T11:31:39Z: fatal error: out of memory allocating heap arena map. Its Go runtime stack begins at runtime.throw and mheap.sysAlloc.
- The associated operation was a Docker Desktop GUI Compose stop for project medflow, using D:\Study\Projects\Data Engineer Projects\Medflow\docker-compose.yml (Docker Desktop POST /compose/bulk/:action). The trace is from Docker Desktop com.docker.backend.exe, not a RAS Go command or RAS API service.
- The current RAS BuildKit failures contain RPC Unavailable / EOF but no Go panic. All three RAS Go test suites passed, and the panic did not reproduce in their isolated Go containers. No Go dependency or backend source was changed.

## Deployment configuration inspection — no deployment performed

- `ApiConfig` defaults to HTTP localhost service URLs (`10.0.2.2` for Android emulator, `localhost` otherwise); Dart defines can override each service URL. No release target URLs are supplied or enforced in the repository. A release invocation must explicitly provide reachable HTTPS URLs; this was not tested.
- The main Android manifest does not enable cleartext traffic. The debug-only manifest enables cleartext for local development. This does not enable cleartext in the release manifest.
- Android `release` build type currently uses `signingConfigs.getByName("debug")`. This is a release/distribution configuration blocker and must be replaced by owner-provided release signing configuration before any distribution. No signing material was requested, generated, or changed.
- The prior debug APK build remained at Gradle `assembleDebug` while the Gradle 8.12 distribution was a zero-byte partial download. No APK was produced. Current Flutter diagnostics also reported that the Java version could not be determined. No release build was generated.
- No CI/CD pipeline, deployment, publish, release, cloud resource, production environment, database, migration, or DNS action was triggered.

## Verification disposition and resumption prerequisites

**LOCAL API END-TO-END CHECKS PASSED; FLUTTER DEVICE RUNTIME UNVERIFIED; ANDROID BUILD UNVERIFIED.** The connected backend flows were exercised through real HTTP requests against isolated local services, with successful state checks in the disposable PostgreSQL database. Automated Flutter and Go checks passed. No deployment or release decision is made or authorized by this report.

The local API containers and private network were removed after testing. The uniquely named verification database volume was retained, as were all ten Docker volumes that existed before the run. Temporary development credentials and Compose overrides were removed; the backend .env remains absent. The retained volume contains only this run local development fixture and should not be reused without deliberate credential and isolation setup.

Flutter UI runtime verification needs a working Android emulator/device and ADB server. The Flutter build or launch was not verified. For a future emulator run, the existing Dart defines can target the local API ports through Android emulator host forwarding: Auth 19001, Branch 19002, Attendance 19003. Start only an isolated local backend and use non-production data.

The stock Compose image build encountered BuildKit RPC EOF during Goose/Attendance compilation. The integration checks completed using the exact Goose version and a locally compiled Attendance binary without source or dependency changes. A rerun of the stock image-build path remains unverified.

Overtime creation and rejection remain intentionally unconnected. Their missing fields/dialogs must not be added as part of this integration verification.

No release APK, deployment, publish, CI/CD pipeline, cloud resource, production environment, production database migration, or DNS action was performed.