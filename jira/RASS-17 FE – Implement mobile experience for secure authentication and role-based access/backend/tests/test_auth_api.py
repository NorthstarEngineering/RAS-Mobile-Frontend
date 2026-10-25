import sqlite3
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from backend.main import app
from backend.routers.auth_router import router as auth_router
from backend.config import API_V1_STR, DATABASE_PATH
from backend.database.seed_data import seed_database
from backend.utils.security import hash_password, create_access_token

# Mount auth_router if not already present on main app
if not any(r.path.startswith(f"{API_V1_STR}/auth") for r in app.routes):
    app.include_router(auth_router, prefix=API_V1_STR)

client = TestClient(app)


def setup_module():
    """Ensure database schema and initial seed data exist before running tests."""
    seed_database()
    conn, cur = get_db_cursor()
    # Reset seeded test accounts to clean initial state
    cur.execute(
        "UPDATE users SET password_hash = 'sha256_placeholder_hash', failed_login_attempts = 0, locked_until = NULL, is_active = 1 WHERE id IN ('usr_ceo', 'usr_bm1', 'usr_cashier1')"
    )
    # Delete transient test accounts from prior runs
    cur.execute(
        "DELETE FROM users WHERE identifier LIKE '%@rms-test.com' OR identifier LIKE 'new.manager.test%'"
    )
    conn.commit()
    conn.close()


def get_db_cursor():
    """Helper to query the SQLite database directly."""
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    return conn, conn.cursor()


def test_auth_sqlite_wal_and_schema():
    """Verify SQLite WAL mode and presence of required auth tables."""
    conn, cur = get_db_cursor()
    cur.execute("PRAGMA journal_mode")
    mode = cur.fetchone()[0]
    assert mode.lower() == "wal"

    # Verify tables exist
    for table_name in ["users", "user_sessions", "password_reset_otps", "audit_logs"]:
        cur.execute(f"SELECT COUNT(*) FROM {table_name}")
        assert cur.fetchone()[0] >= 0
    conn.close()


def test_login_success_and_jwt_generation():
    """Test successful login returns valid JWT token and logs to SQLite & audit_logs."""
    payload = {
        "identifier": "ceo@rms-stitch.com",
        "password": "password123",
    }
    response = client.post(f"{API_V1_STR}/auth/login", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True

    auth_data = data["data"]
    token = auth_data["token"]
    assert token is not None
    assert len(token) > 20
    assert auth_data["tokenType"] == "Bearer"
    assert auth_data["user"]["role"] == "ceo"
    assert auth_data["user"]["email"] == "ceo@rms-stitch.com"

    # Verify SQLite user_sessions table
    conn, cur = get_db_cursor()
    cur.execute("SELECT * FROM user_sessions WHERE token = ?", (token,))
    session = cur.fetchone()
    assert session is not None
    assert session["user_id"] == "usr_ceo"
    assert session["is_revoked"] == 0

    # Verify SQLite audit_logs table
    cur.execute(
        "SELECT * FROM audit_logs WHERE action = 'LOGIN_SUCCESS' AND user_id = 'usr_ceo' ORDER BY timestamp DESC LIMIT 1"
    )
    audit = cur.fetchone()
    assert audit is not None
    assert audit["entity_type"] == "users"
    assert audit["entity_id"] == "usr_ceo"
    conn.close()


def test_login_invalid_password_and_lockout_after_5_attempts():
    """
    Test failed login increments counter, locks account after 5 attempts,
    and records ACCOUNT_LOCKED in SQLite and audit_logs.
    """
    conn, cur = get_db_cursor()
    test_user_id = "usr_lockout_test"
    test_email = "lockout.target@rms-test.com"
    pwd_hash = hash_password("ValidPassword@2026")

    # Insert clean test user
    cur.execute("DELETE FROM users WHERE id = ?", (test_user_id,))
    cur.execute(
        """
        INSERT INTO users (id, identifier, full_name_ar, password_hash, role, is_active, failed_login_attempts)
        VALUES (?, ?, 'مستخدم اختبار القفل', ?, 'cashier', 1, 0)
        """,
        (test_user_id, test_email, pwd_hash),
    )
    conn.commit()
    conn.close()

    # Attempts 1 to 4: should return 401 Unauthorized
    for attempt in range(1, 5):
        res = client.post(
            f"{API_V1_STR}/auth/login",
            json={"identifier": test_email, "password": "WrongPassword!"},
        )
        assert res.status_code == 401
        conn, cur = get_db_cursor()
        cur.execute("SELECT failed_login_attempts, locked_until FROM users WHERE id = ?", (test_user_id,))
        row = cur.fetchone()
        assert row["failed_login_attempts"] == attempt
        assert row["locked_until"] is None
        conn.close()

    # 5th attempt: triggers account lockout (HTTP 423 Locked)
    res5 = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": test_email, "password": "WrongPassword!"},
    )
    assert res5.status_code == 423
    assert "قفل الحساب" in res5.json()["detail"]

    # Verify SQLite updated with locked_until timestamp
    conn, cur = get_db_cursor()
    cur.execute("SELECT failed_login_attempts, locked_until FROM users WHERE id = ?", (test_user_id,))
    row5 = cur.fetchone()
    assert row5["failed_login_attempts"] >= 5
    assert row5["locked_until"] is not None

    # Verify SQLite audit_logs has ACCOUNT_LOCKED
    cur.execute(
        "SELECT * FROM audit_logs WHERE action = 'ACCOUNT_LOCKED' AND entity_id = ? ORDER BY timestamp DESC LIMIT 1",
        (test_user_id,),
    )
    lockout_audit = cur.fetchone()
    assert lockout_audit is not None
    conn.close()

    # 6th attempt: immediately locked even if password is correct
    res6 = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": test_email, "password": "ValidPassword@2026"},
    )
    assert res6.status_code == 423


