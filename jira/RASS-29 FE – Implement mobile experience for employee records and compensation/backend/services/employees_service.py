import json
import math
import time
import calendar
import re
from datetime import datetime, timedelta
from typing import Any, List, Optional, Tuple
import sqlite3
from fastapi import HTTPException, status
from ..schemas.employees_schemas import (
    EmployeeCreate,
    EmployeeUpdate,
    EmployeeResponse,
    EmployeeCompensationResponse,
    PayHistoryRecordResponse,
)

ARABIC_MONTHS = {
    1: "يناير",
    2: "فبراير",
    3: "مارس",
    4: "أبريل",
    5: "مايو",
    6: "يونيو",
    7: "يوليو",
    8: "أغسطس",
    9: "سبتمبر",
    10: "أكتوبر",
    11: "نوفمبر",
    12: "ديسمبر",
}

def get_arabic_month_labels(year: int, month: int) -> Tuple[str, str]:
    m_name = ARABIC_MONTHS.get(month, f"شهر {month}")
    month_label = f"{m_name} {year}"
    try:
        _, last_day = calendar.monthrange(year, month)
        date_label = f"{last_day} {m_name} {year}"
    except Exception:
        date_label = f"30 {m_name} {year}"
    return month_label, date_label

def _row_val(row: Any, col_idx: int, col_name: str) -> Any:
    if hasattr(row, "keys"):
        try:
            return row[col_name]
        except Exception:
            pass
    if isinstance(row, dict):
        return row.get(col_name)
    try:
        return row[col_idx]
    except Exception:
        try:
            return row[col_name]
        except Exception:
            return None


def parse_shift_duration(d_str: Optional[str], t_in: Optional[str], t_out: Optional[str]) -> float:
    if not t_in or not t_out or not isinstance(t_in, str) or not isinstance(t_out, str):
        return 0.0

    def _parse(d_val: Optional[str], t_val: str) -> Optional[Tuple[bool, datetime]]:
        t_clean = t_val.strip()
        for iso_fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M"):
            try:
                return (True, datetime.strptime(t_clean, iso_fmt))
            except ValueError:
                pass

        if not d_val or not isinstance(d_val, str):
            return None
        try:
            base_date = datetime.strptime(d_val.strip()[:10], "%Y-%m-%d")
        except ValueError:
            return None

        is_pm = "م" in t_clean or "PM" in t_clean.upper()
        is_am = "ص" in t_clean or "AM" in t_clean.upper()
        digits = re.sub(r"[^\d:]", "", t_clean)
        parts = digits.split(":")
        if len(parts) < 2:
            return None
        try:
            h = int(parts[0])
            m = int(parts[1])
            s = int(parts[2]) if len(parts) > 2 else 0
        except ValueError:
            return None
        if not (0 <= h <= 23 and 0 <= m <= 59 and 0 <= s <= 59):
            if not (1 <= h <= 12 and 0 <= m <= 59 and 0 <= s <= 59):
                return None
        if is_pm and h < 12:
            h += 12
        elif is_am and h == 12:
            h = 0
        return (False, base_date.replace(hour=h, minute=m, second=s))

    p_in = _parse(d_str, t_in)
    p_out = _parse(d_str, t_out)
    if not p_in or not p_out:
        return 0.0

    exp_in, dt_in = p_in
    exp_out, dt_out = p_out

    if not exp_out and dt_out < dt_in:
        dt_out += timedelta(days=1)

    dur = (dt_out - dt_in).total_seconds()
    if dur <= 0 or dur > 24 * 3600:
        return 0.0
    return round(dur / 3600.0, 1)


