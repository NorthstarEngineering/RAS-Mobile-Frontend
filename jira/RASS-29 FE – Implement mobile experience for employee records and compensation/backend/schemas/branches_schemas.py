from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field, ConfigDict


class ApiResponse(BaseModel):
    success: bool = True
    data: Optional[Any] = None
    message: Optional[str] = None
    errors: Optional[List[str]] = None
    meta: Optional[Dict[str, Any]] = None


class BranchBase(BaseModel):
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

    name_ar: str = Field(..., alias="nameAr")
    name_en: Optional[str] = Field("", alias="nameEn")
    code: str
    address: str
    phone: str
    manager_name: Optional[str] = Field("", alias="managerName")
    type: str = "dining"  # 'dining' or 'kitchen'
    is_active: bool = Field(True, alias="isActive")
    is_main: Optional[bool] = Field(False, alias="isMain")
    employee_count: Optional[int] = Field(15, alias="employeeCount")
    efficiency_rate: Optional[float] = Field(98.5, alias="efficiencyRate")
    working_hours: Optional[str] = Field("09:00 ص - 01:00 ص", alias="workingHours")
    pos_terminals_count: Optional[int] = Field(4, alias="posTerminalsCount")


class BranchCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

    id: Optional[str] = None
    name_ar: Optional[str] = Field(None, alias="nameAr")
    name_en: Optional[str] = Field(None, alias="nameEn")
    name: Optional[str] = None
    code: str
    address: str
    phone: str
    manager_name: Optional[str] = Field(None, alias="managerName")
    type: str = "dining"
    is_active: bool = Field(True, alias="isActive")
    is_main: Optional[bool] = Field(False, alias="isMain")
    employee_count: Optional[int] = Field(15, alias="employeeCount")
    efficiency_rate: Optional[float] = Field(98.5, alias="efficiencyRate")
    working_hours: Optional[str] = Field("09:00 ص - 01:00 ص", alias="workingHours")
    pos_terminals_count: Optional[int] = Field(4, alias="posTerminalsCount")


class BranchUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

    name_ar: Optional[str] = Field(None, alias="nameAr")
    name_en: Optional[str] = Field(None, alias="nameEn")
    name: Optional[str] = None
    code: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    manager_name: Optional[str] = Field(None, alias="managerName")
    type: Optional[str] = None
    is_active: Optional[bool] = Field(None, alias="isActive")
    is_main: Optional[bool] = Field(None, alias="isMain")
    employee_count: Optional[int] = Field(None, alias="employeeCount")
    efficiency_rate: Optional[float] = Field(None, alias="efficiencyRate")
    working_hours: Optional[str] = Field(None, alias="workingHours")
    pos_terminals_count: Optional[int] = Field(None, alias="posTerminalsCount")


class BranchResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

    id: str
    code: str
    name: str
    nameAr: str
    nameEn: str
    type: str
    address: str
    phone: str
    managerName: str
    employeeCount: int
    efficiencyRate: float
    isMain: bool
    isActive: bool
    workingHours: Optional[str] = None
    posTerminalsCount: Optional[int] = None
    createdAt: str
    updatedAt: str


class CentralKitchenStockAlert(BaseModel):
    itemName: str
    remainingUnits: str
    actionText: str
    isCritical: bool = False


class CentralKitchenDelivery(BaseModel):
    branchName: str
    truckNumber: str
    itemCountDescription: str
    status: str


class CentralKitchenSummaryResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

    kitchenBranch: Optional[BranchResponse] = None
    capacityDescription: str
    crewDescription: str
    fleetDescription: str
    readinessRate: float
    readinessText: str
    criticalAlerts: List[CentralKitchenStockAlert]
    activeDeliveries: List[CentralKitchenDelivery]
    totalRawStockItems: int
    totalSupplyOrders: int
