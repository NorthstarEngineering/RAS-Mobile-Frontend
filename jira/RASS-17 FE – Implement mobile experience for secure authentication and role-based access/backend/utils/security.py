import os
import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional, Dict, Any
import jwt

# Path to persisted local dev secret file in project-owned outputs
DEV_SECRET_FILE = Path(__file__).resolve().parent.parent.parent / "qa_recovery" / "closeout" / "auth_security" / ".jwt_dev_secret"


def get_jwt_secret() -> str:
    """
    Resolve JWT secret key with strict fail-closed security:
    1. Primary: RMS_JWT_SECRET environment variable (explicit deployment secret, >= 32 chars).
    2. Explicit file: RMS_JWT_SECRET_FILE environment variable.
    3. Safe local dev fallback: Persisted local dev secret file in isolated project-owned outputs
       (never hardcoded in code, survives server restarts, avoids silently breaking user sessions).
    4. If none provided: Fails closed with clear descriptive error.
    """
    # 1. Environment variable
    env_secret = os.environ.get("RMS_JWT_SECRET")
    if env_secret:
        s = env_secret.strip()
        if len(s) >= 32:
            return s
        raise ValueError("RMS_JWT_SECRET must be at least 32 characters for 256-bit security.")

    # 2. File from environment variable
    env_file = os.environ.get("RMS_JWT_SECRET_FILE")
    if env_file:
        f_path = Path(env_file).resolve()
        if f_path.is_file():
            content = f_path.read_text(encoding="utf-8").strip()
            if len(content) >= 32:
                return content
            raise ValueError(f"Secret in RMS_JWT_SECRET_FILE ({env_file}) must be at least 32 characters.")
        raise FileNotFoundError(f"RMS_JWT_SECRET_FILE specified but not found: {env_file}")

    # 3. Persisted local dev secret file in project-owned outputs
    if DEV_SECRET_FILE.is_file():
        dev_content = DEV_SECRET_FILE.read_text(encoding="utf-8").strip()
        if len(dev_content) >= 32:
            return dev_content

    # 4. Fail closed
    raise RuntimeError(
        "مفتاح توقيع الجلسات RMS_JWT_SECRET غير مهيأ (Fail-closed). "
        "يرجى ضبط متغير البيئة RMS_JWT_SECRET (بحد أدنى 32 حرفاً) أو توفير ملف المفتاح عبر RMS_JWT_SECRET_FILE."
    )


def ensure_local_dev_secret() -> str:
    """
    Safe local dev helper: persists a cryptographically strong 256-bit secret to DEV_SECRET_FILE
    if not already present, avoiding code-hardcoding and ensuring restart persistence.
    """
    if DEV_SECRET_FILE.is_file():
        content = DEV_SECRET_FILE.read_text(encoding="utf-8").strip()
        if len(dev_content := content) >= 32:
            return dev_content
    DEV_SECRET_FILE.parent.mkdir(parents=True, exist_ok=True)
    new_secret = secrets.token_urlsafe(48)
    DEV_SECRET_FILE.write_text(new_secret, encoding="utf-8")
    return new_secret


JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.environ.get("RMS_ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))  # 24 hours
REFRESH_TOKEN_EXPIRE_DAYS = int(os.environ.get("RMS_REFRESH_TOKEN_EXPIRE_DAYS", "7"))
RESET_TOKEN_EXPIRE_MINUTES = 15
PBKDF2_ITERATIONS = 100_000


def __getattr__(name: str):
    if name == "JWT_SECRET":
        return get_jwt_secret()
    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")


def is_placeholder_hash(stored_hash: Optional[str]) -> bool:
    """Check if a stored password hash is an unactivated placeholder marker."""
    if not stored_hash:
        return True
    s = stored_hash.strip().lower()
    return (
        s == "sha256_placeholder_hash"
        or "placeholder" in s
        or s == "disabled"
        or s == "unactivated"
    )


def hash_password(password: str) -> str:
    """Hash a password using PBKDF2-HMAC-SHA256 with 100,000 iterations and a random salt."""
    salt = secrets.token_bytes(16)
    key = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        PBKDF2_ITERATIONS
    )
    return f"pbkdf2_sha256${PBKDF2_ITERATIONS}${salt.hex()}${key.hex()}"