def calculate_actual_period_hours(
    conn: sqlite3.Connection,
    employee_id: Optional[str] = None,
    period_start: Optional[Any] = None,
    period_end: Optional[Any] = None,
    branch_id: Optional[str] = None,
    start_date: Optional[Any] = None,
    end_date: Optional[Any] = None,
) -> float:
    """
    Calculate actual working duration derived from attendance check-in/out records.
    Half-open clipping for periods [period_start, period_end), robust to raw sqlite3 connections.
    """
    p_start_raw = period_start or start_date
    p_end_raw = period_end or end_date

    p_start: Optional[datetime] = None
    if isinstance(p_start_raw, datetime):
        p_start = p_start_raw
    elif isinstance(p_start_raw, str) and p_start_raw.strip():
        s = p_start_raw.strip()
        if len(s) == 10:
            p_start = datetime.strptime(s, "%Y-%m-%d")
        else:
            for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"):
                try:
                    p_start = datetime.strptime(s, fmt)
                    break
                except ValueError:
                    pass

    p_end: Optional[datetime] = None
    if isinstance(p_end_raw, datetime):
        p_end = p_end_raw
    elif isinstance(p_end_raw, str) and p_end_raw.strip():
        s = p_end_raw.strip()
        if len(s) == 10:
            p_end = datetime.strptime(s, "%Y-%m-%d") + timedelta(days=1)
        else:
            for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"):
                try:
                    p_end = datetime.strptime(s, fmt)
                    break
                except ValueError:
                    pass

    ids_to_match = set()
    if employee_id:
        emp_id_str = str(employee_id)
        ids_to_match.update([emp_id_str, f"emp_{emp_id_str}", f"emp_0{emp_id_str}"])
        cur = conn.execute(
            "SELECT id, code, national_id, first_name_ar, last_name_ar FROM employees WHERE id = ? OR code = ? OR national_id = ?",
            (emp_id_str, emp_id_str, emp_id_str),
        )
        emp_row = cur.fetchone()
        if emp_row:
            e_id = _row_val(emp_row, 0, "id")
            if e_id:
                ids_to_match.add(str(e_id))
                ids_to_match.add(f"emp_{e_id}")
                ids_to_match.add(f"emp_0{e_id}")
            e_code = _row_val(emp_row, 1, "code")
            if e_code:
                code_str = str(e_code)
                ids_to_match.add(code_str)
                for alias in conn.execute("SELECT id FROM employees WHERE national_id = ? OR code = ?", (code_str, code_str)).fetchall():
                    a_id = _row_val(alias, 0, "id")
                    if a_id:
                        ids_to_match.add(str(a_id))
            e_nid = _row_val(emp_row, 2, "national_id")
            if e_nid:
                ids_to_match.add(str(e_nid))

    query = "SELECT date, check_in_time, check_out_time, status, branch_id, employee_id FROM attendance_records WHERE status IN ('present', 'late')"
    params: List[Any] = []
    if ids_to_match:
        placeholders = ", ".join(["?"] * len(ids_to_match))
        query += f" AND employee_id IN ({placeholders})"
        params.extend(list(ids_to_match))
    if branch_id:
        query += " AND branch_id = ?"
        params.append(branch_id)

    rows = conn.execute(query, params).fetchall()

    def _parse_to_datetime(d_str: Optional[str], t_str: Optional[str]) -> Optional[Tuple[bool, datetime]]:
        if not t_str or not isinstance(t_str, str):
            return None
        t_clean = t_str.strip()
        for iso_fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M"):
            try:
                dt = datetime.strptime(t_clean, iso_fmt)
                return (True, dt)
            except ValueError:
                pass

        if not d_str or not isinstance(d_str, str):
            return None
        d_clean = d_str.strip()
        try:
            base_date = datetime.strptime(d_clean[:10], "%Y-%m-%d")
        except ValueError:
            return None

        is_pm = "م" in t_clean or "PM" in t_clean.upper()
        is_am = "ص" in t_clean or "AM" in t_clean.upper()
        digits = re.sub(r"[^\d:]", "", t_clean)
        parts = digits.split(":")
        if len(parts) < 2:
            return None
        try:
            h = int(parts[0])
            m = int(parts[1])
            s = int(parts[2]) if len(parts) > 2 else 0
        except ValueError:
            return None

        if not (0 <= h <= 23 and 0 <= m <= 59 and 0 <= s <= 59):
            if not (1 <= h <= 12 and 0 <= m <= 59 and 0 <= s <= 59):
                return None

        if is_pm and h < 12:
            h += 12
        elif is_am and h == 12:
            h = 0

        return (False, base_date.replace(hour=h, minute=m, second=s))

    total_seconds = 0.0
    for r in rows:
        d_val = _row_val(r, 0, "date")
        tin_val = _row_val(r, 1, "check_in_time")
        tout_val = _row_val(r, 2, "check_out_time")

        parsed_in = _parse_to_datetime(d_val, tin_val)
        parsed_out = _parse_to_datetime(d_val, tout_val)

        if not parsed_in or not parsed_out:
            continue

        exp_in, dt_in = parsed_in
        exp_out, dt_out = parsed_out

        if not exp_out and dt_out < dt_in:
            dt_out += timedelta(days=1)

        duration_sec = (dt_out - dt_in).total_seconds()
        if duration_sec <= 0 or duration_sec > 24 * 3600:
            continue

        shift_start = dt_in
        shift_end = dt_out
        if p_start is not None:
            shift_start = max(shift_start, p_start)
        if p_end is not None:
            shift_end = min(shift_end, p_end)

        if shift_end > shift_start:
            total_seconds += (shift_end - shift_start).total_seconds()

    return round(total_seconds / 3600.0, 1)