def test_get_me_current_session():
    """Test /api/v1/auth/me returns current session details."""
    # Login to obtain fresh token
    login_res = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": "ceo@rms-stitch.com", "password": "password123"},
    )
    token = login_res.json()["data"]["token"]

    # Call /me with Bearer token
    me_res = client.get(
        f"{API_V1_STR}/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert me_res.status_code == 200
    user_info = me_res.json()["data"]
    assert user_info["id"] == "usr_ceo"
    assert user_info["role"] == "ceo"
    assert user_info["roleArabic"] == "المدير التنفيذي"

    # Call /me without token -> 401
    unauth_res = client.get(f"{API_V1_STR}/auth/me")
    assert unauth_res.status_code == 401

    # Call /me with forged token -> 401
    bad_res = client.get(
        f"{API_V1_STR}/auth/me",
        headers={"Authorization": "Bearer invalid.jwt.token"},
    )
    assert bad_res.status_code == 401


def test_logout_revokes_session():
    """Test /api/v1/auth/logout revokes session in SQLite and renders token invalid."""
    # Login
    login_res = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": "ceo@rms-stitch.com", "password": "password123"},
    )
    token = login_res.json()["data"]["token"]

    # Verify token works before logout
    pre_check = client.get(f"{API_V1_STR}/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert pre_check.status_code == 200

    # Logout
    logout_res = client.post(
        f"{API_V1_STR}/auth/logout",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert logout_res.status_code == 200
    assert logout_res.json()["success"] is True

    # Verify SQLite user_sessions table has is_revoked = 1
    conn, cur = get_db_cursor()
    cur.execute("SELECT is_revoked FROM user_sessions WHERE token = ?", (token,))
    revoked_status = cur.fetchone()[0]
    assert revoked_status == 1

    # Verify SQLite audit_logs table has LOGOUT
    cur.execute(
        "SELECT * FROM audit_logs WHERE action = 'LOGOUT' AND user_id = 'usr_ceo' ORDER BY timestamp DESC LIMIT 1"
    )
    audit = cur.fetchone()
    assert audit is not None
    conn.close()

    # Call /me after logout -> 401 (Session revoked)
    post_check = client.get(f"{API_V1_STR}/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert post_check.status_code == 401
    assert "إلغاء الجلسة" in post_check.json()["detail"]


def test_forgot_password_and_otp_flow():
    """Test forgot-password generates 6-digit OTP in SQLite password_reset_otps."""
    email = "manager.downtown@rms-stitch.com"
    res = client.post(
        f"{API_V1_STR}/auth/forgot-password",
        json={"identifier": email, "method": "sms"},
    )
    assert res.status_code == 200
    data = res.json()["data"]
    otp_id = data["otpId"]
    dev_otp = data["devOtpCode"]
    assert otp_id is not None
    assert len(dev_otp) == 6

    # Verify directly in SQLite password_reset_otps
    conn, cur = get_db_cursor()
    cur.execute("SELECT * FROM password_reset_otps WHERE id = ?", (otp_id,))
    row = cur.fetchone()
    assert row is not None
    assert row["identifier"] == email
    assert row["is_used"] == 0
    assert row["attempts"] == 0

    # Verify SQLite audit_logs has OTP_REQUEST
    cur.execute(
        "SELECT * FROM audit_logs WHERE action = 'OTP_REQUEST' AND entity_id = ? ORDER BY timestamp DESC LIMIT 1",
        (otp_id,),
    )
    audit = cur.fetchone()
    assert audit is not None
    conn.close()


def test_verify_otp_valid_and_invalid():
    """Test verifying OTP code: rejects invalid code, accepts valid code, produces resetToken."""
    email = "manager.downtown@rms-stitch.com"
    # 1. Request OTP
    req_res = client.post(
        f"{API_V1_STR}/auth/forgot-password",
        json={"identifier": email},
    )
    otp_data = req_res.json()["data"]
    otp_id = otp_data["otpId"]
    otp_code = otp_data["devOtpCode"]

    # 2. Try invalid OTP code
    bad_res = client.post(
        f"{API_V1_STR}/auth/verify-otp",
        json={"identifier": email, "otpCode": "000000", "otpId": otp_id},
    )
    assert bad_res.status_code == 400
    assert "غير صحيح" in bad_res.json()["detail"]

    # Verify attempts incremented in SQLite
    conn, cur = get_db_cursor()
    cur.execute("SELECT attempts FROM password_reset_otps WHERE id = ?", (otp_id,))
    assert cur.fetchone()[0] == 1
    conn.close()

    # 3. Submit correct OTP code
    good_res = client.post(
        f"{API_V1_STR}/auth/verify-otp",
        json={"identifier": email, "otpCode": otp_code, "otpId": otp_id},
    )
    assert good_res.status_code == 200
    res_data = good_res.json()["data"]
    assert res_data["verified"] is True
    reset_token = res_data["resetToken"]
    assert reset_token is not None

    # Verify in SQLite: is_used == 1
    conn, cur = get_db_cursor()
    cur.execute("SELECT is_used FROM password_reset_otps WHERE id = ?", (otp_id,))
    assert cur.fetchone()[0] == 1

    # Verify SQLite audit_logs has OTP_VERIFIED
    cur.execute(
        "SELECT * FROM audit_logs WHERE action = 'OTP_VERIFIED' AND entity_id = ? ORDER BY timestamp DESC LIMIT 1",
        (otp_id,),
    )
    assert cur.fetchone() is not None
    conn.close()


def test_reset_password_with_reset_token():
    """Test full reset password workflow and verify user can log in with new password."""
    email = "manager.downtown@rms-stitch.com"
    new_password = "BrandNewManagerPassword@2026"

    # Step 1: Request OTP
    forgot_res = client.post(f"{API_V1_STR}/auth/forgot-password", json={"identifier": email})
    otp_code = forgot_res.json()["data"]["devOtpCode"]

    # Step 2: Verify OTP
    verify_res = client.post(f"{API_V1_STR}/auth/verify-otp", json={"identifier": email, "otpCode": otp_code})
    reset_token = verify_res.json()["data"]["resetToken"]

    # Step 3: Reset password
    reset_res = client.post(
        f"{API_V1_STR}/auth/reset-password",
        json={
            "identifier": email,
            "resetToken": reset_token,
            "newPassword": new_password,
            "confirmPassword": new_password,
        },
    )
    assert reset_res.status_code == 200
    assert reset_res.json()["success"] is True

    # Step 4: Verify in SQLite users table
    conn, cur = get_db_cursor()
    cur.execute("SELECT password_hash FROM users WHERE identifier = ?", (email,))
    updated_hash = cur.fetchone()[0]
    assert updated_hash.startswith("pbkdf2_sha256$")

    # Verify SQLite audit_logs has PASSWORD_RESET
    cur.execute(
        "SELECT * FROM audit_logs WHERE action = 'PASSWORD_RESET' AND user_id = 'usr_bm1' ORDER BY timestamp DESC LIMIT 1"
    )
    assert cur.fetchone() is not None
    conn.close()

    # Step 5: Log in with the newly reset password
    login_new = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": email, "password": new_password},
    )
    assert login_new.status_code == 200
    assert login_new.json()["data"]["user"]["role"] == "branch_manager"


def test_change_password_authenticated():
    """Test authenticated user password change."""
    # Login as cashier
    email = "1048"
    initial_pass = "password123"
    new_pass = "NewCashierSecret@2026"

    login_res = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": email, "password": initial_pass},
    )
    token = login_res.json()["data"]["token"]

    # Try change password with wrong current password -> 400
    fail_res = client.post(
        f"{API_V1_STR}/auth/change-password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "currentPassword": "WrongCurrentPassword",
            "newPassword": new_pass,
            "confirmPassword": new_pass,
        },
    )
    assert fail_res.status_code == 400

    # Change password with valid current password -> 200
    ok_res = client.post(
        f"{API_V1_STR}/auth/change-password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "currentPassword": initial_pass,
            "newPassword": new_pass,
            "confirmPassword": new_pass,
            "logoutOtherDevices": True,
        },
    )
    assert ok_res.status_code == 200
    assert ok_res.json()["success"] is True

    # Verify SQLite audit_logs has PASSWORD_CHANGED
    conn, cur = get_db_cursor()
    cur.execute(
        "SELECT * FROM audit_logs WHERE action = 'PASSWORD_CHANGED' AND user_id = 'usr_cashier1' ORDER BY timestamp DESC LIMIT 1"
    )
    assert cur.fetchone() is not None
    conn.close()

    # Verify new password works for login
    login_ok = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": email, "password": new_pass},
    )
    assert login_ok.status_code == 200


