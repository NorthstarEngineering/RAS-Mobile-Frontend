import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional, List, Dict, Any, Tuple
from fastapi import HTTPException, status, Request

from ..database.connection import get_db
from ..utils.security import (
    hash_password,
    verify_password,
    is_placeholder_hash,
    hash_pin,
    create_access_token,
    create_refresh_token,
    create_reset_token,
    decode_token,
    generate_otp,
    hash_otp,
    verify_otp_code,
    ACCESS_TOKEN_EXPIRE_MINUTES,
)
from ..schemas.auth_schemas import (
    LoginRequest,
    LoginData,
    UserResponse,
    ForgotPasswordRequest,
    ForgotPasswordData,
    VerifyOtpRequest,
    VerifyOtpData,
    ResetPasswordRequest,
    ChangePasswordRequest,
    AccountCreateRequest,
    AccountResponse,
    AccountToggleStatusResponse,
    AccountUpdateRequest,
    AccountDeleteResponse,
)

# Role mapping dictionaries
ROLE_ARABIC_MAP = {
    "ceo": "المدير التنفيذي",
    "branch_manager": "مدير فرع",
    "shift_lead": "مسؤول وردية وتشغيل",
    "cashier": "أمين صندوق",
}

VALID_ROLES = {"ceo", "branch_manager", "shift_lead", "cashier"}


def normalize_role(role_input: str) -> str:
    """Normalize role input in English or Arabic to internal enum string."""
    role = (role_input or "").strip().lower()
    if "ceo" in role or "تنفيذي" in role:
        return "ceo"
    if "shift" in role or "lead" in role or "وردية" in role:
        return "shift_lead"
    if "cashier" in role or "صندوق" in role or "كاشير" in role:
        return "cashier"
    if "manager" in role or "مدير" in role or "branch" in role:
        return "branch_manager"
    if role in VALID_ROLES:
        return role
    return "branch_manager"


def resolve_branch_id(conn, branch_input: Optional[str]) -> Optional[str]:
    """Resolve branch ID from id, code, or name, preventing FK integrity errors."""
    if not branch_input:
        return None
    b_val = str(branch_input).strip()
    if not b_val:
        return None
    # 1. Exact ID in branches
    cur = conn.execute("SELECT id FROM branches WHERE id = ?", (b_val,))
    if cur.fetchone():
        return b_val
    # 2. Case-insensitive code or name match
    cur = conn.execute(
        "SELECT id FROM branches WHERE LOWER(code) = LOWER(?) OR name_ar LIKE ? OR name_en LIKE ?",
        (b_val, f"%{b_val}%", f"%{b_val}%"),
    )
    row = cur.fetchone()
    if row:
        return row["id"]
    # 3. Numeric code / token heuristics
    if "01" in b_val or "وسط البلد" in b_val or "104" in b_val:
        return "br_01"
    if "02" in b_val or "معادي" in b_val:
        return "br_02"
    if "03" in b_val or "تجمع" in b_val:
        return "br_03"
    if "04" in b_val or "مطبخ" in b_val or "زايد" in b_val:
        return "br_04"
    return None



def format_utc_now() -> str:
    """Get current UTC timestamp formatted for SQLite datetime."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def parse_db_datetime(dt_str: Optional[str]) -> Optional[datetime]:
    """Parse a datetime string from DB into UTC datetime."""
    if not dt_str:
        return None
    try:
        clean_str = dt_str.replace(" ", "T")
        dt = datetime.fromisoformat(clean_str)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return None


def log_audit(
    conn,
    action: str,
    entity_type: str,
    entity_id: str,
    user_id: Optional[str] = None,
    branch_id: Optional[str] = None,
    old_values: Optional[Dict[str, Any]] = None,
    new_values: Optional[Dict[str, Any]] = None,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> str:
    """Helper to record an immutable entry in audit_logs."""
    log_id = f"aud_{uuid.uuid4().hex[:12]}"
    conn.execute(
        """
        INSERT INTO audit_logs (
            id, user_id, branch_id, action, entity_type, entity_id,
            old_values_json, new_values_json, ip_address, user_agent, timestamp
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            log_id,
            user_id,
            branch_id,
            action,
            entity_type,
            entity_id,
            json.dumps(old_values, ensure_ascii=False) if old_values is not None else None,
            json.dumps(new_values, ensure_ascii=False) if new_values is not None else None,
            ip_address,
            user_agent,
            format_utc_now(),
        ),
    )
    return log_id


def build_user_response(user_row: Any, branch_name: Optional[str] = None) -> UserResponse:
    """Convert DB user row into UserResponse model."""
    role = user_row["role"]
    return UserResponse(
        id=user_row["id"],
        name=user_row["full_name_ar"],
        email=user_row["identifier"],
        role=role,
        roleArabic=ROLE_ARABIC_MAP.get(role, role),
        branchId=user_row["branch_id"],
        branchName=branch_name or user_row["branch_name"] if "branch_name" in user_row.keys() else None,
        isActive=bool(user_row["is_active"]),
    )


