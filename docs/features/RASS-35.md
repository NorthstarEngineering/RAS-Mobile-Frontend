# RASS-35: Attendance and Lateness Deductions

## Overview
This branch implements the mobile frontend experience for Employee Attendance, Lateness Tracking, and Automated Deduction Adjustments as part of Jira task [RASS-35](https://omarabdelazez1.atlassian.net/browse/RASS-35).

## Key Screens & Features
- **ATT-01 (Attendance List)**: Daily biometric log, real-time check-in/out records, late arrivals, and absence filters.
- **ATT-02 (Attendance Details)**: In-depth punch-in/out timeline, working hours calculation, and penalty breakdown.
- **ATT-03 (Deduction Adjustment)**: Administrative interface for supervisor review, deduction modification, and justification entry.
- **ATT-04 (Employee Attendance History)**: Monthly historical summary of attendance, punctuality scores, and overtime linkage.

## Architecture
- **Location**: `lib/features/attendance/`
- **Routing**: `/attendance`, `/attendance/details`, `/attendance/adjust-deduction`, `/attendance/history`
- **Design Standard**: Arabic RTL layout with dynamic badge statuses (On-Time, Late, Excused, Deducted).