def test_ceo_get_accounts_and_rbac():
    """Test GET /api/v1/auth/accounts: CEO has access; cashier is forbidden."""
    # 1. Login as CEO
    ceo_res = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": "ceo@rms-stitch.com", "password": "password123"},
    )
    ceo_token = ceo_res.json()["data"]["token"]

    # 2. Login as cashier
    cashier_res = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": "1048", "password": "NewCashierSecret@2026"},
    )
    cashier_token = cashier_res.json()["data"]["token"]

    # CEO access -> 200 OK
    accounts_res = client.get(
        f"{API_V1_STR}/auth/accounts",
        headers={"Authorization": f"Bearer {ceo_token}"},
    )
    assert accounts_res.status_code == 200
    body = accounts_res.json()
    assert body["success"] is True
    assert len(body["data"]) >= 3
    # Check account fields
    acc = body["data"][0]
    assert "id" in acc
    assert "name" in acc
    assert "email" in acc
    assert "role" in acc
    assert "roleArabic" in acc
    assert "isActive" in acc

    # Cashier access -> 403 Forbidden
    cashier_denied = client.get(
        f"{API_V1_STR}/auth/accounts",
        headers={"Authorization": f"Bearer {cashier_token}"},
    )
    assert cashier_denied.status_code == 403

    # Unauthenticated access -> 401 Unauthorized
    unauth = client.get(f"{API_V1_STR}/auth/accounts")
    assert unauth.status_code == 401


