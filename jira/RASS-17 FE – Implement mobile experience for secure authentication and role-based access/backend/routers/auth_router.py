from typing import Optional, Dict, Any, Tuple
import fastapi.routing
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

if hasattr(fastapi.routing, "_IncludedRouter") and not hasattr(fastapi.routing._IncludedRouter, "path"):
    fastapi.routing._IncludedRouter.path = property(
        lambda self: (getattr(self.include_context, "prefix", "") or "") + (getattr(self.original_router, "prefix", "") or "")
    )

from ..schemas.auth_schemas import (
    ApiResponse,
    LoginRequest,
    LogoutRequest,
    ForgotPasswordRequest,
    VerifyOtpRequest,
    ResetPasswordRequest,
    ChangePasswordRequest,
    AccountCreateRequest,
    AccountUpdateRequest,
    AccountDeleteResponse,
)
from ..services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Auth & RBAC"])
security_scheme = HTTPBearer(auto_error=False)


def get_client_info(request: Request) -> Tuple[Optional[str], Optional[str]]:
    """Extract client IP and user agent headers."""
    client_ip = request.client.host if request.client else None
    if "x-forwarded-for" in request.headers:
        client_ip = request.headers["x-forwarded-for"].split(",")[0].strip()
    user_agent = request.headers.get("user-agent")
    return client_ip, user_agent


def get_current_user(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme),
) -> Dict[str, Any]:
    """Dependency that extracts and validates Bearer token from header."""
    token = None
    if credentials:
        token = credentials.credentials
    elif "authorization" in request.headers:
        auth_header = request.headers["authorization"]
        if auth_header.lower().startswith("bearer "):
            token = auth_header[7:].strip()
    elif "x-auth-token" in request.headers:
        token = request.headers["x-auth-token"].strip()

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="رمز المصادقة مطلوب (Bearer token required)",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return AuthService.get_current_user_from_token(token)


def get_current_ceo(
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    """Dependency that ensures caller has CEO role."""
    if current_user.get("role") != "ceo":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="هذه العملية تتطلب صلاحيات المدير التنفيذي (CEO)",
        )
    return current_user


@router.post("/login", response_model=ApiResponse)
def login(request: Request, payload: LoginRequest):
    """
    Authenticate user via identifier (email / employee code) and password.
    Returns JWT token, refresh token, role, and branch details.
    Enforces maximum 5 failed attempts before a 15-minute lockout.
    """
    client_ip, user_agent = get_client_info(request)
    login_data = AuthService.login(payload, client_ip=client_ip, user_agent=user_agent)
    return ApiResponse(
        success=True,
        data=login_data.model_dump(),
    )


@router.post("/logout", response_model=ApiResponse)
def logout(
    request: Request,
    payload: Optional[LogoutRequest] = None,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme),
):
    """
    Revoke active session token in SQLite and record logout audit log.
    """
    client_ip, user_agent = get_client_info(request)
    token = None
    if credentials:
        token = credentials.credentials
    elif payload and payload.token:
        token = payload.token
    elif "authorization" in request.headers:
        auth_header = request.headers["authorization"]
        if auth_header.lower().startswith("bearer "):
            token = auth_header[7:].strip()

    result = AuthService.logout(token=token, client_ip=client_ip, user_agent=user_agent)
    return ApiResponse(success=True, data=result)


@router.get("/me", response_model=ApiResponse)
def get_me(current_user: Dict[str, Any] = Depends(get_current_user)):
    """
    Fetch the currently authenticated user's session profile and branch.
    """
    user_res = AuthService.get_me(current_user)
    return ApiResponse(success=True, data=user_res.model_dump())


@router.post("/forgot-password", response_model=ApiResponse)
def forgot_password(request: Request, payload: ForgotPasswordRequest):
    """
    Initiate password reset flow.
    Enforces indistinguishable generic response to prevent account enumeration (AUTH007).
    """
    client_ip, user_agent = get_client_info(request)
    res = AuthService.forgot_password(payload, client_ip=client_ip, user_agent=user_agent)
    return ApiResponse(success=True, data=res.model_dump())


@router.post("/verify-otp", response_model=ApiResponse)
def verify_otp(request: Request, payload: VerifyOtpRequest):
    """
    Verify the 6-digit OTP code.
    If valid, returns a scoped resetToken valid for 15 minutes.
    """
    client_ip, user_agent = get_client_info(request)
    res = AuthService.verify_otp(payload, client_ip=client_ip, user_agent=user_agent)
    return ApiResponse(success=True, data=res.model_dump())


@router.post("/reset-password", response_model=ApiResponse)
def reset_password(request: Request, payload: ResetPasswordRequest):
    """
    Reset account password using verified resetToken.
    Updates SQLite users table, revokes existing sessions, and writes audit log.
    """
    client_ip, user_agent = get_client_info(request)
    res = AuthService.reset_password(payload, client_ip=client_ip, user_agent=user_agent)
    return ApiResponse(success=True, data=res)


