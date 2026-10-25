import math
from typing import List, Optional, Any
from fastapi import HTTPException
from pydantic import BaseModel, Field, field_validator, model_validator

EMPLOYEE_NUMERIC_FIELDS = [
    "baseSalary", "base_salary",
    "hourlyRate", "hourly_rate",
    "overtimeRate", "overtime_rate",
    "housingAllowance", "housing_allowance",
    "transportAllowance", "transport_allowance",
    "insuranceDeduction", "insurance_deduction",
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
    meta: Optional[dict] = None

class EmployeeCreate(BaseModel):
    id: Optional[str] = None
    code: Optional[str] = None
    branchId: Optional[str] = "br_01"
    firstNameAr: Optional[str] = None
    lastNameAr: Optional[str] = None
    name: Optional[str] = None
    jobTitle: Optional[str] = None
    role: Optional[str] = None
    phone: str
    nationalId: Optional[str] = None
    wageType: Optional[str] = "monthly"
    baseSalary: Optional[float] = Field(default=0.0, ge=0.0, allow_inf_nan=False)
    hourlyRate: Optional[float] = Field(default=0.0, ge=0.0, allow_inf_nan=False)
    overtimeRate: Optional[float] = Field(default=35.0, ge=0.0, allow_inf_nan=False)
    housingAllowance: Optional[float] = Field(default=0.0, ge=0.0, allow_inf_nan=False)
    transportAllowance: Optional[float] = Field(default=0.0, ge=0.0, allow_inf_nan=False)
    insuranceDeduction: Optional[float] = Field(default=0.0, ge=0.0, allow_inf_nan=False)
    status: Optional[str] = "active"
    department: Optional[str] = "FOH"
    hireDate: Optional[str] = None
    isActive: Optional[bool] = True

    @model_validator(mode="before")
    @classmethod
    def validate_finite_inputs(cls, data: Any) -> Any:
        return _check_finite_dict(data, EMPLOYEE_NUMERIC_FIELDS)

    @field_validator("baseSalary", "hourlyRate", "overtimeRate", "housingAllowance", "transportAllowance", "insuranceDeduction")
    @classmethod
    def validate_finite_non_negative(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v < 0:
                raise ValueError("القيم المالية والأجور والبدلات والاستقطاعات يجب أن تكون أرقاماً حقيقية محدودة وغير سالبة (>= 0)")
        return v

class EmployeeUpdate(BaseModel):
    code: Optional[str] = None
    branchId: Optional[str] = None
    firstNameAr: Optional[str] = None
    lastNameAr: Optional[str] = None
    name: Optional[str] = None
    jobTitle: Optional[str] = None
    role: Optional[str] = None
    phone: Optional[str] = None
    nationalId: Optional[str] = None
    wageType: Optional[str] = None
    baseSalary: Optional[float] = Field(default=None, ge=0.0, allow_inf_nan=False)
    hourlyRate: Optional[float] = Field(default=None, ge=0.0, allow_inf_nan=False)
    overtimeRate: Optional[float] = Field(default=None, ge=0.0, allow_inf_nan=False)
    housingAllowance: Optional[float] = Field(default=None, ge=0.0, allow_inf_nan=False)
    transportAllowance: Optional[float] = Field(default=None, ge=0.0, allow_inf_nan=False)
    insuranceDeduction: Optional[float] = Field(default=None, ge=0.0, allow_inf_nan=False)
    status: Optional[str] = None
    department: Optional[str] = None
    hireDate: Optional[str] = None
    isActive: Optional[bool] = None

    @model_validator(mode="before")
    @classmethod
    def validate_finite_inputs(cls, data: Any) -> Any:
        return _check_finite_dict(data, EMPLOYEE_NUMERIC_FIELDS)

    @field_validator("baseSalary", "hourlyRate", "overtimeRate", "housingAllowance", "transportAllowance", "insuranceDeduction")
    @classmethod
    def validate_finite_non_negative(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v < 0:
                raise ValueError("القيم المالية والأجور والبدلات والاستقطاعات يجب أن تكون أرقاماً حقيقية محدودة وغير سالبة (>= 0)")
        return v

class EmployeeResponse(BaseModel):
    id: str
    code: str
    name: str
    firstNameAr: str
    lastNameAr: str
    jobTitle: str
    role: str
    branchId: str
    branchName: str
    branchCode: str
    managerName: str
    phone: str
    nationalId: str
    wageType: str
    baseSalary: float
    hourlyRate: float
    overtimeRate: float
    housingAllowance: float
    transportAllowance: float
    insuranceDeduction: float
    status: str
    department: str
    totalHoursThisMonth: float = 0.0
    isActive: bool = True
    hireDate: str
    createdAt: Optional[str] = None
    updatedAt: Optional[str] = None

class EmployeeCompensationResponse(BaseModel):
    employeeId: str
    employeeName: str
    employeeCode: str
    jobTitle: str
    branchName: str
    wageType: str
    baseSalary: float
    hourlyRate: float
    overtimeRate: float
    housingAllowance: float
    transportAllowance: float
    insuranceDeduction: float
    totalAllowances: float
    totalDeductions: float
    grossPay: float
    netEstimatedPay: float
    effectiveDate: str
    reviewDate: str
    status: str

class PayHistoryRecordResponse(BaseModel):
    id: str
    employeeId: str
    periodMonth: int
    periodYear: int
    monthLabel: str
    dateLabel: str
    baseAmount: float
    allowanceAmount: float = 0.0
    overtimeAmount: float = 0.0
    deductionsAmount: float = 0.0
    netPayout: float
    status: str
    paymentMethod: Optional[str] = None
    referenceNo: Optional[str] = None
    paidAt: Optional[str] = None
