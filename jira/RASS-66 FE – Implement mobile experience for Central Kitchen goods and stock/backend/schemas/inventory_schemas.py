import math
from typing import List, Optional, Any
from enum import Enum
from pydantic import BaseModel, Field, ConfigDict, field_validator


class StockLevelEnum(str, Enum):
    CRITICAL = "critical"
    LOW = "low"
    AVAILABLE = "available"


class StockMovementTypeEnum(str, Enum):
    ISSUE = "issue"
    RECEIPT = "receipt"
    TRANSFER = "transfer"
    ADJUSTMENT = "adjustment"


class AdjustmentModeEnum(str, Enum):
    DEFICIT = "deficit"
    SURPLUS = "surplus"
    SET_BALANCE = "setBalance"


class StockItemResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

    id: str
    branch_id: str = Field(..., alias="branchId")
    name: str
    sku: str
    category: str
    quantity: float
    unit: str
    unit_cost: float = Field(..., alias="unitCost")
    total_value: float = Field(..., alias="totalValue")
    safety_stock: float = Field(..., alias="safetyStock")
    capacity: float = Field(..., alias="capacity")
    location: str
    stock_level: str = Field(..., alias="stockLevel")
    level: str  # For frontend StockLevel enum ('critical', 'low', 'available')
    updated_at: Optional[str] = Field(None, alias="updatedAt")


class StockMovementResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

    id: str
    code: str
    stock_item_id: str = Field(..., alias="stockItemId")
    branch_id: str = Field(..., alias="branchId")
    item_name: Optional[str] = Field(None, alias="itemName")
    sku: Optional[str] = None
    movement_type: str = Field(..., alias="movementType")
    type: str  # For frontend StockMovementType compatibility
    quantity: float
    quantity_label: Optional[str] = Field(None, alias="quantityLabel")
    balance_after: float = Field(..., alias="balanceAfter")
    description: str
    time: Optional[str] = None
    created_by_user_id: Optional[str] = Field(None, alias="createdByUserId")
    created_at: Optional[str] = Field(None, alias="createdAt")


class StockAdjustmentRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    item_id: Optional[str] = Field(None, alias="itemId")
    branch_id: Optional[str] = Field(None, alias="branchId")
    mode: str = Field(default="deficit")  # 'deficit' (خصم عجز/هالك), 'surplus' (إضافة فائض), 'setBalance' (تحديد رصيد فعلي)
    quantity: float = Field(..., gt=0, description="الكمية المراد تسويتها أو الرصيد الفعلي الجديد")
    reason: str = Field(..., min_length=2, description="سبب التسوية المخزنية للتدقيق")
    notes: Optional[str] = Field(None, description="تفاصيل إضافية للتدقيق والحوكمة")
    user_id: Optional[str] = Field(None, alias="userId")

    @field_validator("quantity")
    @classmethod
    def validate_quantity(cls, v: float) -> float:
        if not math.isfinite(v) or v <= 0:
            raise ValueError("الكمية المحددة للتسوية يجب أن تكون قيمة عددية محدودة وموجبة تماماً")
        return v


class StockAdjustmentResult(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    item: StockItemResponse
    movement: StockMovementResponse
    previous_balance: float = Field(..., alias="previousBalance")
    adjusted_quantity: float = Field(..., alias="adjustedQuantity")
    new_balance: float = Field(..., alias="newBalance")
    financial_impact: float = Field(..., alias="financialImpact")


class CategoryValuation(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    category: str
    total_value: float = Field(..., alias="totalValue")
    item_count: int = Field(..., alias="itemCount")
    total_quantity: float = Field(..., alias="totalQuantity")
    percentage: float


class StockValuationResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    branch_id: str = Field(..., alias="branchId")
    branch_name: Optional[str] = Field(None, alias="branchName")
    total_valuation: float = Field(..., alias="totalValuation")
    total_items: int = Field(..., alias="totalItems")
    critical_count: int = Field(..., alias="criticalCount")
    low_count: int = Field(..., alias="lowCount")
    available_count: int = Field(..., alias="availableCount")
    by_category: List[CategoryValuation] = Field(default_factory=list, alias="byCategory")
    top_items: List[StockItemResponse] = Field(default_factory=list, alias="topItems")


class ApiResponse(BaseModel):
    success: bool = True
    data: Optional[Any] = None
    message: Optional[str] = None
    errors: Optional[List[str]] = None
