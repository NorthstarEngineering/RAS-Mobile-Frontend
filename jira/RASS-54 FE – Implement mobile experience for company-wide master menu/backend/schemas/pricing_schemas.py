import math
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional, Any
from pydantic import BaseModel, Field, ConfigDict, field_validator, model_validator

class ApiResponse(BaseModel):
    success: bool = True
    data: Optional[Any] = None
    message: Optional[str] = None
    error: Optional[Any] = None
    meta: Optional[dict] = None

class PriceChangeRequestCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="allow")

    id: Optional[str] = None
    itemId: str
    proposedPrice: float = Field(..., gt=0.0)
    currentPrice: Optional[float] = None
    reason: str
    requestedByUserId: Optional[str] = "usr_bm1"
    effectiveDate: Optional[str] = None
    requestNumber: Optional[str] = None
    branchId: Optional[str] = Field(None, alias="branchId")
    branch_id: Optional[str] = Field(None, alias="branch_id")

    @field_validator("proposedPrice")
    @classmethod
    def validate_proposed_price(cls, v: float) -> float:
        if not math.isfinite(v) or v <= 0:
            raise ValueError("السعر المقترح يجب أن يكون رقماً حقيقياً موجباً (> 0)")
        return v

    @field_validator("currentPrice")
    @classmethod
    def validate_current_price(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v < 0:
                raise ValueError("السعر الحالي يجب أن يكون رقماً حقيقياً غير سالب (>= 0)")
        return v

class PriceChangeRequestApprove(BaseModel):
    approvedByUserId: Optional[str] = "usr_ceo"
    effectiveDate: Optional[str] = None
    reviewNotes: Optional[str] = None
    approvedPrice: Optional[float] = None

    @field_validator("approvedPrice")
    @classmethod
    def validate_approved_price(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v <= 0:
                raise ValueError("السعر المعتمد يجب أن يكون رقماً حقيقياً موجباً (> 0)")
        return v

class PriceChangeRequestReject(BaseModel):
    reviewedByUserId: Optional[str] = "usr_ceo"
    reviewNotes: Optional[str] = None

class PriceChangeRequestResponse(BaseModel):
    id: str
    requestNumber: str
    itemId: str
    itemNameAr: str
    itemNameEn: str = ""
    itemSku: str = ""
    categoryName: str = ""
    currentPrice: float
    proposedPrice: float
    cost: float = 0.0
    branchName: str = ""
    requestedByName: str = ""
    requestDate: str
    status: str = "pending"
    reason: str = ""
    effectiveDate: Optional[str] = None
    difference: float = 0.0
    percentageChange: float = 0.0
    approvedPrice: Optional[float] = None

class PriceHistoryResponse(BaseModel):
    id: str
    itemId: str
    oldPrice: float
    newPrice: float
    effectiveDate: str
    approvedByName: str
    reason: str
    difference: float = 0.0
    percentageChange: float = 0.0
    itemNameAr: Optional[str] = None
    itemNameEn: Optional[str] = None
    itemSku: Optional[str] = None
    categoryName: Optional[str] = None
    currentPrice: Optional[float] = None

class ItemPricingSummaryResponse(BaseModel):
    itemId: str
    itemNameAr: str
    itemNameEn: str = ""
    itemSku: str = ""
    categoryName: str = ""
    currentPrice: float
    cost: float = 0.0
    effectiveSince: Optional[str] = None
    upcomingPrice: Optional[float] = None
    upcomingEffectiveDate: Optional[str] = None
    upcomingStatus: Optional[str] = None
