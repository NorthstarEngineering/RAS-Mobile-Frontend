# RASS-84: Inter-Branch Inventory Transfers

## Overview
This branch implements the mobile frontend experience for Inter-Branch Transfers (TR-01 to TR-06) as part of Jira task [RASS-84](https://omarabdelazez1.atlassian.net/browse/RASS-84).

## Key Screens & Features
- **TR-01 (Transfers Overview)**: Outbound and inbound transfer orders categorized by status (Draft, Pending Approval, In-Transit, Completed).
- **TR-02 (Create Transfer Request)**: Multi-item selector, source and destination branch pickers, and urgent priority toggle.
- **TR-03 (Transfer Review & Approval)**: Source branch manager review, item quantity validation, and dispatch sign-off.
- **TR-04 (Dispatch & Driver Assignment)**: Vehicle plate number, driver details, and departure timestamp registration.
- **TR-05 (Receive & Inspect Transfer)**: Receiving branch physical inspection, quantity match check, and damaged item recording.
- **TR-06 (Transfer Audit History)**: Comprehensive historical log of all inter-branch inventory transfers with filterable parameters.

## Architecture
- **Location**: `lib/features/transfers/`
- **Routing**: `/transfers`, `/transfers/create`, `/transfers/review`, `/transfers/send`, `/transfers/receive`, `/transfers/history`
- **Design Standard**: Step-by-step dispatch and receipt steppers optimized for fast tablet/mobile warehouse operation.