def verify_password(plain_password: str, stored_hash: str) -> bool:
    """
    Verify a plain password against a stored hash using constant-time comparison.
    Supports PBKDF2-HMAC-SHA256 and legacy SHA-256 hex.
    Strictly rejects placeholder hashes, universal shared secrets, and bypass fallbacks.
    """
    if not stored_hash or not plain_password:
        return False

    if is_placeholder_hash(stored_hash):
        return False

    # 1. PBKDF2-HMAC-SHA256 standard production format
    if stored_hash.startswith("pbkdf2_sha256$"):
        parts = stored_hash.split("$")
        if len(parts) == 4:
            try:
                iterations = int(parts[1])
                salt = bytes.fromhex(parts[2])
                expected_hash = parts[3]
                computed_key = hashlib.pbkdf2_hmac(
                    "sha256",
                    plain_password.encode("utf-8"),
                    salt,
                    iterations
                ).hex()
                return secrets.compare_digest(computed_key, expected_hash)
            except Exception:
                return False

    # 2. Standard SHA-256 hex digest (legacy format)
    if len(stored_hash) == 64 and all(c in "0123456789abcdefABCDEF" for c in stored_hash):
        try:
            sha256_digest = hashlib.sha256(plain_password.encode("utf-8")).hexdigest()
            return secrets.compare_digest(sha256_digest, stored_hash)
        except Exception:
            pass

    return False


def hash_pin(pin: str) -> str:
    """Hash a 4-to-6 digit cashier PIN."""
    salt = secrets.token_bytes(8)
    key = hashlib.pbkdf2_hmac("sha256", pin.encode("utf-8"), salt, 50_000)
    return f"pbkdf2_pin$50000${salt.hex()}${key.hex()}"


def verify_pin(plain_pin: str, stored_hash: str) -> bool:
    """Verify a cashier PIN."""
    if not stored_hash or not plain_pin:
        return False
    if stored_hash.startswith("pbkdf2_pin$"):
        parts = stored_hash.split("$")
        if len(parts) == 4:
            try:
                iterations = int(parts[1])
                salt = bytes.fromhex(parts[2])
                expected_hash = parts[3]
                computed = hashlib.pbkdf2_hmac("sha256", plain_pin.encode("utf-8"), salt, iterations).hex()
                return secrets.compare_digest(computed, expected_hash)
            except Exception:
                return False
    return secrets.compare_digest(plain_pin, stored_hash)


def create_access_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    """Create a signed JWT access token with unique jti."""
    to_encode = data.copy()
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({
        "exp": expire,
        "iat": now,
        "type": "access",
        "jti": secrets.token_hex(16),
    })
    return jwt.encode(to_encode, get_jwt_secret(), algorithm=JWT_ALGORITHM)


def create_refresh_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    """Create a signed JWT refresh token with unique jti."""
    to_encode = data.copy()
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({
        "exp": expire,
        "iat": now,
        "type": "refresh",
        "jti": secrets.token_hex(16),
    })
    return jwt.encode(to_encode, get_jwt_secret(), algorithm=JWT_ALGORITHM)


def create_reset_token(identifier: str, expires_delta: Optional[timedelta] = None) -> str:
    """Create a temporary password-reset token (valid 15 minutes)."""
    now = datetime.now(timezone.utc)
    expire = now + (expires_delta or timedelta(minutes=RESET_TOKEN_EXPIRE_MINUTES))
    payload = {
        "sub": identifier,
        "type": "password_reset",
        "exp": expire,
        "iat": now,
        "jti": secrets.token_hex(8),
    }
    return jwt.encode(payload, get_jwt_secret(), algorithm=JWT_ALGORITHM)


def decode_token(token: str) -> Dict[str, Any]:
    """Decode and validate a JWT token."""
    try:
        payload = jwt.decode(token, get_jwt_secret(), algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise ValueError("انتهت صلاحية الرمز (Token expired)")
    except jwt.InvalidTokenError:
        raise ValueError("رمز غير صالح (Invalid token)")


def generate_otp(length: int = 6) -> str:
    """Generate a cryptographically secure random numeric OTP string."""
    digits = "0123456789"
    return "".join(secrets.choice(digits) for _ in range(length))


def hash_otp(otp: str) -> str:
    """Hash an OTP code using SHA-256 for secure DB storage."""
    return hashlib.sha256(otp.strip().encode("utf-8")).hexdigest()


def verify_otp_code(plain_otp: str, stored_hash: str) -> bool:
    """Verify an entered OTP code against its SHA-256 hash in constant time."""
    if not plain_otp or not stored_hash:
        return False
    computed = hashlib.sha256(plain_otp.strip().encode("utf-8")).hexdigest()
    return secrets.compare_digest(computed, stored_hash)
