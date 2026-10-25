import json
import time
import math
import uuid
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
import sqlite3
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, HTTPException, Depends, status
from ..database.connection import get_db
from ..schemas.menu_schemas import (
    MenuCategoryResponse,
    MenuCategoryCreate,
    MenuCategoryUpdate,
    CategoryReorderItem,
    MenuItemCreate,
    MenuItemUpdate,
    MenuItemResponse,
    MenuItemRequestCreate,
    MenuItemRequestReview,
    MenuItemRequestResponse,
    ApiResponse,
)
from .auth_router import get_current_user, get_current_ceo

router = APIRouter(prefix="/menu", tags=["Menu"])

def _row_to_menu_item(row, category_name: str = "") -> MenuItemResponse:
    allergens = []
    if row["allergens_json"]:
        try:
            allergens = json.loads(row["allergens_json"])
        except Exception:
            allergens = []
    
    return MenuItemResponse(
        id=row["id"],
        sku=row["sku"],
        barcode=row["barcode"] or "",
        nameAr=row["name_ar"],
        nameEn=row["name_en"] or "",
        categoryId=row["category_id"],
        categoryName=category_name,
        price=float(row["price"]),
        cost=float(row["cost"]),
        marginPercent=float(row["margin_percent"]),
        kitchenStation=row["station"] or "محطة التشغيل",
        isActive=bool(row["is_active"]),
        description=row["description_ar"] or "",
        branches=["كافة الفروع"],
        allergens=allergens,
    )

# =============================================================================
# 1. CATEGORIES ENDPOINTS
# =============================================================================

@router.get("/categories", response_model=ApiResponse)
def get_categories(current_user: Dict[str, Any] = Depends(get_current_user)):
    with get_db() as conn:
        cursor = conn.execute("""
            SELECT c.id, c.name_ar, c.name_en, c.sort_order, c.is_active,
                   COUNT(m.id) as items_count
            FROM menu_categories c
            LEFT JOIN menu_items m ON c.id = m.category_id AND m.is_active = 1
            WHERE c.is_active = 1
            GROUP BY c.id
            ORDER BY c.sort_order ASC
        """)
        rows = cursor.fetchall()
        categories = [
            MenuCategoryResponse(
                id=r["id"],
                nameAr=r["name_ar"],
                nameEn=r["name_en"],
                sortOrder=r["sort_order"],
                itemsCount=r["items_count"],
                isActive=bool(r["is_active"]),
            ).model_dump()
            for r in rows
        ]
        return ApiResponse(success=True, data=categories)

