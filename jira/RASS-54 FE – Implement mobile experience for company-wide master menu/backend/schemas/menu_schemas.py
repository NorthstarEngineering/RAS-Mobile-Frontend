from typing import List, Optional, Any
from pydantic import BaseModel, Field

# --- Categories ---

class MenuCategoryResponse(BaseModel):
    id: str
    nameAr: str
    nameEn: str
    sortOrder: int = 0
    itemsCount: int = 0
    isActive: bool = True

class MenuCategoryCreate(BaseModel):
    id: Optional[str] = None
    nameAr: str
    nameEn: Optional[str] = ""
    sortOrder: Optional[int] = 0
    isActive: Optional[bool] = True

class MenuCategoryUpdate(BaseModel):
    nameAr: Optional[str] = None
    nameEn: Optional[str] = None
    sortOrder: Optional[int] = None
    isActive: Optional[bool] = None

class CategoryReorderItem(BaseModel):
    id: str
    sortOrder: int

# --- Menu Items ---

class MenuItemCreate(BaseModel):
    id: Optional[str] = None
    sku: str
    barcode: Optional[str] = ""
    nameAr: str
    nameEn: Optional[str] = ""
    categoryId: str
    categoryName: Optional[str] = ""
    price: float
    cost: float = 0.0
    marginPercent: Optional[float] = 0.0
    kitchenStation: Optional[str] = "محطة التشغيل"
    isActive: bool = True
    description: Optional[str] = ""
    branches: Optional[List[str]] = Field(default_factory=lambda: ["كافة الفروع"])
    allergens: Optional[List[str]] = Field(default_factory=list)

class MenuItemUpdate(BaseModel):
    sku: Optional[str] = None
    barcode: Optional[str] = None
    nameAr: Optional[str] = None
    nameEn: Optional[str] = None
    categoryId: Optional[str] = None
    categoryName: Optional[str] = None
    price: Optional[float] = None
    cost: Optional[float] = None
    marginPercent: Optional[float] = None
    kitchenStation: Optional[str] = None
    isActive: Optional[bool] = None
    description: Optional[str] = None
    branches: Optional[List[str]] = None
    allergens: Optional[List[str]] = None

class MenuItemResponse(BaseModel):
    id: str
    sku: str
    barcode: str
    nameAr: str
    nameEn: str
    categoryId: str
    categoryName: str
    price: float
    cost: float
    marginPercent: float
    kitchenStation: str
    isActive: bool
    description: str
    branches: List[str]
    allergens: List[str]

# --- Menu Item Requests ---

class MenuItemRequestCreate(BaseModel):
    id: Optional[str] = None
    nameAr: str
    nameEn: Optional[str] = ""
    categoryId: Optional[str] = None
    categoryName: Optional[str] = None
    suggestedPrice: Optional[float] = None
    proposedPrice: Optional[float] = None
    suggestedCost: Optional[float] = None
    estimatedCost: Optional[float] = None
    requestedByUserId: Optional[str] = None
    branchId: Optional[str] = None
    reason: Optional[str] = ""
    notes: Optional[str] = ""
    kitchenStation: Optional[str] = None

class MenuItemRequestReview(BaseModel):
    reviewNotes: Optional[str] = ""
    status: Optional[str] = None
    categoryId: Optional[str] = None
    sku: Optional[str] = None
    barcode: Optional[str] = None
    kitchenStation: Optional[str] = None

class MenuItemRequestResponse(BaseModel):
    id: str
    requestNumber: str
    itemNameAr: str
    itemNameEn: str
    categoryId: Optional[str] = None
    categoryName: str = ""
    proposedPrice: float
    estimatedCost: float = 0.0
    branchName: str = ""
    requestedByName: str = ""
    requestDate: str
    status: str  # "pending", "approved", "rejected"
    reason: str = ""
    notes: str = ""
    createdMenuItemId: Optional[str] = None

# --- Standard API Response ---

class ApiResponse(BaseModel):
    success: bool = True
    data: Optional[Any] = None
    error: Optional[Any] = None
    message: Optional[str] = None
    meta: Optional[dict] = None