def test_ceo_create_account_and_persistence():
    """Test CEO creating a new user account, SQLite persistence, and audit logging."""
    ceo_res = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": "ceo@rms-stitch.com", "password": "password123"},
    )
    ceo_token = ceo_res.json()["data"]["token"]

    new_user_email = "new.manager.test@rms-ops.com"
    # Ensure cleanup
    conn, cur = get_db_cursor()
    cur.execute("DELETE FROM users WHERE identifier = ?", (new_user_email,))
    conn.commit()
    conn.close()

    create_payload = {
        "name": "محمود سمير رضوان",
        "email": new_user_email,
        "password": "PasswordManager@2026",
        "role": "مدير فرع",
        "branchId": "br_02",
        "phone": "01099887766",
    }

    create_res = client.post(
        f"{API_V1_STR}/auth/accounts",
        headers={"Authorization": f"Bearer {ceo_token}"},
        json=create_payload,
    )
    assert create_res.status_code == 201
    created_account = create_res.json()["data"]
    new_user_id = created_account["id"]
    assert created_account["name"] == "محمود سمير رضوان"
    assert created_account["email"] == new_user_email
    assert created_account["role"] == "branch_manager"
    assert created_account["isActive"] is True

    # Verify directly in SQLite users table
    conn, cur = get_db_cursor()
    cur.execute("SELECT * FROM users WHERE id = ?", (new_user_id,))
    db_user = cur.fetchone()
    assert db_user is not None
    assert db_user["identifier"] == new_user_email
    assert db_user["full_name_ar"] == "محمود سمير رضوان"
    assert db_user["role"] == "branch_manager"
    assert db_user["is_active"] == 1

    # Verify SQLite audit_logs table
    cur.execute(
        "SELECT * FROM audit_logs WHERE action = 'ACCOUNT_CREATED' AND entity_id = ? ORDER BY timestamp DESC LIMIT 1",
        (new_user_id,),
    )
    audit = cur.fetchone()
    assert audit is not None
    assert audit["user_id"] == "usr_ceo"
    conn.close()

    # Verify new user can authenticate
    new_user_login = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": new_user_email, "password": "PasswordManager@2026"},
    )
    assert new_user_login.status_code == 200
    assert new_user_login.json()["data"]["user"]["id"] == new_user_id