@router.post("/categories", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def create_category(
    payload: MenuCategoryCreate,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    cat_id = payload.id or f"cat_{int(time.time() * 1000)}"
    user_id = current_user.get("id")
    with get_db() as conn:
        existing = conn.execute("SELECT id FROM menu_categories WHERE id = ?", (cat_id,)).fetchone()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Category with id '{cat_id}' already exists",
            )
        conn.execute("""
            INSERT INTO menu_categories (id, name_ar, name_en, sort_order, is_active)
            VALUES (?, ?, ?, ?, ?)
        """, (
            cat_id, payload.nameAr, payload.nameEn or payload.nameAr,
            payload.sortOrder or 0, 1 if payload.isActive else 0
        ))
        conn.execute("""
            INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, new_values_json)
            VALUES (?, ?, 'CREATE_MENU_CATEGORY', 'menu_categories', ?, ?)
        """, (
            f"aud_{int(time.time() * 1000)}",
            user_id,
            cat_id,
            json.dumps(payload.model_dump(), ensure_ascii=False)
        ))
        row = conn.execute("SELECT * FROM menu_categories WHERE id = ?", (cat_id,)).fetchone()
        data = MenuCategoryResponse(
            id=row["id"],
            nameAr=row["name_ar"],
            nameEn=row["name_en"],
            sortOrder=row["sort_order"],
            itemsCount=0,
            isActive=bool(row["is_active"]),
        ).model_dump()
        return ApiResponse(success=True, data=data)

@router.put("/categories/reorder", response_model=ApiResponse)
def reorder_categories(
    payload: List[CategoryReorderItem],
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    user_id = current_user.get("id")
    with get_db() as conn:
        for item in payload:
            conn.execute(
                "UPDATE menu_categories SET sort_order = ? WHERE id = ?",
                (item.sortOrder, item.id)
            )
        conn.execute("""
            INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, new_values_json)
            VALUES (?, ?, 'REORDER_MENU_CATEGORIES', 'menu_categories', 'reorder', ?)
        """, (
            f"aud_{int(time.time() * 1000)}",
            user_id,
            json.dumps([i.model_dump() for i in payload], ensure_ascii=False)
        ))
        cursor = conn.execute("""
            SELECT c.id, c.name_ar, c.name_en, c.sort_order, c.is_active,
                   COUNT(m.id) as items_count
            FROM menu_categories c
            LEFT JOIN menu_items m ON c.id = m.category_id AND m.is_active = 1
            WHERE c.is_active = 1
            GROUP BY c.id
            ORDER BY c.sort_order ASC
        """)
        rows = cursor.fetchall()
        categories = [
            MenuCategoryResponse(
                id=r["id"],
                nameAr=r["name_ar"],
                nameEn=r["name_en"],
                sortOrder=r["sort_order"],
                itemsCount=r["items_count"],
                isActive=bool(r["is_active"]),
            ).model_dump()
            for r in rows
        ]
        return ApiResponse(success=True, data=categories)

@router.put("/categories/{category_id}", response_model=ApiResponse)
def update_category(
    category_id: str,
    payload: MenuCategoryUpdate,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    user_id = current_user.get("id")
    with get_db() as conn:
        row = conn.execute("SELECT * FROM menu_categories WHERE id = ?", (category_id,)).fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Category with id '{category_id}' not found",
            )
        old_values = dict(row)
        new_name_ar = payload.nameAr if payload.nameAr is not None else row["name_ar"]
        new_name_en = payload.nameEn if payload.nameEn is not None else row["name_en"]
        new_sort = payload.sortOrder if payload.sortOrder is not None else row["sort_order"]
        new_active = (1 if payload.isActive else 0) if payload.isActive is not None else row["is_active"]

        conn.execute("""
            UPDATE menu_categories
            SET name_ar = ?, name_en = ?, sort_order = ?, is_active = ?
            WHERE id = ?
        """, (new_name_ar, new_name_en, new_sort, new_active, category_id))

        conn.execute("""
            INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, old_values_json, new_values_json)
            VALUES (?, ?, 'UPDATE_MENU_CATEGORY', 'menu_categories', ?, ?, ?)
        """, (
            f"aud_{int(time.time() * 1000)}",
            user_id,
            category_id,
            json.dumps(old_values, ensure_ascii=False),
            json.dumps(payload.model_dump(exclude_unset=True), ensure_ascii=False)
        ))

        items_cnt = conn.execute("SELECT COUNT(*) FROM menu_items WHERE category_id = ? AND is_active = 1", (category_id,)).fetchone()[0]
        updated = conn.execute("SELECT * FROM menu_categories WHERE id = ?", (category_id,)).fetchone()
        return ApiResponse(
            success=True,
            data=MenuCategoryResponse(
                id=updated["id"],
                nameAr=updated["name_ar"],
                nameEn=updated["name_en"],
                sortOrder=updated["sort_order"],
                itemsCount=items_cnt,
                isActive=bool(updated["is_active"]),
            ).model_dump()
        )

@router.delete("/categories/{category_id}", response_model=ApiResponse)
def delete_category(
    category_id: str,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    user_id = current_user.get("id")
    with get_db() as conn:
        row = conn.execute("SELECT * FROM menu_categories WHERE id = ?", (category_id,)).fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Category with id '{category_id}' not found",
            )
        cnt = conn.execute("SELECT COUNT(*) FROM menu_items WHERE category_id = ?", (category_id,)).fetchone()[0]
        if cnt > 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot delete category '{category_id}': it contains {cnt} menu items",
            )
        conn.execute("DELETE FROM menu_categories WHERE id = ?", (category_id,))
        conn.execute("""
            INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, old_values_json)
            VALUES (?, ?, 'DELETE_MENU_CATEGORY', 'menu_categories', ?, ?)
        """, (
            f"aud_{int(time.time() * 1000)}",
            user_id,
            category_id,
            json.dumps(dict(row), ensure_ascii=False)
        ))
        return ApiResponse(success=True, data={"deleted_id": category_id})

# =============================================================================
# 2. MENU ITEMS ENDPOINTS
# =============================================================================

@router.get("/items", response_model=ApiResponse)
def get_menu_items(current_user: Dict[str, Any] = Depends(get_current_user)):
    with get_db() as conn:
        cursor = conn.execute("""
            SELECT m.*, c.name_ar as category_name
            FROM menu_items m
            LEFT JOIN menu_categories c ON m.category_id = c.id
            ORDER BY m.created_at ASC
        """)
        rows = cursor.fetchall()
        items = [_row_to_menu_item(r, r["category_name"] or "").model_dump() for r in rows]
        return ApiResponse(success=True, data=items, meta={"total_records": len(items)})

@router.get("/items/{item_id}", response_model=ApiResponse)
def get_menu_item_by_id(
    item_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    with get_db() as conn:
        cursor = conn.execute("""
            SELECT m.*, c.name_ar as category_name
            FROM menu_items m
            LEFT JOIN menu_categories c ON m.category_id = c.id
            WHERE m.id = ?
        """, (item_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Item with id '{item_id}' not found",
            )
        return ApiResponse(
            success=True,
            data=_row_to_menu_item(row, row["category_name"] or "").model_dump()
        )

@router.post("/items", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def create_menu_item(
    payload: MenuItemCreate,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    if payload.price is None or not math.isfinite(payload.price) or payload.price < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="سعر الصنف يجب أن يكون رقماً حقيقياً غير سالب (>= 0)",
        )
    if payload.cost is not None and (not math.isfinite(payload.cost) or payload.cost < 0):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="تكلفة الصنف يجب أن تكون رقماً حقيقياً غير سالب (>= 0)",
        )

    item_id = payload.id or f"item_{int(time.time() * 1000)}"
    user_id = current_user.get("id")
    margin_percent = payload.marginPercent
    if margin_percent == 0.0 and payload.price > 0:
        margin_percent = round(((payload.price - payload.cost) / payload.price) * 100, 2)
    
    allergens_json = json.dumps(payload.allergens or [], ensure_ascii=False)

    with get_db() as conn:
        # Check SKU uniqueness
        dup_cur = conn.execute("SELECT id FROM menu_items WHERE sku = ?", (payload.sku,))
        if dup_cur.fetchone():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Menu item with SKU '{payload.sku}' already exists",
            )

        # Check category existence (strict validation)
        cat_cur = conn.execute("SELECT name_ar FROM menu_categories WHERE id = ?", (payload.categoryId,))
        cat_row = cat_cur.fetchone()
        if not cat_row:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Category with id '{payload.categoryId}' does not exist",
            )
        category_name = cat_row["name_ar"]

        conn.execute("""
            INSERT INTO menu_items (
                id, category_id, sku, barcode, name_ar, name_en, description_ar,
                price, cost, margin_percent, station, is_active, allergens_json
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            item_id, payload.categoryId, payload.sku, payload.barcode or "",
            payload.nameAr, payload.nameEn or "", payload.description or "",
            payload.price, payload.cost, margin_percent, payload.kitchenStation or "محطة التشغيل",
            1 if payload.isActive else 0, allergens_json
        ))

        # Insert audit log
        conn.execute("""
            INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, new_values_json)
            VALUES (?, ?, 'CREATE_MENU_ITEM', 'menu_items', ?, ?)
        """, (
            f"aud_{int(time.time() * 1000)}",
            user_id,
            item_id,
            json.dumps(payload.model_dump(), ensure_ascii=False)
        ))

        # Re-fetch created
        cursor = conn.execute("""
            SELECT m.*, c.name_ar as category_name
            FROM menu_items m
            LEFT JOIN menu_categories c ON m.category_id = c.id
            WHERE m.id = ?
        """, (item_id,))
        row = cursor.fetchone()
        created_item = _row_to_menu_item(row, row["category_name"] or category_name).model_dump()
        return ApiResponse(success=True, data=created_item)

@router.put("/items/{item_id}", response_model=ApiResponse)
def update_menu_item(
    item_id: str,
    payload: MenuItemUpdate,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    if payload.price is not None and (not math.isfinite(payload.price) or payload.price < 0):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="سعر الصنف يجب أن يكون رقماً حقيقياً غير سالب (>= 0)",
        )
    if payload.cost is not None and (not math.isfinite(payload.cost) or payload.cost < 0):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="تكلفة الصنف يجب أن تكون رقماً حقيقياً غير سالب (>= 0)",
        )

    user_id = current_user.get("id")
    with get_db() as conn:
        cursor = conn.execute("SELECT * FROM menu_items WHERE id = ?", (item_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Item with id '{item_id}' not found",
            )
        
        old_values = dict(row)

        if payload.sku is not None and payload.sku != row["sku"]:
            dup_cur = conn.execute("SELECT id FROM menu_items WHERE sku = ? AND id != ?", (payload.sku, item_id))
            if dup_cur.fetchone():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Menu item with SKU '{payload.sku}' already exists",
                )

        if payload.categoryId is not None:
            cat_cur = conn.execute("SELECT name_ar FROM menu_categories WHERE id = ?", (payload.categoryId,))
            if not cat_cur.fetchone():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Category with id '{payload.categoryId}' does not exist",
                )

        old_price = float(row["price"])
        old_price_dec = Decimal(str(old_price)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

        price_changed = False
        if payload.price is not None:
            new_price_dec = Decimal(str(payload.price)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            if new_price_dec != old_price_dec:
                price_changed = True
                new_price = float(new_price_dec)
            else:
                new_price = float(old_price_dec)
        else:
            new_price = float(old_price_dec)

        new_sku = payload.sku if payload.sku is not None else row["sku"]
        new_barcode = payload.barcode if payload.barcode is not None else row["barcode"]
        new_name_ar = payload.nameAr if payload.nameAr is not None else row["name_ar"]
        new_name_en = payload.nameEn if payload.nameEn is not None else row["name_en"]
        new_cat_id = payload.categoryId if payload.categoryId is not None else row["category_id"]
        new_cost = payload.cost if payload.cost is not None else row["cost"]
        new_station = payload.kitchenStation if payload.kitchenStation is not None else row["station"]
        new_is_active = (1 if payload.isActive else 0) if payload.isActive is not None else row["is_active"]
        new_desc = payload.description if payload.description is not None else row["description_ar"]
        
        if payload.allergens is not None:
            new_allergens_json = json.dumps(payload.allergens, ensure_ascii=False)
        else:
            new_allergens_json = row["allergens_json"]

        margin_percent = round(((new_price - new_cost) / new_price) * 100, 2) if new_price > 0 else 0.0

        conn.execute("""
            UPDATE menu_items
            SET sku = ?, barcode = ?, name_ar = ?, name_en = ?, category_id = ?,
                price = ?, cost = ?, margin_percent = ?, station = ?, is_active = ?,
                description_ar = ?, allergens_json = ?, updated_at = datetime('now')
            WHERE id = ?
        """, (
            new_sku, new_barcode, new_name_ar, new_name_en, new_cat_id,
            new_price, new_cost, margin_percent, new_station, new_is_active,
            new_desc, new_allergens_json, item_id
        ))

        # Atomic Price History Recording for Manual Price Changes
        if price_changed:
            now_dt = datetime.now()
            today_str = now_dt.strftime("%Y-%m-%d")
            created_at_str = now_dt.strftime("%Y-%m-%d %H:%M:%S")
            hist_id = f"hist_{int(time.time() * 1000)}_{uuid.uuid4().hex[:6]}"
            actor_user_id = user_id or "usr_ceo"
            reason = f"تعديل يدوي مباشر لسعر الصنف من {float(old_price_dec)} إلى {new_price}"

            conn.execute("""
                INSERT INTO price_history (
                    id, menu_item_id, old_price, new_price, effective_date,
                    approved_by_user_id, reason, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                hist_id,
                item_id,
                float(old_price_dec),
                new_price,
                today_str,
                actor_user_id,
                reason,
                created_at_str,
            ))

        # Insert audit log
        conn.execute("""
            INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, old_values_json, new_values_json)
            VALUES (?, ?, 'UPDATE_MENU_ITEM', 'menu_items', ?, ?, ?)
        """, (
            f"aud_{int(time.time() * 1000)}",
            user_id,
            item_id,
            json.dumps({k: str(v) for k, v in old_values.items()}, ensure_ascii=False),
            json.dumps(payload.model_dump(exclude_unset=True), ensure_ascii=False)
        ))

        cursor = conn.execute("""
            SELECT m.*, c.name_ar as category_name
            FROM menu_items m
            LEFT JOIN menu_categories c ON m.category_id = c.id
            WHERE m.id = ?
        """, (item_id,))
        updated_row = cursor.fetchone()
        return ApiResponse(
            success=True,
            data=_row_to_menu_item(updated_row, updated_row["category_name"] or "").model_dump()
        )

