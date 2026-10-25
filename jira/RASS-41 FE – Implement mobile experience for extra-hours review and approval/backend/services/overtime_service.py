import json
import math
import re
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple
from fastapi import HTTPException, status

from ..database.connection import get_db
from ..schemas.overtime_schemas import (
    FinancialImpactSummary,
    OvertimeRecordApprove,
    OvertimeRecordCreate,
    OvertimeRecordResponse,
    OvertimeRecordReview,
)

DEFAULT_EMPLOYEES = [
    {
        "id": "emp_01",
        "branch_id": "br_01",
        "first_name_ar": "أحمد محمود",
        "last_name_ar": "سالم",
        "job_title": "مشرف صالة • محطة الخدمة 1",
        "phone": "01011112233",
        "national_id": "1084",
        "wage_type": "monthly",
        "base_salary": 8000.0,
        "hourly_rate": 45.0,
        "hire_date": "2023-01-15",
    },
    {
        "id": "emp_02",
        "branch_id": "br_01",
        "first_name_ar": "مصطفى خالد",
        "last_name_ar": "عثمان",
        "job_title": "طاهي خط ساخن • المطبخ الساخن",
        "phone": "01022223344",
        "national_id": "1052",
        "wage_type": "monthly",
        "base_salary": 7500.0,
        "hourly_rate": 42.0,
        "hire_date": "2023-02-01",
    },
    {
        "id": "emp_03",
        "branch_id": "br_01",
        "first_name_ar": "سارة محمود",
        "last_name_ar": "إبراهيم",
        "job_title": "مساعد بار ومشروبات • محطة المشروبات",
        "phone": "01033334455",
        "national_id": "1060",
        "wage_type": "hourly",
        "base_salary": 6000.0,
        "hourly_rate": 35.0,
        "hire_date": "2023-03-10",
    },
    {
        "id": "emp_04",
        "branch_id": "br_01",
        "first_name_ar": "طارق زياد",
        "last_name_ar": "النجار",
        "job_title": "مساعد شيف • التجهيز والإعداد",
        "phone": "01044445566",
        "national_id": "1099",
        "wage_type": "monthly",
        "base_salary": 6500.0,
        "hourly_rate": 40.0,
        "hire_date": "2023-04-05",
    },
    {
        "id": "emp_05",
        "branch_id": "br_01",
        "first_name_ar": "أحمد نبيل",
        "last_name_ar": "رضوان",
        "job_title": "كابتن صالة • خدمة الصالة الرئيسية",
        "phone": "01055556677",
        "national_id": "1074",
        "wage_type": "monthly",
        "base_salary": 7000.0,
        "hourly_rate": 38.0,
        "hire_date": "2023-05-12",
    },
]

DEFAULT_OVERTIME = [
    {
        "id": "ot_01",
        "employee_id": "emp_02",
        "branch_id": "br_01",
        "date": "2024-04-16",
        "hours": 3.0,
        "rate_multiplier": 1.5,
        "calculated_amount": 120.0,
        "reason": "بصمة خروج متأخرة 3 ساعات (تغطية ذروة العشاء والطلبات المزدحمة)",
        "status": "pending_review",
        "approved_by_user_id": None,
        "decision_reason": None,
    },
    {
        "id": "ot_02",
        "employee_id": "emp_05",
        "branch_id": "br_01",
        "date": "2024-04-16",
        "hours": 2.0,
        "rate_multiplier": 1.5,
        "calculated_amount": 76.0,
        "reason": "تجهيز صالة كبار الزوار وحجز مناسبة خاصة",
        "status": "pending_review",
        "approved_by_user_id": None,
        "decision_reason": None,
    },
    {
        "id": "ot_03",
        "employee_id": "emp_03",
        "branch_id": "br_01",
        "date": "2024-04-15",
        "hours": 1.5,
        "rate_multiplier": 1.5,
        "calculated_amount": 67.5,
        "reason": "جرد مستودع المشروبات الأسبوعي",
        "status": "approved",
        "approved_by_user_id": "usr_bm1",
        "decision_reason": "معتمد ومطابق لجرد الأسبوع",
    },
]

