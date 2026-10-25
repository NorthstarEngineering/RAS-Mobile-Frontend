import math
from typing import List, Optional, Any
from fastapi import HTTPException
from pydantic import BaseModel, Field, ConfigDict, field_validator, model_validator

ATTENDANCE_NUMERIC_FIELDS = [
    "late_minutes", "lateMinutes",
    "deduction_amount", "deductionAmount",
    "waived_minutes", "waivedMinutes",
    "original_late_minutes", "originalLateMinutes",
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
    message: Optional[str] = None
    errors: Optional[List[str]] = None

class AttendanceAdjustmentResponse(BaseModel):
    id: str
    attendanceId: str
    adjustedByUserId: str
    originalLateMinutes: int
    waivedMinutes: int
    deductionAmount: float
    reason: str
    createdAt: str

class AttendanceRecordResponse(BaseModel):
    id: str
    employeeId: str
    employeeName: str
    employeeCode: str
    role: str
    branchId: str
    branchName: Optional[str] = ""
    date: str
    checkInTime: Optional[str] = None
    checkOutTime: Optional[str] = None
    status: str  # 'present', 'late', 'absent'
    delayMinutes: int = 0
    lateMinutes: int = 0
    deductionAmount: float = 0.0
    isDeductionAdjusted: bool = False
    shiftName: str = "الوردية الصباحية"
    adjustmentId: Optional[str] = None
    adjustmentReason: Optional[str] = None
    waivedMinutes: Optional[int] = 0
    createdAt: Optional[str] = None
    updatedAt: Optional[str] = None

class CheckInRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    employee_id: str = Field(..., alias="employeeId")
    branch_id: str = Field(..., alias="branchId")
    date: Optional[str] = None
    check_in_time: Optional[str] = Field(None, alias="checkInTime")
    shift_name: Optional[str] = Field("الوردية الصباحية", alias="shiftName")
    late_minutes: Optional[int] = Field(0, ge=0, allow_inf_nan=False, alias="lateMinutes")

    @model_validator(mode="before")
    @classmethod
    def validate_finite_inputs(cls, data: Any) -> Any:
        return _check_finite_dict(data, ATTENDANCE_NUMERIC_FIELDS)

    @field_validator("late_minutes")
    @classmethod
    def validate_late_minutes(cls, v: Optional[int]) -> Optional[int]:
        if v is not None:
            if isinstance(v, float) and not math.isfinite(v):
                raise ValueError("دقائق التأخير يجب أن تكون رقماً صحيحاً محدوداً")
            if v < 0:
                raise ValueError("دقائق التأخير يجب أن تكون غير سالبة")
        return v

class CheckOutRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    attendance_id: Optional[str] = Field(None, alias="attendanceId")
    employee_id: Optional[str] = Field(None, alias="employeeId")
    date: Optional[str] = None
    check_out_time: Optional[str] = Field(None, alias="checkOutTime")

class AdjustDeductionRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    attendance_id: str = Field(..., alias="attendanceId")
    adjusted_by_user_id: Optional[str] = Field("usr_bm1", alias="adjustedByUserId")
    waived_minutes: Optional[int] = Field(0, ge=0, allow_inf_nan=False, alias="waivedMinutes")
    deduction_amount: float = Field(..., ge=0.0, allow_inf_nan=False, alias="deductionAmount")
    reason: str
    original_late_minutes: Optional[int] = Field(None, ge=0, allow_inf_nan=False, alias="originalLateMinutes")

    @model_validator(mode="before")
    @classmethod
    def validate_finite_inputs(cls, data: Any) -> Any:
        return _check_finite_dict(data, ATTENDANCE_NUMERIC_FIELDS)

    @field_validator("deduction_amount")
    @classmethod
    def validate_deduction_amount(cls, v: float) -> float:
        if not math.isfinite(v) or v < 0:
            raise ValueError("مبلغ الخصم يجب أن يكون رقماً حقيقياً غير سالب ومحدوداً (>= 0)")
        return v

    @field_validator("waived_minutes", "original_late_minutes")
    @classmethod
    def validate_minutes(cls, v: Optional[int]) -> Optional[int]:
        if v is not None:
            if isinstance(v, float) and not math.isfinite(v):
                raise ValueError("الدقائق يجب أن تكون رقماً صحيحاً محدوداً")
            if v < 0:
                raise ValueError("الدقائق يجب أن تكون غير سالبة")
        return v

class EmployeeAttendanceHistoryResponse(BaseModel):
    employeeId: str
    employeeName: str
    employeeCode: str
    jobTitle: str
    records: List[AttendanceRecordResponse] = Field(default_factory=list)
    totalDays: int = 0
    presentDays: int = 0
    lateDays: int = 0
    absentDays: int = 0
    totalLateMinutes: int = 0
    totalDeductions: float = 0.0
    totalWaivedMinutes: int = 0
