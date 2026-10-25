from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field, ConfigDict


class ApiResponse(BaseModel):
    success: bool = True
    data: Optional[Any] = None
    message: Optional[str] = None
    meta: Optional[Dict[str, Any]] = None
    errors: Optional[List[str]] = None


class SupplyOrderItemCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    stock_item_id: str = Field(..., alias="stockItemId", description="ID or SKU of the stock item")
    requested_quantity: float = Field(..., alias="requestedQuantity", gt=0, description="Requested quantity")
    unit_cost: Optional[float] = Field(None, alias="unitCost", ge=0, description="Optional unit cost override")
    notes: Optional[str] = None


class SupplyOrderItemResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    supplyOrderId: str = Field(..., alias="supply_order_id")
    stockItemId: str = Field(..., alias="stock_item_id")
    itemName: str = Field("", alias="item_name")
    itemSku: str = Field("", alias="item_sku")
    category: str = Field("", alias="category")
    unit: str = Field("كجم", alias="unit")
    requestedQuantity: float = Field(..., alias="requested_quantity")
    dispatchedQuantity: Optional[float] = Field(None, alias="dispatched_quantity")
    receivedQuantity: Optional[float] = Field(None, alias="received_quantity")
    unitCost: float = Field(0.0, alias="unit_cost")
    totalCost: float = Field(0.0, alias="total_cost")


class SupplyOrderCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    destination_branch_id: str = Field(..., alias="destinationBranchId", description="Branch receiving goods")
    source_kitchen_id: Optional[str] = Field("br_04", alias="sourceKitchenId", description="Central Kitchen providing goods")
    requested_delivery_date: Optional[str] = Field(None, alias="requestedDeliveryDate")
    created_by_user_id: Optional[str] = Field(None, alias="createdByUserId")
    order_number: Optional[str] = Field(None, alias="orderNumber")
    status: Optional[str] = Field("pending", description="Initial status (pending, draft)")
    items: List[SupplyOrderItemCreate]
    notes: Optional[str] = None
    urgent: Optional[bool] = False
    priority: Optional[str] = Field("normal", description="normal, urgent")


class ExecuteSupplyOrderItem(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    item_id: Optional[str] = Field(None, alias="itemId")
    stock_item_id: Optional[str] = Field(None, alias="stockItemId")
    dispatched_quantity: float = Field(..., alias="dispatchedQuantity", ge=0)


class ExecuteSupplyOrderRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    executed_by_user_id: Optional[str] = Field(None, alias="executedByUserId")
    vehicle_info: Optional[str] = Field(None, alias="vehicleInfo")
    driver_name: Optional[str] = Field(None, alias="driverName")
    driver_phone: Optional[str] = Field(None, alias="driverPhone")
    notes: Optional[str] = None
    confirmed: Optional[bool] = True
    allow_overdraw: Optional[bool] = Field(False, alias="allowOverdraw", description="Allow kitchen balance to go negative if urgent")
    items: Optional[List[ExecuteSupplyOrderItem]] = None


class ReceiveSupplyOrderItem(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    item_id: Optional[str] = Field(None, alias="itemId")
    stock_item_id: Optional[str] = Field(None, alias="stockItemId")
    received_quantity: float = Field(..., alias="receivedQuantity", ge=0)
    damaged_quantity: Optional[float] = Field(0.0, alias="damagedQuantity")


class ReceiveSupplyOrderRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    received_by_user_id: Optional[str] = Field(None, alias="receivedByUserId")
    has_shortage: Optional[bool] = Field(False, alias="hasShortage")
    shortage_notes: Optional[str] = Field(None, alias="shortageNotes")
    notes: Optional[str] = None
    confirmed: Optional[bool] = True
    temperature_celsius: Optional[float] = Field(None, alias="temperatureCelsius")
    items: Optional[List[ReceiveSupplyOrderItem]] = None


class SupplyOrderResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    orderNumber: str = Field(..., alias="order_number")
    sourceKitchenId: str = Field(..., alias="source_kitchen_id")
    sourceKitchenName: Optional[str] = Field("", alias="source_kitchen_name")
    destinationBranchId: str = Field(..., alias="destination_branch_id")
    destinationBranchName: Optional[str] = Field("", alias="destination_branch_name")
    status: str
    statusAr: Optional[str] = Field("", alias="status_ar")
    totalCost: float = Field(0.0, alias="total_cost")
    requestedDeliveryDate: str = Field(..., alias="requested_delivery_date")
    createdByUserId: Optional[str] = Field(None, alias="created_by_user_id")
    createdByName: Optional[str] = Field("", alias="created_by_name")
    executedByUserId: Optional[str] = Field(None, alias="executed_by_user_id")
    executedByName: Optional[str] = Field("", alias="executed_by_name")
    receivedByUserId: Optional[str] = Field(None, alias="received_by_user_id")
    receivedByName: Optional[str] = Field("", alias="received_by_name")
    itemsCount: int = Field(0, alias="items_count")
    summary: Optional[str] = ""
    notes: Optional[str] = None
    vehicleInfo: Optional[str] = Field(None, alias="vehicle_info")
    createdAt: Optional[str] = Field(None, alias="created_at")
    updatedAt: Optional[str] = Field(None, alias="updated_at")
    items: List[SupplyOrderItemResponse] = []