ARABIC_MONTHS = {
    "يناير": 1,
    "فبراير": 2,
    "مارس": 3,
    "أبريل": 4,
    "ابريل": 4,
    "مايو": 5,
    "يونيو": 6,
    "يوليو": 7,
    "أغسطس": 8,
    "اغسطس": 8,
    "سبتمبر": 9,
    "أكتوبر": 10,
    "اكتوبر": 10,
    "نوفمبر": 11,
    "ديسمبر": 12,
}


def parse_period_from_date(date_str: Optional[str]) -> Tuple[int, int]:
    """Parse year and month from ISO date string or Arabic formatted date."""
    now = datetime.now()
    if not date_str:
        return now.year, now.month

    # Check ISO format: 2024-04-16
    iso_match = re.search(r"(\d{4})[-/](\d{1,2})[-/](\d{1,2})", date_str)
    if iso_match:
        year = int(iso_match.group(1))
        month = int(iso_match.group(2))
        return year, month

    # Check reversed date: 16-04-2024
    rev_match = re.search(r"(\d{1,2})[-/](\d{1,2})[-/](\d{4})", date_str)
    if rev_match:
        month = int(rev_match.group(2))
        year = int(rev_match.group(3))
        return year, month

    # Check Arabic date text, e.g. "16 أبريل 2024"
    year_match = re.search(r"\b(20\d\d)\b", date_str)
    year = int(year_match.group(1)) if year_match else now.year
    for ar_month_name, m_num in ARABIC_MONTHS.items():
        if ar_month_name in date_str:
            return year, m_num

    return now.year, now.month


def ensure_seed_data(conn) -> None:
    """Ensure baseline employees and overtime records exist in SQLite."""
    # Seed employees if not present
    for emp in DEFAULT_EMPLOYEES:
        conn.execute(
            """
            INSERT OR IGNORE INTO employees (
                id, branch_id, first_name_ar, last_name_ar, job_title,
                phone, national_id, wage_type, base_salary, hourly_rate,
                hire_date, is_active
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
            """,
            (
                emp["id"],
                emp["branch_id"],
                emp["first_name_ar"],
                emp["last_name_ar"],
                emp["job_title"],
                emp["phone"],
                emp["national_id"],
                emp["wage_type"],
                emp["base_salary"],
                emp["hourly_rate"],
                emp["hire_date"],
            ),
        )

    # Seed overtime records if count is 0
    ot_cur = conn.execute("SELECT COUNT(*) FROM overtime_records")
    if ot_cur.fetchone()[0] == 0:
        for ot in DEFAULT_OVERTIME:
            conn.execute(
                """
                INSERT OR IGNORE INTO overtime_records (
                    id, employee_id, branch_id, date, hours,
                    rate_multiplier, calculated_amount, reason, status,
                    approved_by_user_id, decision_reason, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
                """,
                (
                    ot["id"],
                    ot["employee_id"],
                    ot["branch_id"],
                    ot["date"],
                    ot["hours"],
                    ot["rate_multiplier"],
                    ot["calculated_amount"],
                    ot["reason"],
                    ot["status"],
                    ot["approved_by_user_id"],
                    ot["decision_reason"],
                ),
            )


def format_overtime_row(row) -> OvertimeRecordResponse:
    keys = row.keys()
    first_name = row["first_name_ar"] if "first_name_ar" in keys and row["first_name_ar"] else ""
    last_name = row["last_name_ar"] if "last_name_ar" in keys and row["last_name_ar"] else ""
    emp_name = f"{first_name} {last_name}".strip() or row["employee_id"]

    national_id = row["national_id"] if "national_id" in keys and row["national_id"] else row["employee_id"]
    job_title = row["job_title"] if "job_title" in keys and row["job_title"] else "طاهي خط ساخن"
    branch_name = row["branch_name"] if "branch_name" in keys and row["branch_name"] else "الفرع الرئيسي - وسط البلد"
    approver_name = row["approver_name"] if "approver_name" in keys else None

    reason = row["reason"] or ""
    trigger = "fingerprint" if "بصمة" in reason else "managerRequest"
    hours = float(row["hours"])
    time_range = f"عمل إضافي {hours:g} ساعة"

    return OvertimeRecordResponse(
        id=str(row["id"]),
        employeeId=str(row["employee_id"]),
        employeeName=emp_name,
        employeeCode=str(national_id),
        role=job_title,
        branchId=str(row["branch_id"]),
        branchName=branch_name,
        date=str(row["date"]),
        hours=hours,
        rateMultiplier=float(row["rate_multiplier"]),
        calculatedAmount=float(row["calculated_amount"]),
        overtimePay=float(row["calculated_amount"]),
        timeRange=time_range,
        reason=reason,
        trigger=trigger,
        status=str(row["status"]),
        approvedByUserId=str(row["approved_by_user_id"]) if row["approved_by_user_id"] else None,
        approvedByName=str(approver_name) if approver_name else None,
        decisionReason=str(row["decision_reason"]) if row["decision_reason"] else None,
        createdAt=str(row["created_at"]) if "created_at" in keys and row["created_at"] else datetime.now().isoformat(),
    )