@router.delete("/items/{item_id}", response_model=ApiResponse)
def delete_menu_item(
    item_id: str,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    user_id = current_user.get("id")
    with get_db() as conn:
        cursor = conn.execute("SELECT * FROM menu_items WHERE id = ?", (item_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Item with id '{item_id}' not found",
            )
        
        try:
            conn.execute("DELETE FROM menu_items WHERE id = ?", (item_id,))
            conn.execute("""
                INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, old_values_json)
                VALUES (?, ?, 'DELETE_MENU_ITEM', 'menu_items', ?, ?)
            """, (
                f"aud_{int(time.time() * 1000)}",
                user_id,
                item_id,
                json.dumps(dict(row), ensure_ascii=False)
            ))
            return ApiResponse(success=True, data={"deleted_id": item_id})
        except sqlite3.IntegrityError:
            # Foreign key constraint protection: safely deactivate instead
            conn.execute("UPDATE menu_items SET is_active = 0, updated_at = datetime('now') WHERE id = ?", (item_id,))
            conn.execute("""
                INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, old_values_json, new_values_json)
                VALUES (?, ?, 'DEACTIVATE_MENU_ITEM', 'menu_items', ?, ?, ?)
            """, (
                f"aud_{int(time.time() * 1000)}",
                user_id,
                item_id,
                json.dumps(dict(row), ensure_ascii=False),
                json.dumps({"is_active": 0, "reason": "foreign_key_references_exist"}, ensure_ascii=False)
            ))
            return ApiResponse(
                success=True,
                data={"deactivated_id": item_id, "message": "تم تعطيل الصنف لوجود ارتباطات تشغيلية سابقة"}
            )

# =============================================================================
# 3. MENU ITEM REQUESTS WORKFLOW (ONE TRANSACTION ATOMIC APPROVE + CAS)
# =============================================================================

@router.get("/requests", response_model=ApiResponse)
def get_menu_item_requests(current_user: Dict[str, Any] = Depends(get_current_user)):
    user_role = current_user.get("role")
    user_branch_id = current_user.get("branch_id")

    with get_db() as conn:
        query = """
            SELECT r.*,
                   COALESCE(u.full_name_ar, 'مستخدم النظام') as user_name,
                   COALESCE(b.name_ar, 'الفرع') as branch_name
            FROM menu_item_requests r
            LEFT JOIN users u ON r.requested_by_user_id = u.id
            LEFT JOIN branches b ON r.branch_id = b.id
        """
        params = []
        if user_role != "ceo":
            if not user_branch_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: الحساب غير مقترن بفرع محدد",
                )
            query += " WHERE r.branch_id = ?"
            params.append(user_branch_id)
        
        query += " ORDER BY r.created_at DESC"
        cursor = conn.execute(query, tuple(params))
        rows = cursor.fetchall()
        
        cat_map = {
            c["id"]: c["name_ar"]
            for c in conn.execute("SELECT id, name_ar FROM menu_categories").fetchall()
        }

        requests = []
        for r in rows:
            cat_id = None
            cat_name = ""
            reason = ""
            notes = r["review_notes"] or ""
            created_item_id = None
            if notes.strip().startswith("{") and notes.strip().endswith("}"):
                try:
                    meta = json.loads(notes)
                    cat_id = meta.get("category_id")
                    cat_name = meta.get("category_name") or cat_map.get(cat_id, "")
                    reason = meta.get("reason", "")
                    notes = meta.get("notes") or meta.get("review_notes", "")
                    created_item_id = meta.get("created_item_id")
                except Exception:
                    pass
            if not cat_name and cat_id in cat_map:
                cat_name = cat_map[cat_id]
            if not cat_name:
                cat_name = "عام"

            requests.append(MenuItemRequestResponse(
                id=r["id"],
                requestNumber=f"REQ-{r['id'][:8]}",
                itemNameAr=r["name_ar"],
                itemNameEn=r["name_en"] or "",
                categoryId=cat_id,
                categoryName=cat_name,
                proposedPrice=float(r["suggested_price"]),
                estimatedCost=float(r["suggested_cost"]),
                branchName=r["branch_name"],
                requestedByName=r["user_name"],
                requestDate=r["created_at"],
                status=r["status"],
                reason=reason,
                notes=notes,
                createdMenuItemId=created_item_id,
            ).model_dump())
        return ApiResponse(success=True, data=requests, meta={"total_records": len(requests)})

@router.get("/requests/{request_id}", response_model=ApiResponse)
def get_menu_item_request_by_id(
    request_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    with get_db() as conn:
        cursor = conn.execute("""
            SELECT r.*,
                   COALESCE(u.full_name_ar, 'مستخدم النظام') as user_name,
                   COALESCE(b.name_ar, 'الفرع') as branch_name
            FROM menu_item_requests r
            LEFT JOIN users u ON r.requested_by_user_id = u.id
            LEFT JOIN branches b ON r.branch_id = b.id
            WHERE r.id = ?
        """, (request_id,))
        r = cursor.fetchone()
        if not r:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Request with id '{request_id}' not found",
            )
        
        user_role = current_user.get("role")
        user_branch_id = current_user.get("branch_id")
        if user_role != "ceo" and r["branch_id"] != user_branch_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكنك الاطلاع على طلبات تخص فروعاً أخرى",
            )
        
        cat_map = {
            c["id"]: c["name_ar"]
            for c in conn.execute("SELECT id, name_ar FROM menu_categories").fetchall()
        }
        cat_id = None
        cat_name = ""
        reason = ""
        notes = r["review_notes"] or ""
        created_item_id = None
        if notes.strip().startswith("{") and notes.strip().endswith("}"):
            try:
                meta = json.loads(notes)
                cat_id = meta.get("category_id")
                cat_name = meta.get("category_name") or cat_map.get(cat_id, "")
                reason = meta.get("reason", "")
                notes = meta.get("notes") or meta.get("review_notes", "")
                created_item_id = meta.get("created_item_id")
            except Exception:
                pass
        if not cat_name and cat_id in cat_map:
            cat_name = cat_map[cat_id]
        if not cat_name:
            cat_name = "عام"

        req_data = MenuItemRequestResponse(
            id=r["id"],
            requestNumber=f"REQ-{r['id'][:8]}",
            itemNameAr=r["name_ar"],
            itemNameEn=r["name_en"] or "",
            categoryId=cat_id,
            categoryName=cat_name,
            proposedPrice=float(r["suggested_price"]),
            estimatedCost=float(r["suggested_cost"]),
            branchName=r["branch_name"],
            requestedByName=r["user_name"],
            requestDate=r["created_at"],
            status=r["status"],
            reason=reason,
            notes=notes,
            createdMenuItemId=created_item_id,
        ).model_dump()
        return ApiResponse(success=True, data=req_data)

