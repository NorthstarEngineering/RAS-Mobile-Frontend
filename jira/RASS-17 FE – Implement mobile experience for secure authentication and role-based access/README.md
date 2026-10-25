# RASS-17: Secure Authentication and Role-Based Access Control

## 1. Specification Overview
- **Ticket ID:** RASS-17
- **Parent Story:** FE – Implement mobile experience for secure authentication and role-based access
- **Component:** Mobile Frontend (`rms_app`) & Unified Authentication Backend
- **Platform:** Flutter (iOS / Android / Web) + FastAPI

### Scope
Implementation of the end-to-end mobile authentication flow, persistent session handling, password recovery, profile management, and granular Role-Based Access Control (RBAC) routing for all enterprise personas (CEO, Branch Manager, Supply Manager, Kitchen Staff).

---

## 2. Implemented Architecture and Components

### Frontend (Flutter)
- **State Management:** BLoC pattern (`AuthBloc`, `AuthEvent`, `AuthState`) ensuring deterministic session transitions.
- **Data Layer:**
  - `AuthRepository` (abstract contract)
  - `HttpAuthRepository` (production implementation with JWT bearer interceptors)
  - `MockAuthRepository` (isolated testing harness)
  - `AuthRemoteDataSource`
- **Domain Layer:**
  - `UserSession` entity
  - `LoginUseCase`
- **Presentation Screens:**
  - `SplashScreen`: Initialization and stored credential verification.
  - `LoginScreen`: Secure identifier/password form with client-side validation.
  - `RoleBasedHomeScreen`: Dynamic navigation hub routed by user role.
  - `ProfileAccountScreen`: User account details and active role permissions.
  - `CeoAccountManagementScreen`: Executive-level user and role governance.
  - `ChangePasswordScreen`: Authenticated credential rotation.
  - `ForgotPasswordScreen`, `OtpVerificationScreen`, `ResetPasswordScreen`, `PasswordResetSuccessScreen`: Multi-step password recovery cycle.
  - `SessionExpiredScreen`: Automatic handling of invalid/expired JWT tokens.
  - `AccessDeniedScreen`: Enforcement of RBAC boundaries.

### Backend Integration
- **Routers:** `backend/routers/auth_router.py`
- **Services:** `backend/services/auth_service.py`
- **Schemas:** `backend/schemas/auth_schemas.py`
- **Security Utilities:** `backend/utils/security.py` (PBKDF2-HMAC-SHA256 password hashing, HMAC-SHA256 JWT tokens).
- **Automated Tests:** `backend/tests/test_auth_api.py`

---

## 3. Acceptance Criteria Checklist
- [x] Approved screens and navigation hierarchies are fully implemented.
- [x] Forms and user inputs are strictly validated prior to submission.
- [x] Loading, empty, error, success, and permission states are handled across all flows.
- [x] Reusable design system components (`RMSButton`, `RMSTextField`, `RMSCard`) are utilized consistently.
- [x] Required backend APIs (`/api/v1/auth/login`, `/api/v1/auth/refresh`, `/api/v1/auth/logout`) are integrated and verified.

---

## 4. Verification and Testing Evidence
- Automated test suites passing: `pytest backend/tests/test_auth_api.py`
- Flutter unit and widget tests: Verified under `rms_app/test/`
- RBAC boundary enforcement: Unauthorized role navigation redirects to `AccessDeniedScreen`.
