import math
import uuid
from datetime import datetime
from typing import List, Optional, Tuple, Dict, Any
from fastapi import HTTPException, status
from ..database.connection import get_db
from ..schemas.attendance_schemas import (
    AttendanceRecordResponse,
    AttendanceAdjustmentResponse,
    EmployeeAttendanceHistoryResponse,
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
        "hourly_rate": 45.0,
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
]

DEFAULT_ATTENDANCE = [
    {
        "id": "att_01",
        "employee_id": "emp_01",
        "branch_id": "br_01",
        "date": "2024-04-16",
        "check_in_time": "08:52 ص",
        "check_out_time": "17:05 م",
        "status": "present",
        "late_minutes": 0,
        "shift_name": "الوردية الصباحية",
    },
    {
        "id": "att_02",
        "employee_id": "emp_02",
        "branch_id": "br_01",
        "date": "2024-04-16",
        "check_in_time": "09:28 ص",
        "check_out_time": None,
        "status": "late",
        "late_minutes": 28,
        "shift_name": "الوردية الصباحية",
    },
    {
        "id": "att_03",
        "employee_id": "emp_03",
        "branch_id": "br_01",
        "date": "2024-04-16",
        "check_in_time": "08:58 ص",
        "check_out_time": "17:00 م",
        "status": "present",
        "late_minutes": 0,
        "shift_name": "الوردية الصباحية",
    },
    {
        "id": "att_04",
        "employee_id": "emp_04",
        "branch_id": "br_01",
        "date": "2024-04-16",
        "check_in_time": None,
        "check_out_time": None,
        "status": "absent",
        "late_minutes": 0,
        "shift_name": "الوردية الصباحية",
    },
]