@router.post("/requests", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def create_menu_item_request(
    payload: MenuItemRequestCreate,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_role = current_user.get("role")
    if user_role not in ("ceo", "branch_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: تقديم طلبات الأصناف مقتصر على مديري الفروع والمدير التنفيذي",
        )

    user_id = current_user.get("id")
    req_id = payload.id or f"req_{int(time.time() * 1000)}"

    with get_db() as conn:
        # Determine verified branch
        if user_role == "ceo":
            branch_id = payload.branchId
            if not branch_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="يجب تحديد الفرع المطلوب لتقديم الطلب من الإدارة التنفيذية",
                )
            br_row = conn.execute("SELECT id, name_ar FROM branches WHERE id = ?", (branch_id,)).fetchone()
            if not br_row:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"الفرع '{branch_id}' غير مسجل في النظام",
                )
        else:
            branch_id = current_user.get("branch_id")
            if not branch_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="حساب مدير الفرع غير مقترن بفرع تشغيلي في النظام",
                )
            br_row = conn.execute("SELECT id, name_ar FROM branches WHERE id = ?", (branch_id,)).fetchone()
            if not br_row:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"فرع الحساب '{branch_id}' غير موجود في النظام",
                )

        # Validate Category against real DB choices
        cat_id = payload.categoryId
        cat_name = payload.categoryName
        cat_row = None
        if cat_id:
            cat_row = conn.execute(
                "SELECT id, name_ar FROM menu_categories WHERE id = ? AND is_active = 1",
                (cat_id,),
            ).fetchone()
        elif cat_name and cat_name != "عام":
            cat_row = conn.execute(
                "SELECT id, name_ar FROM menu_categories WHERE (name_ar = ? OR name_en = ?) AND is_active = 1",
                (cat_name, cat_name),
            ).fetchone()
        
        if not cat_row:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="يجب اختيار فئة صالحة ومعتمدة وموجودة في قائمة فئات المنيو",
            )
        
        validated_cat_id = cat_row["id"]
        validated_cat_name = cat_row["name_ar"]

        price = payload.proposedPrice if payload.proposedPrice is not None else (payload.suggestedPrice if payload.suggestedPrice is not None else 0.0)
        cost = payload.estimatedCost if payload.estimatedCost is not None else (payload.suggestedCost if payload.suggestedCost is not None else 0.0)
        if price <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="يجب تحديد سعر مقترح أكبر من صفر",
            )

        meta_notes = json.dumps({
            "category_id": validated_cat_id,
            "category_name": validated_cat_name,
            "kitchen_station": payload.kitchenStation or "محطة التشغيل",
            "reason": payload.reason or "",
            "notes": payload.notes or "",
        }, ensure_ascii=False)

        conn.execute("""
            INSERT INTO menu_item_requests (
                id, requested_by_user_id, branch_id, name_ar, name_en,
                suggested_price, suggested_cost, status, review_notes
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?)
        """, (
            req_id, user_id, branch_id, payload.nameAr,
            payload.nameEn or payload.nameAr, price, cost, meta_notes
        ))

        conn.execute("""
            INSERT INTO audit_logs (id, user_id, branch_id, action, entity_type, entity_id, new_values_json)
            VALUES (?, ?, ?, 'CREATE_MENU_ITEM_REQUEST', 'menu_item_requests', ?, ?)
        """, (
            f"aud_{int(time.time() * 1000)}",
            user_id,
            branch_id,
            req_id,
            json.dumps({
                "id": req_id,
                "name_ar": payload.nameAr,
                "category_id": validated_cat_id,
                "proposed_price": price,
                "estimated_cost": cost,
                "user_id": user_id,
                "branch_id": branch_id,
            }, ensure_ascii=False)
        ))

        cursor = conn.execute("""
            SELECT r.*,
                   COALESCE(u.full_name_ar, 'مستخدم النظام') as user_name,
                   COALESCE(b.name_ar, 'الفرع') as branch_name
            FROM menu_item_requests r
            LEFT JOIN users u ON r.requested_by_user_id = u.id
            LEFT JOIN branches b ON r.branch_id = b.id
            WHERE r.id = ?
        """, (req_id,))
        r = cursor.fetchone()
        req_data = MenuItemRequestResponse(
            id=r["id"],
            requestNumber=f"REQ-{r['id'][:8]}",
            itemNameAr=r["name_ar"],
            itemNameEn=r["name_en"] or "",
            categoryId=validated_cat_id,
            categoryName=validated_cat_name,
            proposedPrice=float(r["suggested_price"]),
            estimatedCost=float(r["suggested_cost"]),
            branchName=r["branch_name"],
            requestedByName=r["user_name"],
            requestDate=r["created_at"],
            status=r["status"],
            reason=payload.reason or "",
            notes=payload.notes or "",
        ).model_dump()
        return ApiResponse(success=True, data=req_data)