class AuthService:
    """Enterprise authentication and session management service backed by SQLite WAL."""

    @staticmethod
    def login(
        payload: LoginRequest,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> LoginData:
        """Authenticate user, handle lockout thresholds, issue tokens, and write audit log."""
        identifier = payload.identifier.strip().lower()
        now_dt = datetime.now(timezone.utc)
        now_str = format_utc_now()

        with get_db() as conn:
            cursor = conn.execute(
                """
                SELECT u.*, b.name_ar as branch_name
                FROM users u
                LEFT JOIN branches b ON u.branch_id = b.id
                WHERE LOWER(u.identifier) = ?
                """,
                (identifier,),
            )
            user = cursor.fetchone()

            if not user:
                log_audit(
                    conn,
                    action="LOGIN_FAILED",
                    entity_type="users",
                    entity_id=identifier,
                    new_values={"reason": "User not found", "identifier": identifier},
                    ip_address=client_ip,
                    user_agent=user_agent,
                )
                conn.commit()
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="بيانات الدخول غير صحيحة (اسم المستخدم أو كلمة المرور)",
                )

            # Check if account is active
            if not user["is_active"]:
                log_audit(
                    conn,
                    action="LOGIN_FAILED",
                    entity_type="users",
                    entity_id=user["id"],
                    branch_id=user["branch_id"],
                    new_values={"reason": "Account is disabled"},
                    ip_address=client_ip,
                    user_agent=user_agent,
                )
                conn.commit()
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="هذا الحساب معطل حالياً، يرجى مراجعة إدارة النظام",
                )

            # Check if account is an unactivated placeholder that requires admin activation
            if is_placeholder_hash(user["password_hash"]):
                log_audit(
                    conn,
                    action="LOGIN_BLOCKED_PLACEHOLDER",
                    entity_type="users",
                    entity_id=user["id"],
                    branch_id=user["branch_id"],
                    new_values={"reason": "Account requires administrative activation; placeholder credentials cannot be used."},
                    ip_address=client_ip,
                    user_agent=user_agent,
                )
                conn.commit()
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="هذا الحساب يتطلب تفعيل كلمة المرور من قبل مدير النظام قبل تسجيل الدخول.",
                )

            # Check lockout state
            locked_until_dt = parse_db_datetime(user["locked_until"])
            if locked_until_dt and locked_until_dt > now_dt:
                remaining_sec = int((locked_until_dt - now_dt).total_seconds())
                remaining_min = max(1, (remaining_sec + 59) // 60)
                raise HTTPException(
                    status_code=status.HTTP_423_LOCKED,
                    detail=f"تم قفل الحساب مؤقتاً بسبب استنفاد محاولات الدخول الخاطئة. يرجى المحاولة بعد {remaining_min} دقيقة.",
                )

            # If lockout expired, reset attempts in memory
            current_failed = user["failed_login_attempts"] if not locked_until_dt else 0

            # Verify password
            is_valid_password = verify_password(payload.password, user["password_hash"])

            if not is_valid_password:
                new_failed = current_failed + 1
                if new_failed >= 5:
                    lock_expiry = (now_dt + timedelta(minutes=15)).strftime("%Y-%m-%d %H:%M:%S")
                    conn.execute(
                        """
                        UPDATE users
                        SET failed_login_attempts = ?, locked_until = ?, updated_at = ?
                        WHERE id = ?
                        """,
                        (new_failed, lock_expiry, now_str, user["id"]),
                    )
                    log_audit(
                        conn,
                        action="ACCOUNT_LOCKED",
                        entity_type="users",
                        entity_id=user["id"],
                        branch_id=user["branch_id"],
                        new_values={"failed_attempts": new_failed, "locked_until": lock_expiry},
                        ip_address=client_ip,
                        user_agent=user_agent,
                    )
                    conn.commit()
                    raise HTTPException(
                        status_code=status.HTTP_423_LOCKED,
                        detail="تم قفل الحساب مؤقتاً لمدة 15 دقيقة لتجاوز 5 محاولات دخول خاطئة متتالية.",
                    )
                else:
                    conn.execute(
                        """
                        UPDATE users
                        SET failed_login_attempts = ?, locked_until = NULL, updated_at = ?
                        WHERE id = ?
                        """,
                        (new_failed, now_str, user["id"]),
                    )
                    remaining = 5 - new_failed
                    log_audit(
                        conn,
                        action="LOGIN_FAILED",
                        entity_type="users",
                        entity_id=user["id"],
                        branch_id=user["branch_id"],
                        new_values={"failed_attempts": new_failed, "remaining": remaining},
                        ip_address=client_ip,
                        user_agent=user_agent,
                    )
                    conn.commit()
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail=f"كلمة المرور غير صحيحة. متبقي {remaining} محاولات قبل قفل الحساب.",
                    )

            # Successful login: reset failed counters and update last login
            conn.execute(
                """
                UPDATE users
                SET failed_login_attempts = 0, locked_until = NULL, last_login_at = ?, updated_at = ?
                WHERE id = ?
                """,
                (now_str, now_str, user["id"]),
            )

            # Auto-upgrade genuine legacy SHA-256 hash to strong PBKDF2 on successful login
            if user["password_hash"] and len(user["password_hash"]) == 64 and all(c in "0123456789abcdefABCDEF" for c in user["password_hash"]):
                upgraded_hash = hash_password(payload.password)
                conn.execute(
                    "UPDATE users SET password_hash = ? WHERE id = ?",
                    (upgraded_hash, user["id"]),
                )
                log_audit(
                    conn,
                    action="CREDENTIALS_MIGRATED",
                    entity_type="users",
                    entity_id=user["id"],
                    user_id=user["id"],
                    branch_id=user["branch_id"],
                    new_values={"migrated_from": "sha256_legacy", "target_format": "pbkdf2_sha256"},
                    ip_address=client_ip,
                    user_agent=user_agent,
                )

            # Issue Tokens
            token_claims = {
                "sub": user["id"],
                "identifier": user["identifier"],
                "role": user["role"],
                "branch_id": user["branch_id"],
            }
            access_token = create_access_token(token_claims)
            refresh_token = create_refresh_token({"sub": user["id"]})

            # Record session in user_sessions table
            session_id = f"sess_{uuid.uuid4().hex[:12]}"
            session_expiry = (now_dt + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)).strftime("%Y-%m-%d %H:%M:%S")
            conn.execute(
                """
                INSERT INTO user_sessions (
                    id, user_id, token, refresh_token, expires_at, ip_address, user_agent, is_revoked, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)
                """,
                (
                    session_id,
                    user["id"],
                    access_token,
                    refresh_token,
                    session_expiry,
                    client_ip,
                    user_agent,
                    now_str,
                ),
            )

            # Write Audit Log
            log_audit(
                conn,
                action="LOGIN_SUCCESS",
                entity_type="users",
                entity_id=user["id"],
                user_id=user["id"],
                branch_id=user["branch_id"],
                new_values={"session_id": session_id, "role": user["role"]},
                ip_address=client_ip,
                user_agent=user_agent,
            )

            user_res = build_user_response(user, user["branch_name"])

            return LoginData(
                token=access_token,
                refreshToken=refresh_token,
                tokenType="Bearer",
                expiresIn=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
                user=user_res,
            )

    @staticmethod
    def logout(
        token: Optional[str] = None,
        user_id: Optional[str] = None,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> Dict[str, str]:
        """Revoke active user session and record audit log."""
        with get_db() as conn:
            session_row = None
            if token:
                cur = conn.execute("SELECT * FROM user_sessions WHERE token = ?", (token,))
                session_row = cur.fetchone()
                conn.execute(
                    "UPDATE user_sessions SET is_revoked = 1 WHERE token = ?",
                    (token,),
                )
            elif user_id:
                conn.execute(
                    "UPDATE user_sessions SET is_revoked = 1 WHERE user_id = ? AND is_revoked = 0",
                    (user_id,),
                )

            uid = session_row["user_id"] if session_row else user_id
            log_audit(
                conn,
                action="LOGOUT",
                entity_type="user_sessions",
                entity_id=session_row["id"] if session_row else (uid or "unknown"),
                user_id=uid,
                ip_address=client_ip,
                user_agent=user_agent,
            )

        return {"message": "تم تسجيل الخروج بنجاح وإلغاء الجلسة"}

    @staticmethod
    def get_current_user_from_token(token: str) -> Dict[str, Any]:
        """Validate Bearer token, session status, and user status."""
        try:
            payload = decode_token(token)
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=str(e),
                headers={"WWW-Authenticate": "Bearer"},
            )

        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="رمز المصادقة غير صالح",
                headers={"WWW-Authenticate": "Bearer"},
            )

        with get_db() as conn:
            # Check user_sessions table
            sess_cur = conn.execute(
                "SELECT * FROM user_sessions WHERE token = ?",
                (token,),
            )
            session = sess_cur.fetchone()
            if session and session["is_revoked"]:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="تم إلغاء الجلسة (Session revoked)",
                    headers={"WWW-Authenticate": "Bearer"},
                )

            # Query user
            user_cur = conn.execute(
                """
                SELECT u.*, b.name_ar as branch_name
                FROM users u
                LEFT JOIN branches b ON u.branch_id = b.id
                WHERE u.id = ?
                """,
                (user_id,),
            )
            user = user_cur.fetchone()
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="المستخدم المرتبط بهذا الرمز لم يعد موجوداً",
                    headers={"WWW-Authenticate": "Bearer"},
                )

            if not user["is_active"]:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="هذا الحساب معطل حالياً",
                )

            return dict(user)

    @staticmethod
    def get_me(current_user: Dict[str, Any]) -> UserResponse:
        """Return the current authenticated user's session details."""
        return build_user_response(current_user, current_user.get("branch_name"))

    @staticmethod
    def forgot_password(
        payload: ForgotPasswordRequest,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> ForgotPasswordData:
        """Issue an OTP code for password recovery."""
        identifier = payload.identifier.strip().lower()
        now_dt = datetime.now(timezone.utc)
        expires_dt = now_dt + timedelta(minutes=10)
        now_str = format_utc_now()
        expires_str = expires_dt.strftime("%Y-%m-%d %H:%M:%S")

        with get_db() as conn:
            cur = conn.execute(
                "SELECT * FROM users WHERE LOWER(identifier) = ?",
                (identifier,),
            )
            user = cur.fetchone()

            if user:
                # Invalidate any prior unused OTPs for this identifier
                conn.execute(
                    "UPDATE password_reset_otps SET is_used = 1 WHERE LOWER(identifier) = ? AND is_used = 0",
                    (identifier,),
                )

                otp_code = generate_otp(6)
                otp_code_hash = hash_otp(otp_code)
                otp_id = f"otp_{uuid.uuid4().hex[:12]}"

                conn.execute(
                    """
                    INSERT INTO password_reset_otps (
                        id, identifier, otp_code_hash, expires_at, is_used, attempts, created_at
                    ) VALUES (?, ?, ?, ?, 0, 0, ?)
                    """,
                    (otp_id, user["identifier"], otp_code_hash, expires_str, now_str),
                )

                log_audit(
                    conn,
                    action="OTP_REQUEST",
                    entity_type="password_reset_otps",
                    entity_id=otp_id,
                    user_id=user["id"],
                    branch_id=user["branch_id"],
                    new_values={"method": payload.method, "identifier": user["identifier"]},
                    ip_address=client_ip,
                    user_agent=user_agent,
                )

                # Record audit trace for blocked external delivery channel
                log_audit(
                    conn,
                    action="BLOCKED_EXTERNAL_DELIVERY",
                    entity_type="password_reset_otps",
                    entity_id=otp_id,
                    user_id=user["id"],
                    branch_id=user["branch_id"],
                    new_values={
                        "channel": payload.method,
                        "identifier": user["identifier"],
                        "delivery_status": "BLOCKED_EXTERNAL_DELIVERY",
                        "reason": "External SMS/Email provider not configured in isolated environment",
                    },
                    ip_address=client_ip,
                    user_agent=user_agent,
                )
            else:
                # User not found: Do not leak account existence (AUTH007 Account Enumeration protection).
                # Do not generate or persist fake OTPs ("no fake OTP sent").
                log_audit(
                    conn,
                    action="FORGOT_PASSWORD_REQUEST_UNKNOWN",
                    entity_type="users",
                    entity_id=identifier,
                    new_values={
                        "channel": payload.method,
                        "identifier": identifier,
                        "delivery_status": "BLOCKED_EXTERNAL_DELIVERY",
                        "reason": "Identifier not registered; account enumeration suppressed",
                    },
                    ip_address=client_ip,
                    user_agent=user_agent,
                )
                conn.commit()

            # Return indistinguishable generic response for both known and unknown users
            return ForgotPasswordData(
                message="تم تسجيل طلب الاسترداد وتوثيقه، وتوقف الإرسال لعدم توفر قناة خارجية معتمدة (BLOCKED_EXTERNAL_DELIVERY).",
                otpId=None,
                identifier=identifier,
                expiresInMinutes=10,
                deliveryStatus="BLOCKED_EXTERNAL_DELIVERY",
                devOtpCode=None,
            )

    @staticmethod
    def verify_otp(
        payload: VerifyOtpRequest,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> VerifyOtpData:
        """Verify the user's submitted OTP code and return a scoped resetToken."""
        identifier = payload.identifier.strip().lower()
        now_dt = datetime.now(timezone.utc)

        with get_db() as conn:
            if payload.otpId:
                cur = conn.execute(
                    "SELECT * FROM password_reset_otps WHERE id = ? AND is_used = 0",
                    (payload.otpId,),
                )
            else:
                cur = conn.execute(
                    """
                    SELECT * FROM password_reset_otps
                    WHERE LOWER(identifier) = ? AND is_used = 0
                    ORDER BY created_at DESC LIMIT 1
                    """,
                    (identifier,),
                )
            otp_row = cur.fetchone()

            if not otp_row:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="لا يوجد رمز تحقق نشط لهذا المعرف، يرجى طلب رمز جديد",
                )

            # Check expiration
            exp_dt = parse_db_datetime(otp_row["expires_at"])
            if exp_dt and exp_dt < now_dt:
                conn.execute(
                    "UPDATE password_reset_otps SET is_used = 1 WHERE id = ?",
                    (otp_row["id"],),
                )
                conn.commit()
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="انتهت صلاحية رمز التحقق، يرجى طلب رمز جديد",
                )

            # Check attempts
            current_attempts = otp_row["attempts"]
            if current_attempts >= 5:
                conn.execute(
                    "UPDATE password_reset_otps SET is_used = 1 WHERE id = ?",
                    (otp_row["id"],),
                )
                conn.commit()
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="تم تجاوز الحد الأقصى للمحاولات الخاطئة (5 محاولات). يرجى طلب رمز جديد.",
                )

            # Verify OTP code
            code_to_check = payload.get_code() if hasattr(payload, "get_code") else (payload.otpCode or "")
            is_valid = verify_otp_code(code_to_check, otp_row["otp_code_hash"])

            if not is_valid:
                conn.execute(
                    "UPDATE password_reset_otps SET attempts = attempts + 1 WHERE id = ?",
                    (otp_row["id"],),
                )
                conn.commit()
                remaining = 4 - current_attempts
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"رمز التحقق غير صحيح. متبقي {max(0, remaining)} محاولات.",
                )

            # Mark OTP as used
            conn.execute(
                "UPDATE password_reset_otps SET is_used = 1 WHERE id = ?",
                (otp_row["id"],),
            )

            # Generate scoped reset token
            reset_token = create_reset_token(otp_row["identifier"])

            log_audit(
                conn,
                action="OTP_VERIFIED",
                entity_type="password_reset_otps",
                entity_id=otp_row["id"],
                new_values={"identifier": otp_row["identifier"]},
                ip_address=client_ip,
                user_agent=user_agent,
            )

            return VerifyOtpData(
                verified=True,
                message="تم التحقق من الرمز بنجاح. يمكنك الآن إعادة تعيين كلمة المرور.",
                resetToken=reset_token,
            )

    @staticmethod
    def reset_password(
        payload: ResetPasswordRequest,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> Dict[str, str]:
        """Reset password using a verified resetToken."""
        raw_reset_token = payload.get_reset_token() if hasattr(payload, "get_reset_token") else payload.resetToken
        raw_new_password = payload.get_new_password() if hasattr(payload, "get_new_password") else payload.newPassword

        if payload.confirmPassword and raw_new_password != payload.confirmPassword:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="كلمات المرور غير متطابقة",
            )

        try:
            token_data = decode_token(raw_reset_token)
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"رمز إعادة التعيين غير صالح أو منتهي الصلاحية: {str(e)}",
            )

        if token_data.get("type") != "password_reset":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="نوع الرمز غير صالح لإعادة تعيين كلمة المرور",
            )

        token_sub = str(token_data.get("sub", "")).lower()
        if token_sub != payload.identifier.strip().lower():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="المعرف المرفق لا يتطابق مع صاحب رمز إعادة التعيين",
            )

        new_password_hash = hash_password(raw_new_password)
        now_str = format_utc_now()

        with get_db() as conn:
            cur = conn.execute(
                "SELECT * FROM users WHERE LOWER(identifier) = ?",
                (token_sub,),
            )
            user = cur.fetchone()
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="المستخدم غير موجود",
                )

            # Update password and clear any lockouts
            conn.execute(
                """
                UPDATE users
                SET password_hash = ?, failed_login_attempts = 0, locked_until = NULL, updated_at = ?
                WHERE id = ?
                """,
                (new_password_hash, now_str, user["id"]),
            )

            # Revoke all existing sessions for this user
            conn.execute(
                "UPDATE user_sessions SET is_revoked = 1 WHERE user_id = ?",
                (user["id"],),
            )

            log_audit(
                conn,
                action="PASSWORD_RESET",
                entity_type="users",
                entity_id=user["id"],
                user_id=user["id"],
                branch_id=user["branch_id"],
                new_values={"updated_at": now_str},
                ip_address=client_ip,
                user_agent=user_agent,
            )

        return {"message": "تمت إعادة تعيين كلمة المرور بنجاح. يرجى تسجيل الدخول مجدداً."}

    @staticmethod
    def change_password(
        current_user: Dict[str, Any],
        payload: ChangePasswordRequest,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> Dict[str, str]:
        """Change current user's password with old-password verification."""
        curr_pwd = payload.get_current_password() if hasattr(payload, "get_current_password") else payload.currentPassword
        new_pwd = payload.get_new_password() if hasattr(payload, "get_new_password") else payload.newPassword

        if payload.confirmPassword and new_pwd != payload.confirmPassword:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="كلمات المرور الجديدة غير متطابقة",
            )

        if not verify_password(curr_pwd, current_user["password_hash"]):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="كلمة المرور الحالية غير صحيحة",
            )

        new_hash = hash_password(new_pwd)
        now_str = format_utc_now()

        with get_db() as conn:
            conn.execute(
                """
                UPDATE users
                SET password_hash = ?, updated_at = ?
                WHERE id = ?
                """,
                (new_hash, now_str, current_user["id"]),
            )

            if payload.logoutOtherDevices:
                # Revoke all sessions except the currently active one (or revoke all)
                conn.execute(
                    "UPDATE user_sessions SET is_revoked = 1 WHERE user_id = ?",
                    (current_user["id"],),
                )

            log_audit(
                conn,
                action="PASSWORD_CHANGED",
                entity_type="users",
                entity_id=current_user["id"],
                user_id=current_user["id"],
                branch_id=current_user["branch_id"],
                new_values={"logout_other_devices": payload.logoutOtherDevices},
                ip_address=client_ip,
                user_agent=user_agent,
            )

        return {"message": "تم تغيير كلمة المرور بنجاح وتحديث جلسة الأمان"}

    @staticmethod
    def get_accounts(current_user: Dict[str, Any]) -> List[AccountResponse]:
        """List all system accounts for CEO governance."""
        if current_user.get("role") != "ceo":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="هذه العملية تتطلب صلاحيات المدير التنفيذي (CEO)",
            )

        with get_db() as conn:
            cur = conn.execute(
                """
                SELECT u.*, b.name_ar as branch_name
                FROM users u
                LEFT JOIN branches b ON u.branch_id = b.id
                ORDER BY u.created_at DESC
                """
            )
            rows = cur.fetchall()

            accounts = []
            for r in rows:
                role = r["role"]
                accounts.append(
                    AccountResponse(
                        id=r["id"],
                        name=r["full_name_ar"],
                        email=r["identifier"],
                        role=role,
                        roleArabic=ROLE_ARABIC_MAP.get(role, role),
                        branchId=r["branch_id"],
                        branchName=r["branch_name"],
                        isActive=bool(r["is_active"]),
                        failedLoginAttempts=r["failed_login_attempts"] or 0,
                        lockedUntil=r["locked_until"],
                        lastLoginAt=r["last_login_at"],
                        createdAt=r["created_at"],
                    )
                )

            return accounts

    @staticmethod
    def create_account(
        current_user: Dict[str, Any],
        payload: AccountCreateRequest,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> AccountResponse:
        """CEO provision of a new staff account."""
        if current_user.get("role") != "ceo":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="هذه العملية تتطلب صلاحيات المدير التنفيذي (CEO)",
            )

        full_name = payload.get_full_name()
        identifier = payload.get_identifier()
        role = normalize_role(payload.role)
        now_str = format_utc_now()
        user_id = f"usr_{uuid.uuid4().hex[:8]}"
        password_hash = hash_password(payload.password)
        pin_hash = hash_pin(payload.pinCode) if payload.pinCode else None

        with get_db() as conn:
            # Check unique identifier
            cur = conn.execute(
                "SELECT id FROM users WHERE LOWER(identifier) = ?",
                (identifier,),
            )
            if cur.fetchone():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"البريد الإلكتروني أو كود الموظف '{identifier}' مسجل بالفعل",
                )

            # Check branch if supplied
            branch_input = payload.branchId or getattr(payload, "branch", None)
            resolved_branch_id = resolve_branch_id(conn, branch_input)
            branch_name = None
            if resolved_branch_id:
                b_cur = conn.execute(
                    "SELECT name_ar FROM branches WHERE id = ?",
                    (resolved_branch_id,),
                )
                b_row = b_cur.fetchone()
                if b_row:
                    branch_name = b_row["name_ar"]

            conn.execute(
                """
                INSERT INTO users (
                    id, branch_id, identifier, full_name_ar, password_hash, role,
                    pin_code_hash, is_active, failed_login_attempts, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0, ?, ?)
                """,
                (
                    user_id,
                    resolved_branch_id,
                    identifier,
                    full_name,
                    password_hash,
                    role,
                    pin_hash,
                    now_str,
                    now_str,
                ),
            )

            log_audit(
                conn,
                action="ACCOUNT_CREATED",
                entity_type="users",
                entity_id=user_id,
                user_id=current_user["id"],
                branch_id=resolved_branch_id,
                new_values={
                    "identifier": identifier,
                    "name": full_name,
                    "role": role,
                    "branch_id": resolved_branch_id,
                },
                ip_address=client_ip,
                user_agent=user_agent,
            )

            return AccountResponse(
                id=user_id,
                name=full_name,
                email=identifier,
                role=role,
                roleArabic=ROLE_ARABIC_MAP.get(role, role),
                branchId=resolved_branch_id,
                branchName=branch_name,
                isActive=True,
                failedLoginAttempts=0,
                lockedUntil=None,
                lastLoginAt=None,
                createdAt=now_str,
            )

    @staticmethod
    def toggle_account_status(
        current_user: Dict[str, Any],
        account_id: str,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> AccountToggleStatusResponse:
        """Toggle user account between active and disabled states."""
        if current_user.get("role") != "ceo":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="هذه العملية تتطلب صلاحيات المدير التنفيذي (CEO)",
            )

        now_str = format_utc_now()

        with get_db() as conn:
            cur = conn.execute("SELECT * FROM users WHERE id = ?", (account_id,))
            user = cur.fetchone()
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"الحساب رقم '{account_id}' غير موجود",
                )

            # Prevent CEO from self-disabling
            if user["id"] == current_user["id"]:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="لا يمكن للمدير التنفيذي تعطيل حسابه الشخصي الحالي",
                )

            old_status = user["is_active"]
            new_status = 0 if old_status == 1 else 1

            if user["role"] == "ceo" and old_status == 1 and new_status == 0:
                cur_ceo_cnt = conn.execute("SELECT COUNT(*) FROM users WHERE role = 'ceo' AND is_active = 1").fetchone()[0]
                if cur_ceo_cnt <= 1:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="لا يمكن تعطيل آخر مدير تنفيذي نشط في النظام",
                    )

            conn.execute(
                "UPDATE users SET is_active = ?, updated_at = ? WHERE id = ?",
                (new_status, now_str, account_id),
            )

            # If account disabled, revoke all its active sessions immediately
            if new_status == 0:
                conn.execute(
                    "UPDATE user_sessions SET is_revoked = 1 WHERE user_id = ?",
                    (account_id,),
                )

            status_msg = "تم تنشيط الحساب بنجاح" if new_status == 1 else "تم تعطيل الحساب بنجاح"

            log_audit(
                conn,
                action="STATUS_TOGGLED",
                entity_type="users",
                entity_id=account_id,
                user_id=current_user["id"],
                branch_id=user["branch_id"],
                old_values={"is_active": old_status},
                new_values={"is_active": new_status},
                ip_address=client_ip,
                user_agent=user_agent,
            )

            return AccountToggleStatusResponse(
                id=account_id,
                isActive=bool(new_status),
                message=status_msg,
            )

    @staticmethod
    def update_account(
        current_user: Dict[str, Any],
        account_id: str,
        payload: AccountUpdateRequest,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> AccountResponse:
        """CEO update of an existing staff account."""
        if current_user.get("role") != "ceo":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="هذه العملية تتطلب صلاحيات المدير التنفيذي (CEO)",
            )

        now_str = format_utc_now()

        with get_db() as conn:
            cur = conn.execute("SELECT * FROM users WHERE id = ?", (account_id,))
            user = cur.fetchone()
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"الحساب رقم '{account_id}' غير موجود",
                )

            old_values = dict(user)
            old_values.pop("password_hash", None)
            old_values.pop("pin_code_hash", None)

            # 1. Identifier / Email update
            new_identifier = (payload.identifier or payload.email or "").strip().lower()
            if new_identifier and new_identifier != user["identifier"].lower():
                dup_cur = conn.execute(
                    "SELECT id FROM users WHERE LOWER(identifier) = ? AND id != ?",
                    (new_identifier, account_id),
                )
                if dup_cur.fetchone():
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"البريد الإلكتروني أو كود الموظف '{new_identifier}' مسجل بالفعل",
                    )
            else:
                new_identifier = user["identifier"]

            # 2. Full name
            new_name = (payload.fullNameAr or payload.name or "").strip() or user["full_name_ar"]

            # 3. Role
            new_role = normalize_role(payload.role) if payload.role else user["role"]
            if user["role"] == "ceo" and new_role != "ceo" and user["is_active"] == 1:
                cur_ceo_cnt = conn.execute("SELECT COUNT(*) FROM users WHERE role = 'ceo' AND is_active = 1").fetchone()[0]
                if cur_ceo_cnt <= 1:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="لا يمكن تغيير دور آخر مدير تنفيذي نشط في النظام",
                    )

            # 4. Active status
            if payload.isActive is not None:
                new_is_active = 1 if payload.isActive else 0
                if user["id"] == current_user["id"] and new_is_active == 0:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="لا يمكن للمدير التنفيذي تعطيل حسابه الشخصي الحالي",
                    )
                if user["role"] == "ceo" and user["is_active"] == 1 and new_is_active == 0:
                    cur_ceo_cnt = conn.execute("SELECT COUNT(*) FROM users WHERE role = 'ceo' AND is_active = 1").fetchone()[0]
                    if cur_ceo_cnt <= 1:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail="لا يمكن تعطيل آخر مدير تنفيذي نشط في النظام",
                        )
            else:
                new_is_active = user["is_active"]

            # 5. Branch
            branch_input = payload.branchId or getattr(payload, "branch", None)
            if branch_input is not None:
                new_branch_id = resolve_branch_id(conn, branch_input)
            else:
                new_branch_id = user["branch_id"]

            # 6. Password
            new_pwd_hash = user["password_hash"]
            if payload.password and len(payload.password) >= 6:
                new_pwd_hash = hash_password(payload.password)
                conn.execute("UPDATE user_sessions SET is_revoked = 1 WHERE user_id = ?", (account_id,))

            # 7. Pin
            new_pin_hash = hash_pin(payload.pinCode) if payload.pinCode else user["pin_code_hash"]

            # If account is being disabled, revoke all sessions
            if user["is_active"] == 1 and new_is_active == 0:
                conn.execute("UPDATE user_sessions SET is_revoked = 1 WHERE user_id = ?", (account_id,))

            conn.execute(
                """
                UPDATE users
                SET identifier = ?, full_name_ar = ?, role = ?, branch_id = ?,
                    is_active = ?, password_hash = ?, pin_code_hash = ?, updated_at = ?
                WHERE id = ?
                """,
                (
                    new_identifier,
                    new_name,
                    new_role,
                    new_branch_id,
                    new_is_active,
                    new_pwd_hash,
                    new_pin_hash,
                    now_str,
                    account_id,
                ),
            )

            branch_name = None
            if new_branch_id:
                b_cur = conn.execute("SELECT name_ar FROM branches WHERE id = ?", (new_branch_id,))
                b_row = b_cur.fetchone()
                if b_row:
                    branch_name = b_row["name_ar"]

            new_values = {
                "identifier": new_identifier,
                "name": new_name,
                "role": new_role,
                "branch_id": new_branch_id,
                "is_active": new_is_active,
            }

            log_audit(
                conn,
                action="ACCOUNT_UPDATED",
                entity_type="users",
                entity_id=account_id,
                user_id=current_user["id"],
                branch_id=new_branch_id,
                old_values=old_values,
                new_values=new_values,
                ip_address=client_ip,
                user_agent=user_agent,
            )

            return AccountResponse(
                id=account_id,
                name=new_name,
                email=new_identifier,
                role=new_role,
                roleArabic=ROLE_ARABIC_MAP.get(new_role, new_role),
                branchId=new_branch_id,
                branchName=branch_name,
                isActive=bool(new_is_active),
                failedLoginAttempts=user["failed_login_attempts"],
                lockedUntil=user["locked_until"],
                lastLoginAt=user["last_login_at"],
                createdAt=user["created_at"],
            )

    @staticmethod
    def delete_account(
        current_user: Dict[str, Any],
        account_id: str,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> AccountDeleteResponse:
        """CEO safe deletion of a user account."""
        if current_user.get("role") != "ceo":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="هذه العملية تتطلب صلاحيات المدير التنفيذي (CEO)",
            )

        with get_db() as conn:
            cur = conn.execute("SELECT * FROM users WHERE id = ?", (account_id,))
            user = cur.fetchone()
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"الحساب رقم '{account_id}' غير موجود",
                )

            # Prevent CEO from deleting self
            if user["id"] == current_user["id"]:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="لا يمكن للمدير التنفيذي حذف حسابه الشخصي الحالي",
                )

            # Prevent deleting the last active CEO
            if user["role"] == "ceo" and user["is_active"] == 1:
                cur_ceo_cnt = conn.execute("SELECT COUNT(*) FROM users WHERE role = 'ceo' AND is_active = 1").fetchone()[0]
                if cur_ceo_cnt <= 1:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="لا يمكن حذف آخر مدير تنفيذي نشط في النظام",
                    )

            # 1. Revoke all active sessions for this user
            conn.execute("UPDATE user_sessions SET is_revoked = 1 WHERE user_id = ?", (account_id,))

            # 2. Record audit log before deleting record
            old_values = {
                "id": user["id"],
                "identifier": user["identifier"],
                "name": user["full_name_ar"],
                "role": user["role"],
                "branch_id": user["branch_id"],
            }
            log_audit(
                conn,
                action="ACCOUNT_DELETED",
                entity_type="users",
                entity_id=account_id,
                user_id=current_user["id"],
                branch_id=user["branch_id"],
                old_values=old_values,
                ip_address=client_ip,
                user_agent=user_agent,
            )

            # 3. Delete user sessions and user record
            conn.execute("DELETE FROM user_sessions WHERE user_id = ?", (account_id,))
            conn.execute("DELETE FROM users WHERE id = ?", (account_id,))

            return AccountDeleteResponse(
                id=account_id,
                deleted=True,
                message="تم حذف الحساب بنجاح",
            )

