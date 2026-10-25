import math
from typing import List, Optional, Any, Dict
from enum import Enum
from pydantic import BaseModel, Field, ConfigDict, model_validator, field_validator


class StockLevelEnum(str, Enum):
    CRITICAL = "critical"
    LOW = "low"
    AVAILABLE = "available"


class StockMovementTypeEnum(str, Enum):
    ISSUE = "issue"
    RECEIPT = "receipt"
    TRANSFER = "transfer"
    ADJUSTMENT = "adjustment"


class KitchenItemResponse(BaseModel):
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
    level: str  # For frontend StockLevel compatibility ('critical', 'low', 'available')
    updated_at: Optional[str] = Field(None, alias="updatedAt")


class KitchenItemCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: Optional[str] = None
    name: str = Field(..., min_length=1, description="اسم الصنف الخام بالكامل")
    sku: str = Field(..., min_length=1, description="كود الصنف المخزني الفريد (SKU)")
    category: str = Field(..., min_length=1, description="الفئة التصنيفية للخام")
    quantity: float = Field(default=0.0, ge=0.0, description="الرصيد الافتتاحي أو الحالي")
    unit: str = Field(default="كجم", description="وحدة القياس المعتمدة")
    unit_cost: float = Field(default=0.0, ge=0.0, alias="unitCost", description="تكلفة الوحدة")
    cost: Optional[float] = Field(None, ge=0.0, description="حقل بديل لتكلفة الوحدة")
    safety_stock: float = Field(default=0.0, ge=0.0, alias="safetyStock", description="حد الأمان الأدنى")
    safety: Optional[float] = Field(None, ge=0.0, description="حقل بديل لحد الأمان الأدنى")
    capacity: Optional[float] = Field(None, ge=0.0, description="السعة التخزينية القصوى للمستودع")
    location: Optional[str] = Field("المستودع الرئيسي للمطبخ المركزي", description="موقع التخزين أو الثلاجة")
    branch_id: Optional[str] = Field(None, alias="branchId", description="معرف الفرع (المطبخ المركزي)")
    user_id: Optional[str] = Field("usr_ceo", alias="userId", description="معرف المستخدم منفذ العملية")

    @field_validator("quantity", "unit_cost", "cost", "safety_stock", "safety", "capacity")
    @classmethod
    def validate_finite_nonnegative_create(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v < 0.0:
                raise ValueError("القيمة العددية يجب أن تكون محدودة وغير سالبة")
        return v

    @model_validator(mode="after")
    def resolve_aliases(self) -> "KitchenItemCreate":
        if self.cost is not None and self.unit_cost == 0.0:
            self.unit_cost = self.cost
        if self.safety is not None and self.safety_stock == 0.0:
            self.safety_stock = self.safety
        return self


class KitchenItemUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    name: Optional[str] = None
    sku: Optional[str] = None
    category: Optional[str] = None
    quantity: Optional[float] = Field(None, ge=0.0)
    unit: Optional[str] = None
    unit_cost: Optional[float] = Field(None, ge=0.0, alias="unitCost")
    cost: Optional[float] = Field(None, ge=0.0)
    safety_stock: Optional[float] = Field(None, ge=0.0, alias="safetyStock")
    safety: Optional[float] = Field(None, ge=0.0)
    capacity: Optional[float] = Field(None, ge=0.0)
    location: Optional[str] = None
    branch_id: Optional[str] = Field(None, alias="branchId")
    user_id: Optional[str] = Field("usr_ceo", alias="userId")

    @field_validator("quantity", "unit_cost", "cost", "safety_stock", "safety", "capacity")
    @classmethod
    def validate_finite_nonnegative_update(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v < 0.0:
                raise ValueError("القيمة العددية يجب أن تكون محدودة وغير سالبة")
        return v

    @model_validator(mode="after")
    def resolve_aliases(self) -> "KitchenItemUpdate":
        if self.cost is not None and self.unit_cost is None:
            self.unit_cost = self.cost
        if self.safety is not None and self.safety_stock is None:
            self.safety_stock = self.safety
        return self


class KitchenMovementResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

    id: str
    code: str
    stock_item_id: str = Field(..., alias="stockItemId")
    branch_id: str = Field(..., alias="branchId")
    item_name: Optional[str] = Field(None, alias="itemName")
    sku: Optional[str] = None
    movement_type: str = Field(..., alias="movementType")
    type: str  # 'issue', 'receipt', 'transfer', 'adjustment'
    quantity: float
    quantity_label: Optional[str] = Field(None, alias="quantityLabel")
    balance_after: float = Field(..., alias="balanceAfter")
    description: str
    time: Optional[str] = None
    created_by_user_id: Optional[str] = Field(None, alias="createdByUserId")
    created_at: Optional[str] = Field(None, alias="createdAt")


class KitchenItemsSummary(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    total: int
    critical_count: int = Field(0, alias="criticalCount")
    low_count: int = Field(0, alias="lowCount")
    available_count: int = Field(0, alias="availableCount")
    total_valuation: float = Field(0.0, alias="totalValuation")


class KitchenMovementsSummary(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    total: int
    issue_count: int = Field(0, alias="issueCount")
    receipt_count: int = Field(0, alias="receiptCount")
    transfer_count: int = Field(0, alias="transferCount")
    adjustment_count: int = Field(0, alias="adjustmentCount")


class ApiResponse(BaseModel):
    success: bool = True
    data: Optional[Any] = None
    message: Optional[str] = None
    meta: Optional[Dict[str, Any]] = None
    errors: Optional[List[str]] = None