@router.post("/requests/{request_id}/approve", response_model=ApiResponse)
def approve_menu_item_request(
    request_id: str,
    payload: Optional[MenuItemRequestReview] = None,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    ceo_id = current_user.get("id")

    with get_db() as conn:
        # 1. Fetch current request
        row = conn.execute("SELECT * FROM menu_item_requests WHERE id = ?", (request_id,)).fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"طلب الصنف '{request_id}' غير موجود",
            )
        
        # 2. Reject duplicate review; guarded CAS check
        if row["status"] != "pending":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"الطلب تمت مراجعته مسبقاً (الحالة الحالية: '{row['status']}'). تم رفض إعادة المراجعة.",
            )
        
        # 3. Validated real category selected/in request
        cat_id = payload.categoryId if (payload and payload.categoryId) else None
        kitchen_station = payload.kitchenStation if (payload and payload.kitchenStation) else None
        prev_meta = {}
        if row["review_notes"] and row["review_notes"].strip().startswith("{"):
            try:
                prev_meta = json.loads(row["review_notes"])
                if not cat_id:
                    cat_id = prev_meta.get("category_id")
                if not kitchen_station:
                    kitchen_station = prev_meta.get("kitchen_station")
            except Exception:
                pass
        
        if not cat_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="يجب تحديد فئة صالحة ومعتمدة للصنف المطلوب اعتماده",
            )
        
        cat_row = conn.execute(
            "SELECT id, name_ar FROM menu_categories WHERE id = ? AND is_active = 1",
            (cat_id,),
        ).fetchone()
        if not cat_row:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"الفئة '{cat_id}' غير موجودة أو غير نشطة في النظام",
            )
        category_name = cat_row["name_ar"]

        # 4. Prepare new menu item attributes with stable real sku/barcode
        item_id = f"item_{request_id}"
        sku = (payload.sku if payload and payload.sku else None) or f"REQ-{request_id}"
        dup_sku = conn.execute("SELECT id FROM menu_items WHERE sku = ?", (sku,)).fetchone()
        if dup_sku and dup_sku["id"] != item_id:
            sku = f"REQ-{request_id}-{int(time.time() * 1000) % 10000}"

        barcode = (payload.barcode if payload and payload.barcode else None) or f"6223{abs(hash(request_id)) % 100000000:08d}"
        name_ar = row["name_ar"]
        name_en = row["name_en"] or row["name_ar"]
        price = float(row["suggested_price"])
        cost = float(row["suggested_cost"])
        margin_percent = round(((price - cost) / price) * 100, 2) if price > 0 else 0.0
        station = kitchen_station or "محطة التشغيل"
        desc = f"صنف معتمد رسمياً بموجب طلب رقم {request_id}"
        review_notes_text = (payload.reviewNotes if payload and payload.reviewNotes else "معتمد من الإدارة التنفيذية")

        new_meta = {
            **prev_meta,
            "category_id": cat_id,
            "category_name": category_name,
            "created_item_id": item_id,
            "review_notes": review_notes_text,
            "approved_by_user_id": ceo_id,
        }

        # 5. CAS Update: status must still be 'pending'
        cas_cur = conn.execute("""
            UPDATE menu_item_requests
            SET status = 'approved', review_notes = ?
            WHERE id = ? AND status = 'pending'
        """, (json.dumps(new_meta, ensure_ascii=False), request_id))
        
        if cas_cur.rowcount == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="فشل اعتماد الطلب: تغيرت حالة الطلب بواسطة عملية متزامنة أخرى",
            )
        
        # 6. Insert exactly ONE menu_item with linkage
        existing_item = conn.execute("SELECT id FROM menu_items WHERE id = ?", (item_id,)).fetchone()
        if existing_item:
            conn.execute("""
                UPDATE menu_items
                SET sku = ?, barcode = ?, name_ar = ?, name_en = ?, category_id = ?,
                    price = ?, cost = ?, margin_percent = ?, station = ?, is_active = 1,
                    description_ar = ?, updated_at = datetime('now')
                WHERE id = ?
            """, (
                sku, barcode, name_ar, name_en, cat_id,
                price, cost, margin_percent, station, desc, item_id
            ))
        else:
            conn.execute("""
                INSERT INTO menu_items (
                    id, category_id, sku, barcode, name_ar, name_en, description_ar,
                    price, cost, margin_percent, station, is_active, allergens_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, '[]')
            """, (
                item_id, cat_id, sku, barcode, name_ar, name_en, desc,
                price, cost, margin_percent, station
            ))

        # 7. Audit linkage
        conn.execute("""
            INSERT INTO audit_logs (id, user_id, branch_id, action, entity_type, entity_id, new_values_json)
            VALUES (?, ?, ?, 'APPROVE_MENU_ITEM_REQUEST', 'menu_item_requests', ?, ?)
        """, (
            f"aud_{int(time.time() * 1000)}",
            ceo_id,
            row["branch_id"],
            request_id,
            json.dumps({
                "request_id": request_id,
                "status": "approved",
                "created_item_id": item_id,
                "category_id": cat_id,
                "review_notes": review_notes_text,
            }, ensure_ascii=False)
        ))

        conn.execute("""
            INSERT INTO audit_logs (id, user_id, branch_id, action, entity_type, entity_id, new_values_json)
            VALUES (?, ?, ?, 'CREATE_MENU_ITEM', 'menu_items', ?, ?)
        """, (
            f"aud_{int(time.time() * 1000) + 1}",
            ceo_id,
            row["branch_id"],
            item_id,
            json.dumps({
                "id": item_id,
                "sku": sku,
                "name_ar": name_ar,
                "category_id": cat_id,
                "from_request_id": request_id,
            }, ensure_ascii=False)
        ))

        # 8. Re-query updated row
        updated = conn.execute("""
            SELECT r.*,
                   COALESCE(u.full_name_ar, 'مستخدم النظام') as user_name,
                   COALESCE(b.name_ar, 'الفرع') as branch_name
            FROM menu_item_requests r
            LEFT JOIN users u ON r.requested_by_user_id = u.id
            LEFT JOIN branches b ON r.branch_id = b.id
            WHERE r.id = ?
        """, (request_id,)).fetchone()

        return ApiResponse(
            success=True,
            data=MenuItemRequestResponse(
                id=updated["id"],
                requestNumber=f"REQ-{updated['id'][:8]}",
                itemNameAr=updated["name_ar"],
                itemNameEn=updated["name_en"] or "",
                categoryId=cat_id,
                categoryName=category_name,
                proposedPrice=float(updated["suggested_price"]),
                estimatedCost=float(updated["suggested_cost"]),
                branchName=updated["branch_name"],
                requestedByName=updated["user_name"],
                requestDate=updated["created_at"],
                status=updated["status"],
                reason=prev_meta.get("reason", ""),
                notes=review_notes_text,
                createdMenuItemId=item_id,
            ).model_dump(),
            message="تم اعتماد الطلب وإدراج الصنف في قائمة الطعام بنجاح",
        )