def calculate_actual_monthly_hours(
    conn: sqlite3.Connection,
    emp_id: str,
    target_year: Optional[int] = None,
    target_month: Optional[int] = None,
) -> float:
    """
    Calculate actual monthly working duration derived from attendance check-in/out records.
    Correctly computes elapsed time for explicit datetimes vs time-only overnight inference
    with documented max 24h limit, and splits interval into months correctly for cross-month shifts
    without falling back to previous months.
    """
    now = datetime.now()
    cur_year = target_year or now.year
    cur_month = target_month or now.month

    month_start = datetime(cur_year, cur_month, 1, 0, 0, 0)
    if cur_month == 12:
        next_month_start = datetime(cur_year + 1, 1, 1, 0, 0, 0)
    else:
        next_month_start = datetime(cur_year, cur_month + 1, 1, 0, 0, 0)

    return calculate_actual_period_hours(
        conn=conn,
        employee_id=emp_id,
        period_start=month_start,
        period_end=next_month_start,
    )

def row_to_employee_response(
    row: sqlite3.Row,
    conn: Optional[sqlite3.Connection] = None,
    total_hours: Optional[float] = None,
) -> EmployeeResponse:
    first_name = row["first_name_ar"] or ""
    last_name = row["last_name_ar"] or ""
    full_name = f"{first_name} {last_name}".strip()
    job_title = row["job_title"] or "موظف"

    branch_name = row["branch_name"] if "branch_name" in row.keys() and row["branch_name"] else "الفرع الرئيسي - وسط البلد"
    branch_code = row["branch_code"] if "branch_code" in row.keys() and row["branch_code"] else "#01"
    manager_name = row["manager_name"] if "manager_name" in row.keys() and row["manager_name"] else "م. ألفاريز (مدير فرع)"

    wage_type = str(row["wage_type"] or "monthly")
    base_sal = float(row["base_salary"] or 0.0)
    hourly_r = float(row["hourly_rate"] or 0.0)
    if wage_type == "hourly":
        if base_sal == 0.0 and hourly_r > 0.0:
            base_sal = hourly_r
        elif hourly_r == 0.0 and base_sal > 0.0:
            hourly_r = base_sal

    if total_hours is not None:
        actual_hours = float(total_hours)
    elif conn is not None:
        actual_hours = calculate_actual_monthly_hours(conn, str(row["id"]))
    else:
        actual_hours = 0.0

    return EmployeeResponse(
        id=str(row["id"]),
        code=str(row["code"] or row["id"]),
        name=full_name,
        firstNameAr=first_name,
        lastNameAr=last_name,
        jobTitle=job_title,
        role=job_title,
        branchId=str(row["branch_id"]),
        branchName=branch_name,
        branchCode=branch_code,
        managerName=manager_name,
        phone=str(row["phone"] or ""),
        nationalId=str(row["national_id"] or ""),
        wageType=wage_type,
        baseSalary=base_sal,
        hourlyRate=hourly_r,
        overtimeRate=float(row["overtime_rate"] or 35.0),
        housingAllowance=float(row["housing_allowance"] or 0.0),
        transportAllowance=float(row["transport_allowance"] or 0.0),
        insuranceDeduction=float(row["insurance_deduction"] or 0.0),
        status=str(row["status"] or "active"),
        department=str(row["department"] or "FOH"),
        totalHoursThisMonth=actual_hours,
        isActive=bool(row["is_active"]),
        hireDate=str(row["hire_date"] or "2023-01-01"),
        createdAt=str(row["created_at"]) if "created_at" in row.keys() else None,
        updatedAt=str(row["updated_at"]) if "updated_at" in row.keys() else None,
    )

