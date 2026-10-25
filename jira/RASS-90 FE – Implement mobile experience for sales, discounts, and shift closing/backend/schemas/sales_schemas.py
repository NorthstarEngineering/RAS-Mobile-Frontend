"""
Sales Schemas - Pydantic models for RMS Sales, Shifts, and Discounts.
Unified validation supporting both camelCase and snake_case payloads.
"""

import math
from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field, ConfigDict, field_validator


class ApiResponse(BaseModel):
    success: bool = True
    data: Optional[Any] = None
    message: Optional[str] = None
    meta: Optional[Dict[str, Any]] = None
    errors: Optional[List[str]] = None


# ---------------------------------------------------------------------------
# Shift Models
# ---------------------------------------------------------------------------

class OpenShiftRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    branch_id: str = Field(..., alias="branchId", description="Branch ID (e.g. br_01)")
    cashier_user_id: str = Field(..., alias="cashierUserId", description="Cashier user ID (e.g. usr_cashier1)")
    supervisor_user_id: Optional[str] = Field(None, alias="supervisorUserId", description="Supervisor user ID (e.g. usr_bm1)")
    opening_cash: float = Field(0.0, alias="openingCash", ge=0.0, description="Opening drawer cash balance")
    start_time: Optional[str] = Field(None, alias="startTime", description="Shift start time")
    notes: Optional[str] = Field(None, description="Operational notes")

    @field_validator("opening_cash")
    @classmethod
    def validate_opening_cash(cls, v: float) -> float:
        if not math.isfinite(v) or v < 0:
            raise ValueError("النقد الافتتاحي يجب أن يكون رقماً حقيقياً غير سالب (>= 0)")
        return v