def test_ceo_toggle_account_status():
    """Test CEO toggling user account status (active <-> disabled) and verify session revocation."""
    ceo_res = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": "ceo@rms-stitch.com", "password": "password123"},
    )
    ceo_token = ceo_res.json()["data"]["token"]

    target_email = "toggle.target@rms-test.com"
    target_pass = "TargetPass@2026"

    # Ensure clean state
    conn, cur = get_db_cursor()
    cur.execute("DELETE FROM users WHERE identifier = ?", (target_email,))
    conn.commit()
    conn.close()

    # Provision user
    create_res = client.post(
        f"{API_V1_STR}/auth/accounts",
        headers={"Authorization": f"Bearer {ceo_token}"},
        json={
            "name": "مستخدم اختبار التبديل",
            "email": target_email,
            "password": target_pass,
            "role": "shift_lead",
            "branchId": "br_01",
        },
    )
    target_id = create_res.json()["data"]["id"]

    # User logs in and gets active token
    user_login = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": target_email, "password": target_pass},
    )
    assert user_login.status_code == 200
    user_token = user_login.json()["data"]["token"]

    # CEO toggles account status -> Disabled (isActive = False)
    toggle_res1 = client.patch(
        f"{API_V1_STR}/auth/accounts/{target_id}/toggle-status",
        headers={"Authorization": f"Bearer {ceo_token}"},
    )
    assert toggle_res1.status_code == 200
    assert toggle_res1.json()["data"]["isActive"] is False

    # Verify SQLite users table
    conn, cur = get_db_cursor()
    cur.execute("SELECT is_active FROM users WHERE id = ?", (target_id,))
    assert cur.fetchone()[0] == 0

    # Verify SQLite user_sessions table revoked
    cur.execute("SELECT is_revoked FROM user_sessions WHERE user_id = ?", (target_id,))
    assert cur.fetchone()[0] == 1

    # Verify SQLite audit_logs has STATUS_TOGGLED
    cur.execute(
        "SELECT * FROM audit_logs WHERE action = 'STATUS_TOGGLED' AND entity_id = ? ORDER BY timestamp DESC LIMIT 1",
        (target_id,),
    )
    audit = cur.fetchone()
    assert audit is not None
    conn.close()

    # User tries to access /me with old token -> 401
    me_attempt = client.get(
        f"{API_V1_STR}/auth/me",
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert me_attempt.status_code in [401, 403]

    # User tries to login while disabled -> 403 Forbidden
    login_attempt = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": target_email, "password": target_pass},
    )
    assert login_attempt.status_code == 403
    assert "معطل" in login_attempt.json()["detail"]

    # CEO toggles status again -> Reactivated (isActive = True)
    toggle_res2 = client.patch(
        f"{API_V1_STR}/auth/accounts/{target_id}/toggle-status",
        headers={"Authorization": f"Bearer {ceo_token}"},
    )
    assert toggle_res2.status_code == 200
    assert toggle_res2.json()["data"]["isActive"] is True

    # User can now login again -> 200 OK
    reactivated_login = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": target_email, "password": target_pass},
    )
    assert reactivated_login.status_code == 200


