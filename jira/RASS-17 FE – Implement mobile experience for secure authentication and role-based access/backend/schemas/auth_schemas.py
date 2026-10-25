from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class ApiResponse(BaseModel):
    """Standard RMS Unified API envelope."""
    success: bool = True
    data: Optional[Any] = None
    error: Optional[Any] = None
    meta: Optional[Dict[str, Any]] = None


class LoginRequest(BaseModel):
    """Payload for user login."""
    identifier: str = Field(..., description="البريد الإلكتروني أو كود الموظف")
    password: str = Field(..., min_length=4, description="كلمة المرور")
    pinCode: Optional[str] = Field(None, description="رمز الـ PIN لأمين الصندوق")


class UserResponse(BaseModel):
    """User profile and identity details."""
    id: str
    name: str
    email: str
    role: str
    roleArabic: str
    branchId: Optional[str] = None
    branchName: Optional[str] = None
    isActive: bool = True


class LoginData(BaseModel):
    """Data object returned upon successful authentication."""
    token: str
    refreshToken: str
    tokenType: str = "Bearer"
    expiresIn: int
    user: UserResponse


class LogoutRequest(BaseModel):
    """Payload for explicit session revocation."""
    token: Optional[str] = None
    refreshToken: Optional[str] = None


class ForgotPasswordRequest(BaseModel):
    """Payload to request an OTP code for password reset."""
    identifier: str = Field(..., description="البريد الإلكتروني أو كود الموظف")
    method: Optional[str] = Field("sms", description="قناة الإرسال: sms أو email")


class ForgotPasswordData(BaseModel):
    """Response returned after requesting an OTP."""
    message: str
    otpId: Optional[str] = None
    identifier: str
    expiresInMinutes: int = 10
    deliveryStatus: Optional[str] = "BLOCKED_EXTERNAL_DELIVERY"
    devOtpCode: Optional[str] = None


class VerifyOtpRequest(BaseModel):
    """Payload to verify an OTP code."""
    identifier: str
    otpCode: Optional[str] = None
    otp: Optional[str] = None
    otp_code: Optional[str] = None
    otpId: Optional[str] = None

    def get_code(self) -> str:
        code = self.otpCode or self.otp or self.otp_code or ""
        if not code.strip():
            raise ValueError("رمز التحقق OTP مطلوب")
        return code.strip()


class VerifyOtpData(BaseModel):
    """Response returned upon successful OTP verification."""
    verified: bool = True
    message: str
    resetToken: str


class ResetPasswordRequest(BaseModel):
    """Payload to reset a forgotten password using a verified resetToken."""
    identifier: str
    resetToken: Optional[str] = None
    reset_token: Optional[str] = None
    newPassword: Optional[str] = None
    new_password: Optional[str] = None
    confirmPassword: Optional[str] = None

    def get_reset_token(self) -> str:
        tok = self.resetToken or self.reset_token or ""
        if not tok.strip():
            raise ValueError("رمز إعادة التعيين (resetToken) مطلوب")
        return tok.strip()

    def get_new_password(self) -> str:
        pwd = self.newPassword or self.new_password or ""
        if len(pwd.strip()) < 6:
            raise ValueError("كلمة المرور الجديدة يجب أن لا تقل عن 6 أحرف")
        return pwd.strip()


class ChangePasswordRequest(BaseModel):
    """Payload for an authenticated user to change their own password."""
    currentPassword: Optional[str] = None
    current_password: Optional[str] = None
    old_password: Optional[str] = None
    newPassword: Optional[str] = None
    new_password: Optional[str] = None
    confirmPassword: Optional[str] = None
    logoutOtherDevices: Optional[bool] = True

    def get_current_password(self) -> str:
        pwd = self.currentPassword or self.current_password or self.old_password or ""
        if not pwd:
            raise ValueError("كلمة المرور الحالية مطلوبة")
        return pwd

    def get_new_password(self) -> str:
        pwd = self.newPassword or self.new_password or ""
        if len(pwd) < 6:
            raise ValueError("كلمة المرور الجديدة يجب أن لا تقل عن 6 أحرف")
        return pwd


class AccountCreateRequest(BaseModel):
    """Payload for CEO to provision a new user account."""
    name: Optional[str] = None
    fullNameAr: Optional[str] = None
    identifier: Optional[str] = None
    email: Optional[str] = None
    password: str = Field(..., min_length=6)
    role: str = Field("branch_manager", description="ceo, branch_manager, shift_lead, cashier أو المسمى العربي")
    branchId: Optional[str] = None
    branch: Optional[str] = None
    phone: Optional[str] = None
    pinCode: Optional[str] = None

    def get_full_name(self) -> str:
        name = self.fullNameAr or self.name or ""
        if not name.strip():
            raise ValueError("اسم المستخدم باللغة العربية مطلوب")
        return name.strip()

    def get_identifier(self) -> str:
        ident = self.identifier or self.email or ""
        if not ident.strip():
            raise ValueError("معرّف الحساب أو البريد الإلكتروني مطلوب")
        return ident.strip().lower()


class AccountResponse(BaseModel):
    """Account representation for CEO management table."""
    id: str
    name: str
    email: str
    role: str
    roleArabic: str
    branchId: Optional[str] = None
    branchName: Optional[str] = None
    isActive: bool
    failedLoginAttempts: int = 0
    lockedUntil: Optional[str] = None
    lastLoginAt: Optional[str] = None
    createdAt: str


class AccountToggleStatusResponse(BaseModel):
    """Result of toggling user account status."""
    id: str
    isActive: bool
    message: str


class AccountUpdateRequest(BaseModel):
    """Payload for CEO to update an existing user account."""
    name: Optional[str] = None
    fullNameAr: Optional[str] = None
    identifier: Optional[str] = None
    email: Optional[str] = None
    role: Optional[str] = None
    branchId: Optional[str] = None
    branch: Optional[str] = None
    password: Optional[str] = Field(None, min_length=6)
    phone: Optional[str] = None
    pinCode: Optional[str] = None
    isActive: Optional[bool] = None


class AccountDeleteResponse(BaseModel):
    """Result of deleting a user account."""
    id: str
    deleted: bool = True
    message: str = "تم حذف الحساب بنجاح"

