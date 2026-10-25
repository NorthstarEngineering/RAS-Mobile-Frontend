import math
from typing import Any, Dict, List, Optional
from fastapi import HTTPException
from pydantic import BaseModel, Field, ConfigDict, field_validator, model_validator

OVERTIME_NUMERIC_FIELDS = [
    "hours",
    "rate_multiplier", "rateMultiplier",
    "hourly_rate", "hourlyRate",
    "calculated_amount", "calculatedAmount",
]

def _check_finite_dict(data: Any, numeric_fields: List[str]) -> Any:
    if isinstance(data, dict):
        for k in numeric_fields:
            if k in data and data[k] is not None:
                v = data[k]
                if isinstance(v, (int, float)) and not math.isfinite(v):
                    raise HTTPException(
                        status_code=422,
                        detail=f"الحقل '{k}' يجب أن يكون رقماً حقيقياً محدداً (finite number)",
                    )
                if isinstance(v, str):
                    try:
                        fv = float(v)
                        if not math.isfinite(fv):
                            raise HTTPException(
                                status_code=422,
                                detail=f"الحقل '{k}' يجب أن يكون رقماً حقيقياً محدداً (finite number)",
                            )
                    except ValueError:
                        pass
    return data


class ApiResponse(BaseModel):
    success: bool = True
    data: Optional[Any] = None
    error: Optional[Any] = None
    message: Optional[str] = None
    meta: Optional[Dict[str, Any]] = None


class OvertimeRecordCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: Optional[str] = None
    employee_id: Optional[str] = Field(default=None, alias='employeeId')
    branch_id: Optional[str] = Field(default=None, alias='branchId')
    date: Optional[str] = None
    hours: float = Field(..., gt=0, le=24, allow_inf_nan=False, description="ساعات العمل الإضافي يجب أن تكون قيمة موجبة بين 0 و 24")
    rate_multiplier: Optional[float] = Field(default=1.5, ge=1.0, le=5.0, allow_inf_nan=False, alias='rateMultiplier', description="معامل الأجر الإضافي بين 1.0 و 5.0")
    hourly_rate: Optional[float] = Field(default=None, gt=0, allow_inf_nan=False, alias='hourlyRate', description="أجر الساعة الأساسي يجب أن يكون قيمة موجبة")
    calculated_amount: Optional[float] = Field(default=None, ge=0.0, allow_inf_nan=False, alias='calculatedAmount')
    reason: str = Field(..., min_length=1)
    time_range: Optional[str] = Field(default=None, alias='timeRange')
    trigger: Optional[str] = "managerRequest"
    status: Optional[str] = "pending_review"

    @model_validator(mode="before")
    @classmethod
    def validate_finite_inputs(cls, data: Any) -> Any:
        return _check_finite_dict(data, OVERTIME_NUMERIC_FIELDS)

    @field_validator("hours")
    @classmethod
    def validate_hours(cls, v: float) -> float:
        if not math.isfinite(v) or v <= 0 or v > 24:
            raise ValueError("ساعات العمل الإضافي يجب أن تكون رقماً حقيقياً موجباً بين 0 و 24")
        return v

    @field_validator("rate_multiplier")
    @classmethod
    def validate_multiplier(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v < 1.0 or v > 5.0:
                raise ValueError("معامل الأجر الإضافي يجب أن يكون رقماً حقيقياً بين 1.0 و 5.0")
        return v

    @field_validator("hourly_rate")
    @classmethod
    def validate_hourly_rate(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v <= 0:
                raise ValueError("أجر الساعة يجب أن يكون رقماً حقيقياً موجباً (> 0)")
        return v

    @field_validator("calculated_amount")
    @classmethod
    def validate_calc_amount(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v < 0:
                raise ValueError("المبلغ المحسوب يجب أن يكون رقماً حقيقياً غير سالب (>= 0)")
        return v

    def resolved_employee_id(self) -> str:
        return self.employee_id or ""

    def resolved_branch_id(self) -> str:
        return self.branch_id or "br_01"

    def resolved_multiplier(self) -> float:
        return self.rate_multiplier if self.rate_multiplier is not None else 1.5


class OvertimeRecordReview(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    reviewer_id: Optional[str] = Field(default=None, alias='reviewerId')
    user_id: Optional[str] = Field(default=None, alias='userId')
    notes: Optional[str] = Field(default=None, alias='decisionReason')
    hours: Optional[float] = Field(default=None, gt=0, le=24, allow_inf_nan=False, description="ساعات العمل الإضافي المعدلة")
    rate_multiplier: Optional[float] = Field(default=None, ge=1.0, le=5.0, allow_inf_nan=False, alias='rateMultiplier', description="معامل الأجر الإضافي المعدل")
    status: Optional[str] = None

    @model_validator(mode="before")
    @classmethod
    def validate_finite_inputs(cls, data: Any) -> Any:
        return _check_finite_dict(data, OVERTIME_NUMERIC_FIELDS)

    @field_validator("hours")
    @classmethod
    def validate_review_hours(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v <= 0 or v > 24:
                raise ValueError("ساعات العمل الإضافي المعدلة يجب أن تكون رقماً حقيقياً موجباً بين 0 و 24")
        return v

    @field_validator("rate_multiplier")
    @classmethod
    def validate_review_multiplier(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v < 1.0 or v > 5.0:
                raise ValueError("معامل الأجر الإضافي المعدل يجب أن يكون رقماً حقيقياً بين 1.0 و 5.0")
        return v

    def resolved_reviewer_id(self) -> str:
        return self.reviewer_id or self.user_id or "usr_bm1"

    def resolved_notes(self) -> Optional[str]:
        return self.notes


class OvertimeRecordApprove(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: Optional[str] = None
    is_approved: Optional[bool] = Field(default=None, alias='isApproved')
    approved: Optional[bool] = None
    approved_by_user_id: Optional[str] = Field(default=None, alias='approvedByUserId')
    user_id: Optional[str] = Field(default=None, alias='userId')
    decision_reason: Optional[str] = Field(default=None, alias='decisionReason')
    reason: Optional[str] = None
    notes: Optional[str] = None

    def resolve_is_approved(self) -> bool:
        if self.is_approved is not None:
            return self.is_approved
        if self.approved is not None:
            return self.approved
        if self.status:
            return self.status.lower() in ("approved", "accepted", "معتمد")
        # Default is approve if endpoint is hit without explicit flag
        return True

    def resolve_approver_id(self) -> str:
        return self.approved_by_user_id or self.user_id or "usr_ceo"

    def resolve_reason(self) -> str:
        return (
            self.decision_reason
            or self.reason
            or self.notes
            or ("معتمد للصرف مع راتب الشهر" if self.resolve_is_approved() else "تم رفض طلب الساعات الإضافية")
        )


class FinancialImpactSummary(BaseModel):
    payHistoryId: str
    employeeId: str
    periodMonth: int
    periodYear: int
    baseSalary: float
    previousOvertimeAmount: float
    addedOvertimeAmount: float
    newOvertimeAmount: float
    newNetPayout: float
    status: str


class OvertimeRecordResponse(BaseModel):
    id: str
    employeeId: str
    employeeName: str
    employeeCode: str
    role: str
    branchId: str
    branchName: str
    date: str
    hours: float
    rateMultiplier: float
    calculatedAmount: float
    overtimePay: float
    timeRange: str
    reason: str
    trigger: str
    status: str
    approvedByUserId: Optional[str] = None
    approvedByName: Optional[str] = None
    decisionReason: Optional[str] = None
    createdAt: str