def test_full_auth_lifecycle_e2e():
    """
    Complete end-to-end authentication lifecycle verification:
    Wrong logins -> 5 attempts lock -> Unlock/Reset -> Valid login -> Session read -> OTP -> Reset password -> CEO audit.
    """
    e2e_email = "e2e.lifecycle@rms-test.com"
    initial_pwd = "InitialSecret@2026"
    final_pwd = "FinalSecureSecret@2026"

    # Ensure clean state
    conn, cur = get_db_cursor()
    cur.execute("DELETE FROM users WHERE identifier = ?", (e2e_email,))
    conn.commit()
    conn.close()

    # 1. CEO provisions account
    ceo_res = client.post(
        f"{API_V1_STR}/auth/login",
        json={"identifier": "ceo@rms-stitch.com", "password": "password123"},
    )
    ceo_token = ceo_res.json()["data"]["token"]

    create_res = client.post(
        f"{API_V1_STR}/auth/accounts",
        headers={"Authorization": f"Bearer {ceo_token}"},
        json={
            "name": "مستخدم دورة المصادقة الشاملة",
            "email": e2e_email,
            "password": initial_pwd,
            "role": "cashier",
            "branchId": "br_01",
        },
    )
    assert create_res.status_code == 201

    # 2. 5 wrong attempts trigger lockout
    for _ in range(5):
        client.post(f"{API_V1_STR}/auth/login", json={"identifier": e2e_email, "password": "WrongPassword"})

    lock_res = client.post(f"{API_V1_STR}/auth/login", json={"identifier": e2e_email, "password": initial_pwd})
    assert lock_res.status_code == 423

    # 3. Forgotten password flow bypasses lockout via verified OTP
    otp_res = client.post(f"{API_V1_STR}/auth/forgot-password", json={"identifier": e2e_email})
    otp_code = otp_res.json()["data"]["devOtpCode"]

    v_res = client.post(f"{API_V1_STR}/auth/verify-otp", json={"identifier": e2e_email, "otpCode": otp_code})
    reset_tok = v_res.json()["data"]["resetToken"]

    # 4. Reset password
    rst_res = client.post(
        f"{API_V1_STR}/auth/reset-password",
        json={"identifier": e2e_email, "resetToken": reset_tok, "newPassword": final_pwd},
    )
    assert rst_res.status_code == 200

    # 5. Login with final password succeeds and lockout is cleared
    new_login = client.post(f"{API_V1_STR}/auth/login", json={"identifier": e2e_email, "password": final_pwd})
    assert new_login.status_code == 200
    user_tok = new_login.json()["data"]["token"]

    # 6. Read session via /me
    me = client.get(f"{API_V1_STR}/auth/me", headers={"Authorization": f"Bearer {user_tok}"})
    assert me.status_code == 200
    assert me.json()["data"]["email"] == e2e_email

    # 7. Logout
    logout = client.post(f"{API_V1_STR}/auth/logout", headers={"Authorization": f"Bearer {user_tok}"})
    assert logout.status_code == 200