class SoldItemInput(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    menu_item_id: Optional[str] = Field(None, alias="menuItemId")
    name: str = Field(..., description="Item Arabic name")
    sku: Optional[str] = Field(None, description="Item SKU code")
    category: Optional[str] = Field("البرجر", description="Menu category name")
    quantity: int = Field(1, ge=1, description="Quantity sold")
    unit_price: float = Field(..., alias="unitPrice", ge=0.0, description="Unit price")
    channel: Optional[str] = Field("dine_in", description="Channel (dine_in, takeaway, delivery_apps)")

    @field_validator("unit_price")
    @classmethod
    def validate_unit_price(cls, v: float) -> float:
        if not math.isfinite(v) or v < 0:
            raise ValueError("سعر الوحدة يجب أن يكون رقماً حقيقياً غير سالب (>= 0)")
        return v


class ShiftEntryRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    shift_id: Optional[str] = Field(None, alias="shiftId", description="Shift ID (auto-resolved if empty)")
    channel: str = Field("dine_in", description="Channel: dine_in, takeaway, delivery_apps")
    gross_amount: Optional[float] = Field(None, alias="grossAmount", ge=0.0, description="Gross total sales")
    discount_amount: float = Field(0.0, alias="discountAmount", ge=0.0, description="Discount amount")
    net_amount: Optional[float] = Field(None, alias="netAmount", ge=0.0, description="Net total sales")
    payment_method: str = Field("cash", alias="paymentMethod", description="cash, card, aggregator_account")
    order_count: int = Field(1, alias="orderCount", ge=1, description="Number of orders in entry")
    items: Optional[List[SoldItemInput]] = Field(None, description="Itemized breakdown")
    branch_id: Optional[str] = Field(None, alias="branchId", description="Optional branch ID to find active shift")

    @field_validator("gross_amount", "net_amount")
    @classmethod
    def validate_amounts(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v < 0:
                raise ValueError("المبلغ يجب أن يكون رقماً حقيقياً غير سالب (>= 0)")
        return v

    @field_validator("discount_amount")
    @classmethod
    def validate_discount(cls, v: float) -> float:
        if not math.isfinite(v) or v < 0:
            raise ValueError("مبلغ الخصم يجب أن يكون رقماً حقيقياً غير سالب (>= 0)")
        return v


class CloseShiftRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    shift_id: Optional[str] = Field(None, alias="shiftId", description="Shift ID to close")
    closing_cash_actual: Optional[float] = Field(None, alias="closingCashActual", ge=0.0, description="Actual counted drawer cash")
    supervisor_user_id: Optional[str] = Field(None, alias="supervisorUserId", description="Supervisor user authorizing close")
    notes: Optional[str] = Field(None, description="Closing remarks / variance justification")
    branch_id: Optional[str] = Field(None, alias="branchId", description="Optional branch ID to locate open shift")

    @field_validator("closing_cash_actual")
    @classmethod
    def validate_closing_cash(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if not math.isfinite(v) or v < 0:
                raise ValueError("النقد الفعلي بالدرج يجب أن يكون رقماً حقيقياً غير سالب (>= 0)")
        return v


class ShiftResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    branch_id: str = Field(..., alias="branchId")
    branch_name: Optional[str] = Field(None, alias="branchName")
    cashier_user_id: str = Field(..., alias="cashierUserId")
    cashier_name: Optional[str] = Field(None, alias="cashierName")
    supervisor_user_id: Optional[str] = Field(None, alias="supervisorUserId")
    supervisor_name: Optional[str] = Field(None, alias="supervisorName")
    start_time: str = Field(..., alias="startTime")
    end_time: Optional[str] = Field(None, alias="endTime")
    opening_cash: float = Field(..., alias="openingCash")
    closing_cash_actual: Optional[float] = Field(None, alias="closingCashActual")
    closing_cash_system: Optional[float] = Field(None, alias="closingCashSystem")
    cash_variance: Optional[float] = Field(None, alias="cashVariance")
    total_sales: float = Field(..., alias="totalSales")
    total_discounts: float = Field(..., alias="totalDiscounts")
    status: str  # 'open', 'under_review', 'closed'
    notes: Optional[str] = None
    created_at: Optional[str] = Field(None, alias="createdAt")


# ---------------------------------------------------------------------------
# Dashboard Models
# ---------------------------------------------------------------------------

class ChannelMetric(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    channel_key: str = Field(..., alias="channelKey")
    title: str
    order_count: int = Field(..., alias="orderCount")
    total_amount: float = Field(..., alias="totalAmount")
    percentage: float


class SalesDashboardResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    shift_status: Dict[str, Any] = Field(..., alias="shiftStatus")
    total_sales: float = Field(..., alias="totalSales")
    net_sales: float = Field(..., alias="netSales")
    total_discounts: float = Field(..., alias="totalDiscounts")
    total_orders: int = Field(..., alias="totalOrders")
    dine_in_ratio: float = Field(..., alias="dineInRatio")
    delivery_ratio: float = Field(..., alias="deliveryRatio")
    channels: List[ChannelMetric]
    active_shift: Optional[ShiftResponse] = Field(None, alias="activeShift")


# ---------------------------------------------------------------------------
# Restaurant Sales Models
# ---------------------------------------------------------------------------

class RestaurantItemResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: Optional[str] = None
    name: str
    sku: str
    category: str
    quantity: int
    unit_price: float = Field(..., alias="unitPrice")
    total_amount: float = Field(..., alias="totalAmount")


class RestaurantSalesResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    total_sales: float = Field(..., alias="totalSales")
    total_orders: int = Field(..., alias="totalOrders")
    items: List[RestaurantItemResponse]
    categories: List[str]


# ---------------------------------------------------------------------------
# Delivery Sales Models
# ---------------------------------------------------------------------------

class DeliveryOrderResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: Optional[str] = None
    title: str
    sku: str
    channel: str
    quantity: int
    unit_price: float = Field(..., alias="unitPrice")
    total_amount: float = Field(..., alias="totalAmount")


class DeliverySalesResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    total_revenue: float = Field(..., alias="totalRevenue")
    total_orders: int = Field(..., alias="totalOrders")
    channels: List[str]
    orders: List[DeliveryOrderResponse]
    reconciliation: Dict[str, Any]


# ---------------------------------------------------------------------------
# Discount Models
# ---------------------------------------------------------------------------

class DiscountCreateRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    shift_id: Optional[str] = Field(None, alias="shiftId", description="Shift ID")
    discount_code: str = Field(..., alias="discountCode", description="Discount coupon/code")
    type: str = Field("promotional", description="percentage, fixed_amount, promotional, staff")
    amount: float = Field(..., ge=0.0, description="Discount monetary amount")
    reason: str = Field(..., description="Justification reason")
    authorized_by_user_id: Optional[str] = Field("usr_bm1", alias="authorizedByUserId")

    @field_validator("amount")
    @classmethod
    def validate_amount(cls, v: float) -> float:
        if not math.isfinite(v) or v < 0:
            raise ValueError("قيمة الخصم يجب أن تكون رقماً حقيقياً غير سالب (>= 0)")
        return v


class DiscountCancelRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    reason: str = Field("سوء استخدام صلاحية", description="Mandatory cancellation reason")
    cancelled_by_user_id: Optional[str] = Field("usr_bm1", alias="cancelledByUserId")
    note: Optional[str] = Field(None, description="Audit note")


class DiscountResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    shift_id: str = Field(..., alias="shiftId")
    discount_code: str = Field(..., alias="discountCode")
    type: str
    amount: float
    reason: str
    status: str  # 'applied', 'cancelled'
    authorized_by_user_id: str = Field(..., alias="authorizedByUserId")
    authorized_by_name: Optional[str] = Field(None, alias="authorizedByName")
    cancelled_by_user_id: Optional[str] = Field(None, alias="cancelledByUserId")
    cancelled_by_name: Optional[str] = Field(None, alias="cancelledByName")
    cancel_reason: Optional[str] = Field(None, alias="cancelReason")
    created_at: str = Field(..., alias="createdAt")