class EmployeesService:
    @staticmethod
    def list_employees(
        conn: sqlite3.Connection,
        branch_id: Optional[str] = None,
        status_filter: Optional[str] = None,
        wage_type: Optional[str] = None,
        search: Optional[str] = None,
    ) -> List[EmployeeResponse]:
        query = """
            SELECT e.*, b.name_ar as branch_name, b.code as branch_code, b.manager_name
            FROM employees e
            LEFT JOIN branches b ON e.branch_id = b.id
            WHERE 1=1
        """
        params = []
        if branch_id:
            query += " AND e.branch_id = ?"
            params.append(branch_id)
        if not status_filter:
            query += " AND e.is_active = 1 AND e.status != 'archived'"
        else:
            query += " AND e.status = ?"
            params.append(status_filter)
        if wage_type:
            query += " AND e.wage_type = ?"
            params.append(wage_type)
        if search:
            search_pattern = f"%{search.strip()}%"
            query += """ AND (
                e.first_name_ar LIKE ? OR
                e.last_name_ar LIKE ? OR
                e.code LIKE ? OR
                e.job_title LIKE ? OR
                e.phone LIKE ?
            )"""
            params.extend([search_pattern] * 5)

        query += " ORDER BY e.id ASC"
        cursor = conn.execute(query, params)
        rows = cursor.fetchall()
        return [row_to_employee_response(r, conn=conn) for r in rows]

    @staticmethod
    def get_employee_by_id(conn: sqlite3.Connection, emp_id: str) -> Optional[EmployeeResponse]:
        query = """
            SELECT e.*, b.name_ar as branch_name, b.code as branch_code, b.manager_name
            FROM employees e
            LEFT JOIN branches b ON e.branch_id = b.id
            WHERE e.id = ? OR e.code = ?
        """
        cursor = conn.execute(query, (emp_id, emp_id))
        row = cursor.fetchone()
        if not row:
            return None
        return row_to_employee_response(row, conn=conn)

    @staticmethod
    def create_employee(conn: sqlite3.Connection, payload: EmployeeCreate) -> EmployeeResponse:
        # Determine ID
        emp_id = payload.id or f"emp_{int(time.time() * 1000)}"

        # Determine Code
        if payload.code:
            code = payload.code
        else:
            cur = conn.execute("SELECT COUNT(*) FROM employees")
            count = cur.fetchone()[0]
            code = str(1048 + count)

        # Names
        first_name = payload.firstNameAr
        last_name = payload.lastNameAr
        if not first_name:
            if payload.name:
                parts = payload.name.strip().split(" ", 1)
                first_name = parts[0]
                last_name = parts[1] if len(parts) > 1 else ""
            else:
                first_name = "موظف"
                last_name = "جديد"
        if last_name is None:
            last_name = ""

        # Job title / role
        job_title = payload.jobTitle or payload.role or "موظف تشغيل"

        # Branch
        branch_id = payload.branchId or "br_01"
        cur = conn.execute("SELECT id FROM branches WHERE id = ?", (branch_id,))
        if not cur.fetchone():
            branch_id = "br_01"

        # National ID
        national_id = payload.nationalId or f"NAT-{int(time.time() * 1000)}"
        cur = conn.execute("SELECT id FROM employees WHERE national_id = ?", (national_id,))
        if cur.fetchone():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Employee with National ID '{national_id}' already exists",
            )

        wage_type = payload.wageType or "monthly"
        base_salary = float(payload.baseSalary or 0.0)
        hourly_rate = float(payload.hourlyRate or 0.0)
        if wage_type == "hourly":
            if hourly_rate == 0.0 and base_salary > 0.0:
                hourly_rate = base_salary
            elif base_salary == 0.0 and hourly_rate > 0.0:
                base_salary = hourly_rate
        overtime_rate = float(payload.overtimeRate or 35.0)
        housing = float(payload.housingAllowance or 0.0)
        transport = float(payload.transportAllowance or 0.0)
        insurance = float(payload.insuranceDeduction or 0.0)

        for val_name, val in [
            ("baseSalary", base_salary),
            ("hourlyRate", hourly_rate),
            ("overtimeRate", overtime_rate),
            ("housingAllowance", housing),
            ("transportAllowance", transport),
            ("insuranceDeduction", insurance),
        ]:
            if not math.isfinite(val) or val < 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"القيمة المالية للحقل '{val_name}' غير صالحة: يجب أن تكون رقماً حقيقياً محدداً وغير سالب (>= 0)",
                )

        emp_status = payload.status or "active"
        department = payload.department or "FOH"
        hire_date = payload.hireDate or datetime.now().strftime("%Y-%m-%d")
        is_active = 1 if payload.isActive else 0

        conn.execute(
            """
            INSERT INTO employees (
                id, code, branch_id, first_name_ar, last_name_ar, job_title,
                phone, national_id, wage_type, base_salary, hourly_rate,
                overtime_rate, housing_allowance, transport_allowance,
                insurance_deduction, status, department, is_active, hire_date
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                emp_id, code, branch_id, first_name, last_name, job_title,
                payload.phone, national_id, wage_type, base_salary, hourly_rate,
                overtime_rate, housing, transport, insurance, emp_status,
                department, is_active, hire_date
            )
        )

        emp = EmployeesService.get_employee_by_id(conn, emp_id)
        if not emp:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to retrieve created employee",
            )
        return emp

    @staticmethod
    def update_employee(conn: sqlite3.Connection, emp_id: str, payload: EmployeeUpdate) -> EmployeeResponse:
        existing = EmployeesService.get_employee_by_id(conn, emp_id)
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Employee with ID '{emp_id}' not found",
            )

        fields = []
        params = []

        if payload.code is not None:
            fields.append("code = ?")
            params.append(payload.code)

        if payload.firstNameAr is not None:
            fields.append("first_name_ar = ?")
            params.append(payload.firstNameAr)

        if payload.lastNameAr is not None:
            fields.append("last_name_ar = ?")
            params.append(payload.lastNameAr)

        if payload.name is not None and payload.firstNameAr is None:
            parts = payload.name.strip().split(" ", 1)
            fields.append("first_name_ar = ?")
            params.append(parts[0])
            fields.append("last_name_ar = ?")
            params.append(parts[1] if len(parts) > 1 else "")

        if payload.jobTitle is not None:
            fields.append("job_title = ?")
            params.append(payload.jobTitle)
        elif payload.role is not None:
            fields.append("job_title = ?")
            params.append(payload.role)

        if payload.phone is not None:
            fields.append("phone = ?")
            params.append(payload.phone)

        if payload.branchId is not None:
            fields.append("branch_id = ?")
            params.append(payload.branchId)

        if payload.nationalId is not None:
            fields.append("national_id = ?")
            params.append(payload.nationalId)

        if payload.wageType is not None:
            fields.append("wage_type = ?")
            params.append(payload.wageType)

        target_wage_type = payload.wageType or existing.wageType

        for val_name, val in [
            ("baseSalary", payload.baseSalary),
            ("hourlyRate", payload.hourlyRate),
            ("overtimeRate", payload.overtimeRate),
            ("housingAllowance", payload.housingAllowance),
            ("transportAllowance", payload.transportAllowance),
            ("insuranceDeduction", payload.insuranceDeduction),
        ]:
            if val is not None:
                f_val = float(val)
                if not math.isfinite(f_val) or f_val < 0:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"القيمة المالية للحقل '{val_name}' غير صالحة: يجب أن تكون رقماً حقيقياً محدداً وغير سالب (>= 0)",
                    )

        if payload.baseSalary is not None:
            fields.append("base_salary = ?")
            params.append(payload.baseSalary)
            if target_wage_type == "hourly" and payload.hourlyRate is None:
                fields.append("hourly_rate = ?")
                params.append(payload.baseSalary)

        if payload.hourlyRate is not None:
            fields.append("hourly_rate = ?")
            params.append(payload.hourlyRate)
            if target_wage_type == "hourly" and payload.baseSalary is None:
                fields.append("base_salary = ?")
                params.append(payload.hourlyRate)

        if payload.overtimeRate is not None:
            fields.append("overtime_rate = ?")
            params.append(payload.overtimeRate)

        if payload.housingAllowance is not None:
            fields.append("housing_allowance = ?")
            params.append(payload.housingAllowance)

        if payload.transportAllowance is not None:
            fields.append("transport_allowance = ?")
            params.append(payload.transportAllowance)

        if payload.insuranceDeduction is not None:
            fields.append("insurance_deduction = ?")
            params.append(payload.insuranceDeduction)

        if payload.status is not None:
            fields.append("status = ?")
            params.append(payload.status)

        if payload.department is not None:
            fields.append("department = ?")
            params.append(payload.department)

        if payload.hireDate is not None:
            fields.append("hire_date = ?")
            params.append(payload.hireDate)

        if payload.isActive is not None:
            fields.append("is_active = ?")
            params.append(1 if payload.isActive else 0)

        if fields:
            fields.append("updated_at = datetime('now')")
            params.append(existing.id)
            sql = f"UPDATE employees SET {', '.join(fields)} WHERE id = ?"
            conn.execute(sql, params)

        updated = EmployeesService.get_employee_by_id(conn, existing.id)
        if not updated:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to retrieve updated employee",
            )
        return updated

    @staticmethod
    def get_employee_compensation(conn: sqlite3.Connection, emp_id: str) -> EmployeeCompensationResponse:
        emp = EmployeesService.get_employee_by_id(conn, emp_id)
        if not emp:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Employee with ID '{emp_id}' not found",
            )

        total_allowances = emp.housingAllowance + emp.transportAllowance
        total_deductions = emp.insuranceDeduction

        if emp.wageType == "hourly":
            actual_hours = calculate_actual_monthly_hours(conn, emp.id)
            earned_base = round(actual_hours * (emp.hourlyRate or 0.0), 2)
        else:
            earned_base = emp.baseSalary

        # Look up approved overtime amount and hours
        try:
            ot_cur = conn.execute(
                """
                SELECT SUM(calculated_amount) as total_ot, SUM(hours) as total_ot_hours
                FROM overtime_records
                WHERE (employee_id = ? OR employee_id = ? OR employee_id = ?)
                  AND status = 'approved'
                """,
                (emp.id, f"emp_{emp.id}", f"emp_0{emp.id}"),
            )
            ot_row = ot_cur.fetchone()
            actual_ot = float(ot_row["total_ot"] or 0.0) if ot_row else 0.0
            ot_hours = float(ot_row["total_ot_hours"] or 0.0) if ot_row else 0.0
        except Exception:
            actual_ot = 0.0
            ot_hours = 0.0

        if emp.wageType == "hourly":
            # Avoid double OT base calculation:
            # Base attendance hours already account for regular hourly wage (1.0x);
            # Add only the net overtime premium beyond regular hourly base (e.g. full OT record 75 vs net premium 25: 150 + 25 = 175)
            base_hourly_portion = round(ot_hours * (emp.hourlyRate or 0.0), 2)
            effective_ot_addition = round(max(0.0, actual_ot - base_hourly_portion), 2)
        else:
            effective_ot_addition = actual_ot

        gross_pay = round(earned_base + total_allowances + effective_ot_addition, 2)
        net_pay = round(gross_pay - total_deductions, 2)

        effective_date = emp.hireDate
        # Review date defaults to 6 months after hire date or a fixed operational date
        review_date = "01 مايو 2024"

        comp_status = "نشط بالخدمة" if emp.isActive else "غير نشط"

        return EmployeeCompensationResponse(
            employeeId=emp.id,
            employeeName=emp.name,
            employeeCode=emp.code,
            jobTitle=emp.jobTitle,
            branchName=emp.branchName,
            wageType=emp.wageType,
            baseSalary=emp.baseSalary,
            hourlyRate=emp.hourlyRate,
            overtimeRate=emp.overtimeRate,
            housingAllowance=emp.housingAllowance,
            transportAllowance=emp.transportAllowance,
            insuranceDeduction=emp.insuranceDeduction,
            totalAllowances=total_allowances,
            totalDeductions=total_deductions,
            grossPay=gross_pay,
            netEstimatedPay=net_pay,
            effectiveDate=effective_date,
            reviewDate=review_date,
            status=comp_status,
        )

    @staticmethod
    def get_employee_pay_history(conn: sqlite3.Connection, emp_id: str) -> List[PayHistoryRecordResponse]:
        emp = EmployeesService.get_employee_by_id(conn, emp_id)
        if not emp:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Employee with ID '{emp_id}' not found",
            )

        cursor = conn.execute(
            """
            SELECT * FROM employee_pay_history
            WHERE employee_id = ?
            ORDER BY period_year DESC, period_month DESC
            """,
            (emp.id,)
        )
        rows = cursor.fetchall()
        records = []
        for r in rows:
            m_label, d_label = get_arabic_month_labels(r["period_year"], r["period_month"])
            status_text = r["status"]
            if status_text == "paid":
                if r["payment_method"] == "cash":
                    status_text = "مسدد نقداً - خزينة الفرع"
                else:
                    status_text = "مسدد عبر البنك"

            records.append(
                PayHistoryRecordResponse(
                    id=str(r["id"]),
                    employeeId=str(r["employee_id"]),
                    periodMonth=r["period_month"],
                    periodYear=r["period_year"],
                    monthLabel=m_label,
                    dateLabel=d_label,
                    baseAmount=float(r["base_amount"]),
                    allowanceAmount=emp.housingAllowance + emp.transportAllowance,
                    overtimeAmount=float(r["overtime_amount"]),
                    deductionsAmount=float(r["deductions_amount"]),
                    netPayout=float(r["net_payout"]),
                    status=status_text,
                    paymentMethod=r["payment_method"],
                    referenceNo=r["reference_no"],
                    paidAt=r["paid_at"],
                )
            )
        return records

    @staticmethod
    def delete_employee(
        conn: sqlite3.Connection,
        emp_id: str,
        user_id: Optional[str] = None,
    ) -> bool:
        cursor = conn.execute(
            "SELECT * FROM employees WHERE id = ? OR code = ?",
            (emp_id, emp_id),
        )
        row = cursor.fetchone()
        if not row:
            return False

        real_id = row["id"]
        old_values = dict(row)

        # Insert audit log for deletion before altering/deleting row
        audit_id = f"aud_{int(time.time() * 1000)}"
        conn.execute(
            """
            INSERT INTO audit_logs (
                id, user_id, branch_id, action, entity_type, entity_id,
                old_values_json, timestamp
            )
            VALUES (?, ?, ?, 'DELETE_EMPLOYEE', 'employees', ?, ?, datetime('now'))
            """,
            (
                audit_id,
                user_id,
                row["branch_id"] if "branch_id" in row.keys() else None,
                real_id,
                json.dumps(old_values, ensure_ascii=False),
            ),
        )

        # Check if attendance records, pay history, or overtime records exist
        att_cur = conn.execute("SELECT COUNT(*) FROM attendance_records WHERE employee_id = ?", (real_id,))
        att_count = att_cur.fetchone()[0] if att_cur else 0

        pay_cur = conn.execute("SELECT COUNT(*) FROM employee_pay_history WHERE employee_id = ?", (real_id,))
        pay_count = pay_cur.fetchone()[0] if pay_cur else 0

        ot_cur = conn.execute("SELECT COUNT(*) FROM overtime_records WHERE employee_id = ?", (real_id,))
        ot_count = ot_cur.fetchone()[0] if ot_cur else 0

        if att_count > 0 or pay_count > 0 or ot_count > 0:
            # Soft delete to preserve historical reporting & payroll integrity
            conn.execute(
                "UPDATE employees SET is_active = 0, status = 'archived', updated_at = datetime('now') WHERE id = ?",
                (real_id,),
            )
        else:
            # Hard delete if no history attached
            conn.execute("DELETE FROM employees WHERE id = ?", (real_id,))

        return True

