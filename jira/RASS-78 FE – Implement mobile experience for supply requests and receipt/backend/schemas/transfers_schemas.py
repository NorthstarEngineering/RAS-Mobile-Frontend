from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field, ConfigDict, AliasChoices


class ApiResponse(BaseModel):
    success: bool = True
    data: Optional[Any] = None
    message: Optional[str] = None
    errors: Optional[List[str]] = None


class TransferItemCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    stock_item_id: Optional[str] = Field(None, validation_alias=AliasChoices("stockItemId", "stock_item_id"))
    sku: Optional[str] = None
    item_name: Optional[str] = Field(None, validation_alias=AliasChoices("itemName", "item_name", "name"))
    quantity: float = Field(..., gt=0, description="الكمية المطلوب تحويلها")


class TransferItemReceive(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    stock_item_id: Optional[str] = Field(None, validation_alias=AliasChoices("stockItemId", "stock_item_id"))
    item_id: Optional[str] = Field(None, validation_alias=AliasChoices("itemId", "item_id", "id"))
    received_quantity: float = Field(..., ge=0, validation_alias=AliasChoices("receivedQuantity", "received_quantity"))


class TransferItemResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    transferId: str = Field(..., validation_alias=AliasChoices("transferId", "transfer_id"))
    stockItemId: str = Field(..., validation_alias=AliasChoices("stockItemId", "stock_item_id"))
    name: str
    sku: str
    category: Optional[str] = "عام"
    unit: Optional[str] = "وحدة"
    quantity: float
    receivedQuantity: Optional[float] = Field(None, validation_alias=AliasChoices("receivedQuantity", "received_quantity"))
    unitCost: float = Field(0.0, validation_alias=AliasChoices("unitCost", "unit_cost"))
    availableQuantityAtSource: Optional[float] = Field(None, validation_alias=AliasChoices("availableQuantityAtSource", "available_quantity_at_source"))
    availableQuantityAtDestination: Optional[float] = Field(None, validation_alias=AliasChoices("availableQuantityAtDestination", "available_quantity_at_destination"))

    @property
    def transfer_id(self) -> str:
        return self.transferId

    @property
    def stock_item_id(self) -> str:
        return self.stockItemId

    @property
    def received_quantity(self) -> Optional[float]:
        return self.receivedQuantity

    @property
    def unit_cost(self) -> float:
        return self.unitCost

    @property
    def available_quantity_at_source(self) -> Optional[float]:
        return self.availableQuantityAtSource

    @property
    def available_quantity_at_destination(self) -> Optional[float]:
        return self.availableQuantityAtDestination


class TransferCreateRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    transfer_code: Optional[str] = Field(None, validation_alias=AliasChoices("transferCode", "transfer_code"))
    source_branch_id: str = Field(..., validation_alias=AliasChoices("sourceBranchId", "source_branch_id"))
    destination_branch_id: str = Field(..., validation_alias=AliasChoices("destinationBranchId", "destination_branch_id"))
    items: List[TransferItemCreate] = Field(..., min_length=1)
    notes: Optional[str] = None
    is_urgent: Optional[bool] = Field(False, validation_alias=AliasChoices("isUrgent", "is_urgent"))
    created_by_user_id: Optional[str] = Field(None, validation_alias=AliasChoices("createdByUserId", "created_by_user_id"))


class TransferReviewRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    approved: bool = True
    decision: Optional[str] = "approved"  # 'approved' or 'rejected'
    notes: Optional[str] = None
    reviewed_by_user_id: Optional[str] = Field(None, validation_alias=AliasChoices("reviewedByUserId", "reviewed_by_user_id"))
    approved_quantities: Optional[Dict[str, float]] = Field(None, validation_alias=AliasChoices("approvedQuantities", "approved_quantities"))


class TransferSendRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    driver_name: str = Field(..., validation_alias=AliasChoices("driverName", "driver_name"))
    driver_phone: Optional[str] = Field(None, validation_alias=AliasChoices("driverPhone", "driver_phone"))
    departure_time: Optional[str] = Field(None, validation_alias=AliasChoices("departureTime", "departure_time"))
    vehicle: Optional[str] = None
    notes: Optional[str] = None
    temperature: Optional[str] = None
    sent_by_user_id: Optional[str] = Field(None, validation_alias=AliasChoices("sentByUserId", "sent_by_user_id"))


class TransferReceiveRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    received_by_user_id: Optional[str] = Field(None, validation_alias=AliasChoices("receivedByUserId", "received_by_user_id"))
    arrival_time: Optional[str] = Field(None, validation_alias=AliasChoices("arrivalTime", "arrival_time"))
    received_items: Optional[List[Dict[str, Any]]] = Field(None, validation_alias=AliasChoices("receivedItems", "received_items"))
    has_damage: Optional[bool] = Field(False, validation_alias=AliasChoices("hasDamage", "has_damage"))
    damage_notes: Optional[str] = Field(None, validation_alias=AliasChoices("damageNotes", "damage_notes"))
    notes: Optional[str] = None


class TransferResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    transferCode: str = Field(..., validation_alias=AliasChoices("transferCode", "transfer_code"))
    sourceBranchId: str = Field(..., validation_alias=AliasChoices("sourceBranchId", "source_branch_id"))
    sourceBranchName: str = Field(..., validation_alias=AliasChoices("sourceBranchName", "source_branch_name"))
    sourceBranchCode: Optional[str] = Field(None, validation_alias=AliasChoices("sourceBranchCode", "source_branch_code"))
    destinationBranchId: str = Field(..., validation_alias=AliasChoices("destinationBranchId", "destination_branch_id"))
    destinationBranchName: str = Field(..., validation_alias=AliasChoices("destinationBranchName", "destination_branch_name"))
    destinationBranchCode: Optional[str] = Field(None, validation_alias=AliasChoices("destinationBranchCode", "destination_branch_code"))
    status: str
    statusLabelAr: str = Field(..., validation_alias=AliasChoices("statusLabelAr", "status_label_ar"))
    driverName: Optional[str] = Field(None, validation_alias=AliasChoices("driverName", "driver_name"))
    driverPhone: Optional[str] = Field(None, validation_alias=AliasChoices("driverPhone", "driver_phone"))
    departureTime: Optional[str] = Field(None, validation_alias=AliasChoices("departureTime", "departure_time"))
    arrivalTime: Optional[str] = Field(None, validation_alias=AliasChoices("arrivalTime", "arrival_time"))
    notes: Optional[str] = None
    createdByUserId: str = Field(..., validation_alias=AliasChoices("createdByUserId", "created_by_user_id"))
    createdByName: Optional[str] = Field(None, validation_alias=AliasChoices("createdByName", "created_by_name", "creator_name"))
    approvedByUserId: Optional[str] = Field(None, validation_alias=AliasChoices("approvedByUserId", "approved_by_user_id"))
    approvedByName: Optional[str] = Field(None, validation_alias=AliasChoices("approvedByName", "approved_by_name", "approver_name"))
    receivedByUserId: Optional[str] = Field(None, validation_alias=AliasChoices("receivedByUserId", "received_by_user_id"))
    receivedByName: Optional[str] = Field(None, validation_alias=AliasChoices("receivedByName", "received_by_name", "receiver_name"))
    items: List[TransferItemResponse] = Field(default_factory=list)
    itemsCount: int = Field(0, validation_alias=AliasChoices("itemsCount", "items_count"))
    totalQuantity: float = Field(0.0, validation_alias=AliasChoices("totalQuantity", "total_quantity"))
    sourceBalance: Optional[float] = Field(None, validation_alias=AliasChoices("sourceBalance", "source_balance"))
    destinationBalance: Optional[float] = Field(None, validation_alias=AliasChoices("destinationBalance", "destination_balance"))
    createdAt: str = Field(..., validation_alias=AliasChoices("createdAt", "created_at"))
    updatedAt: str = Field(..., validation_alias=AliasChoices("updatedAt", "updated_at"))

    @property
    def source_balance(self) -> Optional[float]:
        return self.sourceBalance

    @property
    def destination_balance(self) -> Optional[float]:
        return self.destinationBalance

    @property
    def transfer_code(self) -> str:
        return self.transferCode

    @property
    def source_branch_id(self) -> str:
        return self.sourceBranchId

    @property
    def source_branch_name(self) -> str:
        return self.sourceBranchName

    @property
    def destination_branch_id(self) -> str:
        return self.destinationBranchId

    @property
    def destination_branch_name(self) -> str:
        return self.destinationBranchName

    @property
    def status_label_ar(self) -> str:
        return self.statusLabelAr

    @property
    def driver_name(self) -> Optional[str]:
        return self.driverName

    @property
    def driver_phone(self) -> Optional[str]:
        return self.driverPhone

    @property
    def departure_time(self) -> Optional[str]:
        return self.departureTime

    @property
    def arrival_time(self) -> Optional[str]:
        return self.arrivalTime

    @property
    def created_by_user_id(self) -> str:
        return self.createdByUserId

    @property
    def approved_by_user_id(self) -> Optional[str]:
        return self.approvedByUserId

    @property
    def received_by_user_id(self) -> Optional[str]:
        return self.receivedByUserId

    @property
    def items_count(self) -> int:
        return self.itemsCount

    @property
    def total_quantity(self) -> float:
        return self.totalQuantity

    @property
    def created_at(self) -> str:
        return self.createdAt

    @property
    def updated_at(self) -> str:
        return self.updatedAt


class TransferMetricsResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    pendingReviewCount: int = Field(0, validation_alias=AliasChoices("pendingReviewCount", "pending_review_count"))
    inTransitCount: int = Field(0, validation_alias=AliasChoices("inTransitCount", "in_transit_count"))
    receivedCount: int = Field(0, validation_alias=AliasChoices("receivedCount", "received_count"))
    totalTransfers: int = Field(0, validation_alias=AliasChoices("totalTransfers", "total_transfers"))

    @property
    def pending_review_count(self) -> int:
        return self.pendingReviewCount

    @property
    def in_transit_count(self) -> int:
        return self.inTransitCount

    @property
    def received_count(self) -> int:
        return self.receivedCount

    @property
    def total_transfers(self) -> int:
        return self.totalTransfers