@router.post("/change-password", response_model=ApiResponse)
def change_password(
    request: Request,
    payload: ChangePasswordRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    Change current authenticated user's password.
    Requires current password verification and optionally revokes other active sessions.
    """
    client_ip, user_agent = get_client_info(request)
    res = AuthService.change_password(
        current_user,
        payload,
        client_ip=client_ip,
        user_agent=user_agent,
    )
    return ApiResponse(success=True, data=res)


@router.get("/accounts", response_model=ApiResponse)
def get_accounts(current_user: Dict[str, Any] = Depends(get_current_ceo)):
    """
    CEO-only endpoint to list all user accounts with branch names and activity status.
    """
    accounts = AuthService.get_accounts(current_user)
    return ApiResponse(
        success=True,
        data=[a.model_dump() for a in accounts],
        meta={"totalRecords": len(accounts)},
    )


@router.post("/accounts", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def create_account(
    request: Request,
    payload: AccountCreateRequest,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    """
    CEO-only endpoint to provision a new user account.
    """
    client_ip, user_agent = get_client_info(request)
    new_account = AuthService.create_account(
        current_user,
        payload,
        client_ip=client_ip,
        user_agent=user_agent,
    )
    return ApiResponse(success=True, data=new_account.model_dump())


@router.patch("/accounts/{account_id}/toggle-status", response_model=ApiResponse)
def toggle_account_status(
    request: Request,
    account_id: str,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    """
    CEO-only endpoint to activate or disable a user account.
    Revokes sessions if disabled, updates SQLite users table, and records audit log.
    """
    client_ip, user_agent = get_client_info(request)
    result = AuthService.toggle_account_status(
        current_user,
        account_id,
        client_ip=client_ip,
        user_agent=user_agent,
    )
    return ApiResponse(success=True, data=result.model_dump())


@router.put("/accounts/{account_id}", response_model=ApiResponse)
def update_account(
    request: Request,
    account_id: str,
    payload: AccountUpdateRequest,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    """
    CEO-only endpoint to update an existing user account.
    Validates branches and roles, hashes new password if provided, and records audit log.
    """
    client_ip, user_agent = get_client_info(request)
    updated = AuthService.update_account(
        current_user,
        account_id,
        payload,
        client_ip=client_ip,
        user_agent=user_agent,
    )
    return ApiResponse(success=True, data=updated.model_dump())


@router.delete("/accounts/{account_id}", response_model=ApiResponse)
def delete_account(
    request: Request,
    account_id: str,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    """
    CEO-only endpoint to safely delete a user account.
    Guards against self-deletion and deleting the last active CEO. Revokes sessions.
    """
    client_ip, user_agent = get_client_info(request)
    result = AuthService.delete_account(
        current_user,
        account_id,
        client_ip=client_ip,
        user_agent=user_agent,
    )
    return ApiResponse(success=True, data=result.model_dump())


# --- Flutter Client Route Compatibility Aliases (/auth/users) ---

@router.get("/users", response_model=ApiResponse)
def get_users_alias(current_user: Dict[str, Any] = Depends(get_current_ceo)):
    """Flutter client alias for listing accounts."""
    return get_accounts(current_user)


@router.post("/users", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def create_user_alias(
    request: Request,
    payload: AccountCreateRequest,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    """Flutter client alias for provisioning account."""
    return create_account(request, payload, current_user)


@router.put("/users/{account_id}", response_model=ApiResponse)
def update_user_alias(
    request: Request,
    account_id: str,
    payload: AccountUpdateRequest,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    """Flutter client alias for updating account."""
    return update_account(request, account_id, payload, current_user)


@router.delete("/users/{account_id}", response_model=ApiResponse)
def delete_user_alias(
    request: Request,
    account_id: str,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    """Flutter client alias for deleting account."""
    return delete_account(request, account_id, current_user)


@router.put("/users/{account_id}/status", response_model=ApiResponse)
def update_user_status_alias(
    request: Request,
    account_id: str,
    payload: Optional[Dict[str, Any]] = None,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    """Flutter client alias for updating account status."""
    client_ip, user_agent = get_client_info(request)
    if payload and ("is_active" in payload or "isActive" in payload):
        target_active = payload.get("is_active", payload.get("isActive"))
        # Use update_account to apply explicit boolean
        updated = AuthService.update_account(
            current_user,
            account_id,
            AccountUpdateRequest(isActive=bool(target_active)),
            client_ip=client_ip,
            user_agent=user_agent,
        )
        return ApiResponse(
            success=True,
            data={"id": account_id, "isActive": updated.isActive, "message": "تم تحديث حالة الحساب بنجاح"},
        )
    return toggle_account_status(request, account_id, current_user)


@router.patch("/users/{account_id}/toggle-status", response_model=ApiResponse)
def toggle_user_status_alias(
    request: Request,
    account_id: str,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    """Flutter client alias for toggling account status."""
    return toggle_account_status(request, account_id, current_user)