class OvertimeService:
    @staticmethod
    def get_overtime_list(
        status: Optional[str] = None,
        employee_id: Optional[str] = None,
        branch_id: Optional[str] = None,
    ) -> List[OvertimeRecordResponse]:
        """Fetch list of overtime records with joins on employee, branch, and approver."""
        with get_db() as conn:
            query = """
                SELECT o.*,
                       e.first_name_ar, e.last_name_ar, e.national_id, e.job_title,
                       b.name_ar AS branch_name,
                       u.full_name_ar AS approver_name
                FROM overtime_records o
                LEFT JOIN employees e ON o.employee_id = e.id
                LEFT JOIN branches b ON o.branch_id = b.id
                LEFT JOIN users u ON o.approved_by_user_id = u.id
                WHERE 1=1
            """
            params: List[Any] = []

            if status:
                normalized_status = status.lower()
                if normalized_status in ("pending", "pending_review"):
                    query += " AND o.status = 'pending_review'"
                elif normalized_status == "approved":
                    query += " AND o.status = 'approved'"
                elif normalized_status == "rejected":
                    query += " AND o.status = 'rejected'"
                else:
                    query += " AND o.status = ?"
                    params.append(status)

            if employee_id:
                query += " AND (o.employee_id = ? OR e.national_id = ?)"
                params.extend([employee_id, employee_id])

            if branch_id:
                query += " AND o.branch_id = ?"
                params.append(branch_id)

            query += " ORDER BY o.date DESC, o.created_at DESC"
            cursor = conn.execute(query, params)
            rows = cursor.fetchall()
            return [format_overtime_row(r) for r in rows]

    @staticmethod
    def get_overtime_by_id(record_id: str) -> Optional[OvertimeRecordResponse]:
        """Fetch single overtime record by ID."""
        with get_db() as conn:
            cursor = conn.execute(
                """
                SELECT o.*,
                       e.first_name_ar, e.last_name_ar, e.national_id, e.job_title,
                       b.name_ar AS branch_name,
                       u.full_name_ar AS approver_name
                FROM overtime_records o
                LEFT JOIN employees e ON o.employee_id = e.id
                LEFT JOIN branches b ON o.branch_id = b.id
                LEFT JOIN users u ON o.approved_by_user_id = u.id
                WHERE o.id = ?
                """,
                (record_id,),
            )
            row = cursor.fetchone()
            if not row:
                return None
            return format_overtime_row(row)

    @staticmethod
    def create_overtime_record(
        payload: OvertimeRecordCreate,
        current_user_id: Optional[str] = None,
    ) -> OvertimeRecordResponse:
        """Create new overtime request and record in SQLite and audit log."""
        with get_db() as conn:
            ensure_seed_data(conn)
            raw_emp_id = payload.resolved_employee_id()
            if not raw_emp_id:
                raise ValueError("employee_id مطلوب لإنشاء طلب الساعات الإضافية")

            # Look up employee by ID or national_id
            emp_cur = conn.execute(
                "SELECT id, branch_id, hourly_rate, wage_type, base_salary, overtime_rate FROM employees WHERE id = ? OR national_id = ?",
                (raw_emp_id, raw_emp_id),
            )
            emp_row = emp_cur.fetchone()

            if not emp_row:
                # HR002: Unknown employee reference must 404, no automatic INSERT 6000 employee
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Employee with ID '{raw_emp_id}' not found",
                )

            emp_id = emp_row["id"]
            branch_id = payload.branch_id or emp_row["branch_id"] or "br_01"

            # Derive authoritative DB hourly rate (HR001: payload cannot dictate pay)
            db_rate = float(emp_row["hourly_rate"] or 0.0)
            if db_rate <= 0:
                if emp_row["overtime_rate"] and float(emp_row["overtime_rate"]) > 0:
                    db_rate = float(emp_row["overtime_rate"])
                elif emp_row["wage_type"] == "hourly" and float(emp_row["base_salary"] or 0) > 0:
                    db_rate = float(emp_row["base_salary"])
                elif float(emp_row["base_salary"] or 0) > 0:
                    db_rate = round(float(emp_row["base_salary"]) / 240.0, 2)
                else:
                    db_rate = 42.0

            record_id = payload.id or f"ot_{int(datetime.now().timestamp() * 1000)}"
            date_val = payload.date or datetime.now().strftime("%Y-%m-%d")
            hours = float(payload.hours)
            if not math.isfinite(hours) or hours <= 0 or hours > 24:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="ساعات العمل الإضافي يجب أن تكون رقماً حقيقياً موجباً بين 0 و 24",
                )
            rate_multiplier = payload.resolved_multiplier()
            if not math.isfinite(rate_multiplier) or rate_multiplier < 1.0 or rate_multiplier > 5.0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="معامل الأجر الإضافي يجب أن يكون رقماً حقيقياً بين 1.0 و 5.0",
                )
            if not math.isfinite(db_rate) or db_rate <= 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="أجر الساعة المستخرج من قاعدة البيانات غير صالح",
                )

            # Guard concurrent duplicate inserts via SQLite BEGIN IMMEDIATE
            try:
                conn.execute("BEGIN IMMEDIATE")
            except Exception:
                pass

            # HR004: Enforce exact employee/date/hours claim identity NOT free-text reason.
            # Changing reason string MUST NOT bypass duplicate detection.
            # Legitimate disjoint periods with different hours (e.g. 2h morning vs 1.5h evening)
            # are preserved and not arbitrarily blocked.
            dup_cur = conn.execute(
                """
                SELECT id FROM overtime_records
                WHERE employee_id = ? AND date = ? AND hours = ?
                  AND status IN ('pending_review', 'approved')
                """,
                (emp_id, date_val, hours),
            )
            if dup_cur.fetchone():
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Duplicate overtime record: an active overtime entry for employee '{emp_id}' on {date_val} with {hours} hours already exists",
                )

            # HR001: Canonical money server compute (trusted hours * DB actual rate * validated multiplier)
            # Never trust caller payload.calculated_amount (e.g. 999999.0)
            calculated_amount = round(hours * db_rate * rate_multiplier, 2)

            status_val = payload.status or "pending_review"

            conn.execute(
                """
                INSERT INTO overtime_records (
                    id, employee_id, branch_id, date, hours,
                    rate_multiplier, calculated_amount, reason, status,
                    created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
                """,
                (
                    record_id,
                    emp_id,
                    branch_id,
                    date_val,
                    hours,
                    rate_multiplier,
                    calculated_amount,
                    payload.reason,
                    status_val,
                ),
            )

            # Insert audit log
            audit_id = f"aud_{uuid.uuid4().hex[:12]}"
            conn.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id,
                    new_values_json, timestamp
                ) VALUES (?, ?, ?, 'CREATE', 'overtime_record', ?, ?, datetime('now'))
                """,
                (
                    audit_id,
                    current_user_id or "usr_bm1",
                    branch_id,
                    record_id,
                    json.dumps(
                        {
                            "id": record_id,
                            "employee_id": emp_id,
                            "hours": hours,
                            "rate_multiplier": rate_multiplier,
                            "calculated_amount": calculated_amount,
                            "reason": payload.reason,
                            "status": status_val,
                        },
                        ensure_ascii=False,
                    ),
                ),
            )

        # Retrieve full created record
        created = OvertimeService.get_overtime_by_id(record_id)
        if not created:
            raise RuntimeError("فشل استرجاع سجل الساعات الإضافية بعد الإنشاء")
        return created

    @staticmethod
    def review_overtime_record(
        record_id: str,
        payload: OvertimeRecordReview,
        current_user_id: Optional[str] = None,
    ) -> OvertimeRecordResponse:
        """Review overtime record, update notes or parameters, and record in audit log."""
        with get_db() as conn:
            ensure_seed_data(conn)
            cur = conn.execute("SELECT * FROM overtime_records WHERE id = ?", (record_id,))
            old_row = cur.fetchone()
            if not old_row:
                raise ValueError(f"سجل الساعات الإضافية '{record_id}' غير موجود")

            current_status = old_row["status"]
            if current_status in ("approved", "rejected"):
                raise ValueError(
                    f"لا يمكن مراجعة أو تعديل طلب الساعات الإضافية: الطلب بحالة '{current_status}' مسبقاً"
                )

            old_data = dict(old_row)
            if payload.hours is not None:
                h_val = float(payload.hours)
                if not math.isfinite(h_val) or h_val <= 0 or h_val > 24:
                    raise ValueError("ساعات العمل الإضافي المعدلة يجب أن تكون رقماً حقيقياً موجباً بين 0 و 24")
                hours = h_val
            else:
                hours = float(old_row["hours"])

            if payload.rate_multiplier is not None:
                m_val = float(payload.rate_multiplier)
                if not math.isfinite(m_val) or m_val < 1.0 or m_val > 5.0:
                    raise ValueError("معامل الأجر الإضافي المعدل يجب أن يكون رقماً حقيقياً بين 1.0 و 5.0")
                rate_multiplier = m_val
            else:
                rate_multiplier = float(old_row["rate_multiplier"])

            # Recompute amount if parameters changed
            if payload.hours is not None or payload.rate_multiplier is not None:
                # Find hourly rate
                emp_cur = conn.execute(
                    "SELECT hourly_rate FROM employees WHERE id = ?",
                    (old_row["employee_id"],),
                )
                emp_row = emp_cur.fetchone()
                hourly_rate = float(emp_row["hourly_rate"]) if emp_row and emp_row["hourly_rate"] else 42.0
                calculated_amount = round(hours * hourly_rate * rate_multiplier, 2)
            else:
                calculated_amount = float(old_row["calculated_amount"])

            decision_reason = payload.resolved_notes() or old_row["decision_reason"]
            status_val = payload.status or old_row["status"]

            conn.execute(
                """
                UPDATE overtime_records
                SET hours = ?, rate_multiplier = ?, calculated_amount = ?,
                    decision_reason = ?, status = ?
                WHERE id = ?
                """,
                (hours, rate_multiplier, calculated_amount, decision_reason, status_val, record_id),
            )

            # Log to audit_logs
            audit_id = f"aud_{uuid.uuid4().hex[:12]}"
            conn.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id,
                    old_values_json, new_values_json, timestamp
                ) VALUES (?, ?, ?, 'REVIEW', 'overtime_record', ?, ?, ?, datetime('now'))
                """,
                (
                    audit_id,
                    current_user_id or payload.resolved_reviewer_id() or "usr_bm1",
                    old_row["branch_id"],
                    record_id,
                    json.dumps(old_data, ensure_ascii=False),
                    json.dumps(
                        {
                            "hours": hours,
                            "rate_multiplier": rate_multiplier,
                            "calculated_amount": calculated_amount,
                            "decision_reason": decision_reason,
                            "status": status_val,
                        },
                        ensure_ascii=False,
                    ),
                ),
            )

        updated = OvertimeService.get_overtime_by_id(record_id)
        if not updated:
            raise RuntimeError("فشل استرجاع السجل بعد المراجعة")
        return updated

    @staticmethod
    def approve_overtime_record(
        record_id: str,
        payload: OvertimeRecordApprove,
        current_user_id: Optional[str] = None,
    ) -> Tuple[OvertimeRecordResponse, Optional[FinancialImpactSummary]]:
        """Approve or reject overtime record, apply financial impact to SQLite, and write audit log."""
        with get_db() as conn:
            ensure_seed_data(conn)
            cur = conn.execute("SELECT * FROM overtime_records WHERE id = ?", (record_id,))
            old_row = cur.fetchone()
            if not old_row:
                raise ValueError(f"سجل الساعات الإضافية '{record_id}' غير موجود")

            current_status = old_row["status"]
            if current_status in ("approved", "rejected"):
                raise ValueError(
                    f"لا يمكن تغيير حالة الطلب: الطلب تم البت فيه مسبقاً بحالة '{current_status}' (تم منع الاعتماد المزدوج وتكرار الأثر المالي)"
                )

            old_data = dict(old_row)
            is_approved = payload.resolve_is_approved()
            target_status = "approved" if is_approved else "rejected"
            approver_id = current_user_id or payload.resolve_approver_id() or "usr_ceo"
            decision_reason = payload.resolve_reason()

            # Update overtime_records
            conn.execute(
                """
                UPDATE overtime_records
                SET status = ?, approved_by_user_id = ?, decision_reason = ?
                WHERE id = ?
                """,
                (target_status, approver_id, decision_reason, record_id),
            )

            financial_summary: Optional[FinancialImpactSummary] = None

            # Calculate and apply financial impact in SQLite when approved
            if is_approved:
                emp_id = old_row["employee_id"]
                calc_amount = float(old_row["calculated_amount"])
                year, month = parse_period_from_date(old_row["date"])

                # Check if pay history already exists for this period
                pay_cur = conn.execute(
                    """
                    SELECT id, base_amount, overtime_amount, deductions_amount, net_payout, status
                    FROM employee_pay_history
                    WHERE employee_id = ? AND period_month = ? AND period_year = ?
                    """,
                    (emp_id, month, year),
                )
                pay_row = pay_cur.fetchone()

                if pay_row:
                    prev_ot = float(pay_row["overtime_amount"] or 0.0)
                    base_salary = float(pay_row["base_amount"] or 0.0)
                    deductions = float(pay_row["deductions_amount"] or 0.0)
                    new_ot = round(prev_ot + calc_amount, 2)
                    new_net = round(base_salary + new_ot - deductions, 2)
                    pay_id = pay_row["id"]

                    conn.execute(
                        """
                        UPDATE employee_pay_history
                        SET overtime_amount = ?, net_payout = ?
                        WHERE id = ?
                        """,
                        (new_ot, new_net, pay_id),
                    )
                else:
                    # Look up base_salary from employee
                    emp_cur = conn.execute("SELECT base_salary FROM employees WHERE id = ?", (emp_id,))
                    emp_data = emp_cur.fetchone()
                    base_salary = float(emp_data["base_salary"]) if emp_data and emp_data["base_salary"] else 7500.0
                    prev_ot = 0.0
                    new_ot = round(calc_amount, 2)
                    new_net = round(base_salary + new_ot, 2)
                    pay_id = f"pay_{emp_id}_{year}_{month:02d}"

                    conn.execute(
                        """
                        INSERT INTO employee_pay_history (
                            id, employee_id, period_month, period_year, base_amount,
                            overtime_amount, deductions_amount, net_payout, status, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?, 0.0, ?, 'pending', datetime('now'))
                        """,
                        (pay_id, emp_id, month, year, base_salary, new_ot, new_net),
                    )

                financial_summary = FinancialImpactSummary(
                    payHistoryId=pay_id,
                    employeeId=emp_id,
                    periodMonth=month,
                    periodYear=year,
                    baseSalary=base_salary,
                    previousOvertimeAmount=prev_ot,
                    addedOvertimeAmount=calc_amount,
                    newOvertimeAmount=new_ot,
                    newNetPayout=new_net,
                    status="pending",
                )

            # Insert audit log entry
            audit_id = f"aud_{uuid.uuid4().hex[:12]}"
            conn.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id,
                    old_values_json, new_values_json, timestamp
                ) VALUES (?, ?, ?, ?, 'overtime_record', ?, ?, ?, datetime('now'))
                """,
                (
                    audit_id,
                    approver_id,
                    old_row["branch_id"],
                    "APPROVE" if is_approved else "REJECT",
                    record_id,
                    json.dumps(old_data, ensure_ascii=False),
                    json.dumps(
                        {
                            "status": target_status,
                            "approved_by_user_id": approver_id,
                            "decision_reason": decision_reason,
                            "financial_impact": financial_summary.model_dump() if financial_summary else None,
                        },
                        ensure_ascii=False,
                    ),
                ),
            )

        updated = OvertimeService.get_overtime_by_id(record_id)
        if not updated:
            raise RuntimeError("فشل استرجاع السجل بعد الاعتماد")
        return updated, financial_summary