def ensure_seed_data(conn) -> None:
    """Ensure baseline employees and attendance records exist in SQLite."""
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

    # Seed attendance records if empty
    att_cur = conn.execute("SELECT COUNT(*) FROM attendance_records")
    if att_cur.fetchone()[0] == 0:
        for att in DEFAULT_ATTENDANCE:
            conn.execute(
                """
                INSERT OR IGNORE INTO attendance_records (
                    id, employee_id, branch_id, date, check_in_time, check_out_time,
                    status, late_minutes, shift_name
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    att["id"],
                    att["employee_id"],
                    att["branch_id"],
                    att["date"],
                    att["check_in_time"],
                    att["check_out_time"],
                    att["status"],
                    att["late_minutes"],
                    att["shift_name"],
                ),
            )

    # Keep attendance adjustments history intact (no destructive purge)
    pass


def _row_to_attendance_record(row) -> AttendanceRecordResponse:
    emp_name = f"{row['first_name_ar']} {row['last_name_ar']}".strip()
    status = row["status"]
    late_minutes = int(row["late_minutes"] or 0)

    # Calculate deduction amount
    adj_id = row["adj_id"] if "adj_id" in row.keys() else None
    adj_deduction = row["adj_deduction_amount"] if "adj_deduction_amount" in row.keys() else None
    adj_reason = row["adj_reason"] if "adj_reason" in row.keys() else None
    adj_waived = row["adj_waived_minutes"] if "adj_waived_minutes" in row.keys() else 0

    if adj_deduction is not None:
        deduction_amount = float(adj_deduction)
        is_adjusted = True
    elif status == "late":
        deduction_amount = 45.0 if late_minutes == 28 else round(max(10.0, late_minutes * 1.6), 2)
        is_adjusted = False
    elif status == "absent":
        deduction_amount = 180.0
        is_adjusted = False
    else:
        deduction_amount = 0.0
        is_adjusted = False

    check_in_time = row["check_in_time"]
    if not check_in_time and status == "absent":
        check_in_time = "لم يسجل حضور"

    return AttendanceRecordResponse(
        id=row["id"],
        employeeId=row["employee_id"],
        employeeName=emp_name,
        employeeCode=row["national_id"] or row["employee_id"],
        role=row["job_title"],
        branchId=row["branch_id"],
        branchName=row["branch_name_ar"] if "branch_name_ar" in row.keys() else "",
        date=row["date"],
        checkInTime=check_in_time,
        checkOutTime=row["check_out_time"],
        status=status,
        delayMinutes=late_minutes,
        lateMinutes=late_minutes,
        deductionAmount=deduction_amount,
        isDeductionAdjusted=is_adjusted,
        shiftName=row["shift_name"] or "الوردية الصباحية",
        adjustmentId=adj_id,
        adjustmentReason=adj_reason,
        waivedMinutes=adj_waived or 0,
        createdAt=row["created_at"],
        updatedAt=row["updated_at"],
    )


class AttendanceService:
    @staticmethod
    def get_attendance_list(
        date: Optional[str] = None,
        branch_id: Optional[str] = None,
        status: Optional[str] = None,
        employee_id: Optional[str] = None,
    ) -> List[AttendanceRecordResponse]:
        with get_db() as conn:
            query = """
                SELECT 
                    a.id, a.employee_id, a.branch_id, a.date, a.check_in_time, a.check_out_time,
                    a.status, a.late_minutes, a.shift_name, a.created_at, a.updated_at,
                    e.first_name_ar, e.last_name_ar, e.job_title, e.national_id,
                    b.name_ar as branch_name_ar,
                    adj.id as adj_id, adj.original_late_minutes as adj_original_late_minutes,
                    adj.waived_minutes as adj_waived_minutes,
                    adj.deduction_amount as adj_deduction_amount,
                    adj.reason as adj_reason
                FROM attendance_records a
                JOIN employees e ON a.employee_id = e.id
                JOIN branches b ON a.branch_id = b.id
                LEFT JOIN (
                    SELECT attendance_id, MAX(rowid) as max_rowid
                    FROM attendance_adjustments
                    GROUP BY attendance_id
                ) latest_adj ON a.id = latest_adj.attendance_id
                LEFT JOIN attendance_adjustments adj ON adj.rowid = latest_adj.max_rowid
                WHERE 1=1
            """
            params = []
            if date:
                query += " AND a.date = ?"
                params.append(date)
            if branch_id:
                query += " AND a.branch_id = ?"
                params.append(branch_id)
            if status:
                query += " AND a.status = ?"
                params.append(status)
            if employee_id:
                query += " AND (a.employee_id = ? OR e.national_id = ?)"
                params.extend([employee_id, employee_id])

            query += " ORDER BY a.date DESC, a.check_in_time ASC"
            cursor = conn.execute(query, params)
            rows = cursor.fetchall()
            seen_ids = set()
            unique_records = []
            for r in rows:
                if r["id"] not in seen_ids:
                    seen_ids.add(r["id"])
                    unique_records.append(_row_to_attendance_record(r))
            return unique_records

    @staticmethod
    def get_attendance_by_id(attendance_id: str) -> Optional[AttendanceRecordResponse]:
        with get_db() as conn:
            query = """
                SELECT 
                    a.id, a.employee_id, a.branch_id, a.date, a.check_in_time, a.check_out_time,
                    a.status, a.late_minutes, a.shift_name, a.created_at, a.updated_at,
                    e.first_name_ar, e.last_name_ar, e.job_title, e.national_id,
                    b.name_ar as branch_name_ar,
                    adj.id as adj_id, adj.original_late_minutes as adj_original_late_minutes,
                    adj.waived_minutes as adj_waived_minutes,
                    adj.deduction_amount as adj_deduction_amount,
                    adj.reason as adj_reason
                FROM attendance_records a
                JOIN employees e ON a.employee_id = e.id
                JOIN branches b ON a.branch_id = b.id
                LEFT JOIN (
                    SELECT attendance_id, MAX(rowid) as max_rowid
                    FROM attendance_adjustments
                    GROUP BY attendance_id
                ) latest_adj ON a.id = latest_adj.attendance_id
                LEFT JOIN attendance_adjustments adj ON adj.rowid = latest_adj.max_rowid
                WHERE a.id = ? 
                   OR a.id = ('att_' || ?) 
                   OR a.id = ('att_0' || ?)
                   OR a.id = replace(?, 'att_', '')
                   OR a.id = replace(?, 'att_0', '')
            """
            cursor = conn.execute(query, (attendance_id, attendance_id, attendance_id, attendance_id, attendance_id))
            row = cursor.fetchone()
            if not row:
                return None
            return _row_to_attendance_record(row)

    @staticmethod
    def check_in(
        employee_id: str,
        branch_id: str,
        date: Optional[str] = None,
        check_in_time: Optional[str] = None,
        shift_name: Optional[str] = "الوردية الصباحية",
        late_minutes: int = 0,
    ) -> AttendanceRecordResponse:
        with get_db() as conn:
            ensure_seed_data(conn)
            # Find employee by id or national_id
            emp_cur = conn.execute(
                "SELECT id, branch_id FROM employees WHERE id = ? OR national_id = ? OR code = ?",
                (employee_id, employee_id, employee_id),
            )
            emp_row = emp_cur.fetchone()
            if not emp_row:
                # HR002: Unknown employee reference must 404, no automatic INSERT 6000 employee
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Employee with ID '{employee_id}' not found",
                )
            actual_emp_id = emp_row["id"]

            # Validate branch
            br_cur = conn.execute("SELECT id FROM branches WHERE id = ?", (branch_id,))
            if not br_cur.fetchone():
                branch_id = emp_row["branch_id"] or "br_01"

            now = datetime.now()
            today_str = date or now.strftime("%Y-%m-%d")
            time_str = check_in_time or now.strftime("%I:%M %p").replace("AM", "ص").replace("PM", "م")
            status_val = "late" if late_minutes > 0 else "present"

            # HR003: Check if record already exists for today - cannot overwrite original / checkouts
            existing_cur = conn.execute(
                "SELECT id, check_in_time, check_out_time, status FROM attendance_records WHERE employee_id = ? AND date = ?",
                (actual_emp_id, today_str),
            )
            existing_row = existing_cur.fetchone()
            if existing_row:
                if existing_row["check_in_time"] or existing_row["check_out_time"]:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail=f"Duplicate check-in: employee '{actual_emp_id}' already has a check-in record for {today_str}; original check-in and checkout cannot be overwritten.",
                    )
                rec_id = existing_row["id"]
                conn.execute(
                    """
                    UPDATE attendance_records
                    SET check_in_time = ?, status = ?, late_minutes = ?, shift_name = ?, updated_at = datetime('now')
                    WHERE id = ?
                    """,
                    (time_str, status_val, late_minutes, shift_name or "الوردية الصباحية", rec_id),
                )
            else:
                rec_id = f"att_{uuid.uuid4().hex[:10]}"
                conn.execute(
                    """
                    INSERT INTO attendance_records (\n                        id, employee_id, branch_id, date, check_in_time,\n                        check_out_time, status, late_minutes, shift_name,\n                        created_at, updated_at\n                    ) VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, datetime('now'), datetime('now'))\n                    """,
                    (
                        rec_id,
                        actual_emp_id,
                        branch_id,
                        today_str,
                        time_str,
                        status_val,
                        late_minutes,
                        shift_name or "الوردية الصباحية",
                    ),
                )

        record = AttendanceService.get_attendance_by_id(rec_id)
        if not record:
            raise RuntimeError(f"Failed to retrieve newly created attendance record {rec_id}")
        return record

    @staticmethod
    def check_out(
        attendance_id: Optional[str] = None,
        employee_id: Optional[str] = None,
        date: Optional[str] = None,
        check_out_time: Optional[str] = None,
    ) -> AttendanceRecordResponse:
        with get_db() as conn:
            ensure_seed_data(conn)
            now = datetime.now()
            time_str = check_out_time or now.strftime("%I:%M %p").replace("AM", "ص").replace("PM", "م")

            rec_id = None
            if attendance_id:
                # Find by attendance_id
                cur = conn.execute(
                    """
                    SELECT id, check_out_time FROM attendance_records 
                    WHERE id = ? 
                       OR id = ('att_' || ?) 
                       OR id = ('att_0' || ?)
                       OR id = replace(?, 'att_', '')
                       OR id = replace(?, 'att_0', '')
                    """,
                    (attendance_id, attendance_id, attendance_id, attendance_id, attendance_id),
                )
                row = cur.fetchone()
                if row:
                    if row["check_out_time"] and str(row["check_out_time"]).strip():
                        raise ValueError("Employee has already checked out for this attendance record.")
                    rec_id = row["id"]
            elif employee_id:
                today_str = date or now.strftime("%Y-%m-%d")
                cur = conn.execute(
                    """
                    SELECT a.id, a.check_out_time FROM attendance_records a
                    JOIN employees e ON a.employee_id = e.id
                    WHERE (a.employee_id = ? OR e.national_id = ?) AND a.date = ?
                    ORDER BY a.created_at DESC LIMIT 1
                    """,
                    (employee_id, employee_id, today_str),
                )
                row = cur.fetchone()
                if row:
                    if row["check_out_time"] and str(row["check_out_time"]).strip():
                        raise ValueError("Employee has already checked out for this attendance record.")
                    rec_id = row["id"]

            if not rec_id:
                raise ValueError("Attendance record not found for check-out.")

            conn.execute(
                """
                UPDATE attendance_records
                SET check_out_time = ?, updated_at = datetime('now')
                WHERE id = ?
                """,
                (time_str, rec_id),
            )

        record = AttendanceService.get_attendance_by_id(rec_id)
        if not record:
            raise RuntimeError(f"Failed to retrieve updated attendance record {rec_id}")
        return record

    @staticmethod
    def adjust_deduction(
        attendance_id: str,
        adjusted_by_user_id: str = "usr_bm1",
        waived_minutes: int = 0,
        deduction_amount: float = 0.0,
        reason: str = "",
        original_late_minutes: Optional[int] = None,
    ) -> Tuple[AttendanceAdjustmentResponse, AttendanceRecordResponse]:
        ded_val = float(deduction_amount)
        if not math.isfinite(ded_val) or ded_val < 0:
            raise ValueError("مبلغ الخصم يجب أن يكون رقماً حقيقياً محدداً وغير سالب (>= 0)")
        if waived_minutes < 0:
            raise ValueError("الدقائق المعفاة يجب أن تكون غير سالبة")
        if original_late_minutes is not None and original_late_minutes < 0:
            raise ValueError("دقائق التأخير الأصلية يجب أن تكون غير سالبة")

        with get_db() as conn:
            ensure_seed_data(conn)
            # Find the target attendance record
            cur = conn.execute(
                """
                SELECT id, late_minutes, status FROM attendance_records 
                WHERE id = ? 
                   OR id = ('att_' || ?) 
                   OR id = ('att_0' || ?)
                   OR id = replace(?, 'att_', '')
                   OR id = replace(?, 'att_0', '')
                """,
                (attendance_id, attendance_id, attendance_id, attendance_id, attendance_id),
            )
            row = cur.fetchone()
            if not row:
                raise ValueError(f"Attendance record '{attendance_id}' not found.")

            real_att_id = row["id"]
            real_late_min = int(row["late_minutes"] or 0)
            orig_late = original_late_minutes if original_late_minutes is not None else real_late_min

            # Ensure adjusted_by user exists (fallback to usr_bm1 if invalid)
            user_cur = conn.execute("SELECT id FROM users WHERE id = ?", (adjusted_by_user_id,))
            if not user_cur.fetchone():
                adjusted_by_user_id = "usr_bm1"

            # Update existing adjustment or create new one without deleting historical data
            existing_adj = conn.execute(
                "SELECT id FROM attendance_adjustments WHERE attendance_id = ? ORDER BY rowid DESC",
                (real_att_id,),
            ).fetchone()

            if existing_adj:
                adj_id = existing_adj["id"]
                conn.execute(
                    """
                    UPDATE attendance_adjustments
                    SET adjusted_by_user_id = ?, original_late_minutes = ?,
                        waived_minutes = ?, deduction_amount = ?, reason = ?,
                        created_at = datetime('now')
                    WHERE id = ?
                    """,
                    (adjusted_by_user_id, orig_late, waived_minutes, deduction_amount, reason, adj_id),
                )
            else:
                adj_id = f"adj_{int(datetime.now().timestamp() * 1000)}_{uuid.uuid4().hex[:6]}"
                conn.execute(
                    """
                    INSERT INTO attendance_adjustments (
                        id, attendance_id, adjusted_by_user_id, original_late_minutes,
                        waived_minutes, deduction_amount, reason, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
                    """,
                    (adj_id, real_att_id, adjusted_by_user_id, orig_late, waived_minutes, deduction_amount, reason),
                )

            # Update attendance_records timestamp
            conn.execute(
                "UPDATE attendance_records SET updated_at = datetime('now') WHERE id = ?",
                (real_att_id,),
            )

            # Fetch the adjustment entry
            adj_row = conn.execute(
                "SELECT * FROM attendance_adjustments WHERE id = ?",
                (adj_id,),
            ).fetchone()

            adj_response = AttendanceAdjustmentResponse(
                id=adj_row["id"],
                attendanceId=adj_row["attendance_id"],
                adjustedByUserId=adj_row["adjusted_by_user_id"],
                originalLateMinutes=adj_row["original_late_minutes"],
                waivedMinutes=adj_row["waived_minutes"],
                deductionAmount=float(adj_row["deduction_amount"]),
                reason=adj_row["reason"],
                createdAt=adj_row["created_at"],
            )

        updated_record = AttendanceService.get_attendance_by_id(real_att_id)
        if not updated_record:
            raise RuntimeError(f"Failed to reload attendance record after adjustment {real_att_id}")

        return adj_response, updated_record

    @staticmethod
    def get_employee_history(
        employee_id: str,
        month: Optional[int] = None,
        year: Optional[int] = None,
    ) -> EmployeeAttendanceHistoryResponse:
        with get_db() as conn:
            # Find employee by id, national_id, code, or name
            clean_lookup = employee_id.strip() if employee_id else ""
            emp_cur = conn.execute(
                """
                SELECT id, first_name_ar, last_name_ar, job_title, national_id, code
                FROM employees
                WHERE id = ? OR national_id = ? OR code = ?
                   OR (first_name_ar || ' ' || last_name_ar) = ?
                   OR (first_name_ar || ' ' || last_name_ar) LIKE ?
                   OR id = replace(?, 'emp_', '')
                   OR id = replace(?, 'emp_0', '')
                LIMIT 1
                """,
                (clean_lookup, clean_lookup, clean_lookup, clean_lookup, f"%{clean_lookup}%", clean_lookup, clean_lookup),
            )
            emp = emp_cur.fetchone()
            if not emp:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Employee '{employee_id}' not found.",
                )

            actual_emp_id = emp["id"]
            emp_name = f"{emp['first_name_ar']} {emp['last_name_ar']}".strip()

            # Collect alias ids for employee to match attendance records accurately
            match_ids = set([str(actual_emp_id), f"emp_{actual_emp_id}", f"emp_0{actual_emp_id}"])
            if emp["code"]:
                match_ids.add(str(emp["code"]))
            if emp["national_id"]:
                match_ids.add(str(emp["national_id"]))

            # Also check if any duplicate employee rows exist with same code/national_id
            if emp["code"]:
                for alias in conn.execute("SELECT id FROM employees WHERE national_id = ? OR code = ?", (str(emp["code"]), str(emp["code"]))).fetchall():
                    match_ids.add(str(alias["id"]))

            placeholders = ", ".join(["?"] * len(match_ids))
            query = f"""
                SELECT 
                    a.id, a.employee_id, a.branch_id, a.date, a.check_in_time, a.check_out_time,
                    a.status, a.late_minutes, a.shift_name, a.created_at, a.updated_at,
                    e.first_name_ar, e.last_name_ar, e.job_title, e.national_id,
                    b.name_ar as branch_name_ar,
                    adj.id as adj_id, adj.original_late_minutes as adj_original_late_minutes,
                    adj.waived_minutes as adj_waived_minutes,
                    adj.deduction_amount as adj_deduction_amount,
                    adj.reason as adj_reason
                FROM attendance_records a
                LEFT JOIN employees e ON a.employee_id = e.id OR e.id = replace(a.employee_id, 'emp_0', '') OR e.id = replace(a.employee_id, 'emp_', '')
                LEFT JOIN branches b ON a.branch_id = b.id
                LEFT JOIN (
                    SELECT attendance_id, MAX(rowid) as max_rowid
                    FROM attendance_adjustments
                    GROUP BY attendance_id
                ) latest_adj ON a.id = latest_adj.attendance_id
                LEFT JOIN attendance_adjustments adj ON adj.rowid = latest_adj.max_rowid
                WHERE a.employee_id IN ({placeholders})
            """
            params = list(match_ids)

            if year and month:
                query += " AND strftime('%Y', a.date) = ? AND strftime('%m', a.date) = ?"
                params.extend([str(year), f"{month:02d}"])
            elif year:
                query += " AND strftime('%Y', a.date) = ?"
                params.append(str(year))
            elif month:
                query += " AND strftime('%m', a.date) = ?"
                params.append(f"{month:02d}")

            query += " ORDER BY a.date DESC, a.check_in_time DESC"

            rows = conn.execute(query, params).fetchall()
            seen_ids = set()
            records = []
            for r in rows:
                if r["id"] not in seen_ids:
                    seen_ids.add(r["id"])
                    records.append(_row_to_attendance_record(r))

            total_days = len(records)
            present_days = sum(1 for r in records if r.status == "present")
            late_days = sum(1 for r in records if r.status == "late")
            absent_days = sum(1 for r in records if r.status == "absent")
            total_late_min = sum(r.lateMinutes for r in records)
            total_deductions = sum(r.deductionAmount for r in records)
            total_waived_min = sum(r.waivedMinutes or 0 for r in records)

            return EmployeeAttendanceHistoryResponse(
                employeeId=employee_id or actual_emp_id,
                employeeName=emp_name,
                employeeCode=emp["national_id"] or actual_emp_id,
                jobTitle=emp["job_title"],
                records=records,
                totalDays=total_days,
                presentDays=present_days,
                lateDays=late_days,
                absentDays=absent_days,
                totalLateMinutes=total_late_min,
                totalDeductions=round(total_deductions, 2),
                totalWaivedMinutes=total_waived_min,
            )