@router.post("/requests/{request_id}/reject", response_model=ApiResponse)
def reject_menu_item_request(
    request_id: str,
    payload: Optional[MenuItemRequestReview] = None,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    ceo_id = current_user.get("id")
    review_notes = payload.reviewNotes if payload and payload.reviewNotes else "مرفوض من الإدارة التنفيذية"
    with get_db() as conn:
        row = conn.execute("SELECT * FROM menu_item_requests WHERE id = ?", (request_id,)).fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Request with id '{request_id}' not found",
            )
        
        # Guarded CAS check
        if row["status"] != "pending":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"الطلب تمت مراجعته مسبقاً (الحالة الحالية: '{row['status']}'). تم رفض إعادة المراجعة.",
            )

        cas_cur = conn.execute("""
            UPDATE menu_item_requests
            SET status = 'rejected', review_notes = ?
            WHERE id = ? AND status = 'pending'
        """, (review_notes, request_id))
        if cas_cur.rowcount == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="فشل رفض الطلب: تغيرت حالة الطلب بالتزامن مع عملية أخرى",
            )

        conn.execute("""
            INSERT INTO audit_logs (id, user_id, branch_id, action, entity_type, entity_id, old_values_json, new_values_json)
            VALUES (?, ?, ?, 'REJECT_MENU_ITEM_REQUEST', 'menu_item_requests', ?, ?, ?)
        """, (
            f"aud_{int(time.time() * 1000)}",
            ceo_id,
            row["branch_id"],
            request_id,
            json.dumps({"status": row["status"]}, ensure_ascii=False),
            json.dumps({"status": "rejected", "review_notes": review_notes}, ensure_ascii=False)
        ))

        updated = conn.execute("""
            SELECT r.*,
                   COALESCE(u.full_name_ar, 'مستخدم النظام') as user_name,
                   COALESCE(b.name_ar, 'الفرع') as branch_name
            FROM menu_item_requests r
            LEFT JOIN users u ON r.requested_by_user_id = u.id
            LEFT JOIN branches b ON r.branch_id = b.id
            WHERE r.id = ?
        """, (request_id,)).fetchone()

        cat_map = {
            c["id"]: c["name_ar"]
            for c in conn.execute("SELECT id, name_ar FROM menu_categories").fetchall()
        }
        prev_meta = {}
        cat_id = None
        cat_name = ""
        reason = ""
        if row["review_notes"] and row["review_notes"].strip().startswith("{"):
            try:
                prev_meta = json.loads(row["review_notes"])
                cat_id = prev_meta.get("category_id")
                cat_name = prev_meta.get("category_name") or cat_map.get(cat_id, "")
                reason = prev_meta.get("reason", "")
            except Exception:
                pass

        return ApiResponse(
            success=True,
            data=MenuItemRequestResponse(
                id=updated["id"],
                requestNumber=f"REQ-{updated['id'][:8]}",
                itemNameAr=updated["name_ar"],
                itemNameEn=updated["name_en"] or "",
                categoryId=cat_id,
                categoryName=cat_name or "عام",
                proposedPrice=float(updated["suggested_price"]),
                estimatedCost=float(updated["suggested_cost"]),
                branchName=updated["branch_name"],
                requestedByName=updated["user_name"],
                requestDate=updated["created_at"],
                status=updated["status"],
                reason=reason,
                notes=review_notes,
            ).model_dump()
        )
