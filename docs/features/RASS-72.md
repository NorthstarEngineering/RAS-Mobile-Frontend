# RASS-72: Inventory Movements and Adjustments

## Overview
This branch implements the mobile frontend experience for Branch and Central Kitchen Stock Management, Inventory Tracking, and Stock Adjustments as part of Jira task [RASS-72](https://omarabdelazez1.atlassian.net/browse/RASS-72).

## Key Screens & Features
- **INV-01 (Branch Inventory List)**: Real-time stock levels across cold storage, dry storage, and kitchen shelves.
- **INV-02 (Inventory Item Details)**: Raw material specifications, re-order threshold triggers, and shelf-life tracking.
- **INV-03 (Stock Movements Log)**: Real-time audit trail of inbound deliveries, kitchen consumption, and waste logging.
- **INV-04 (Stock Adjustment & Reconcile)**: Discrepancy reconciliation between actual count and theoretical balance.
- **INV-05 (Inventory Valuation)**: Total current inventory asset value calculated against weighted average cost.
- **CK-01 to CK-05 (Central Kitchen Stock)**: Bulk goods, production consumption, and batch expiry monitoring.

## Architecture
- **Location**: `lib/features/stock_control/`
- **Routing**: `/inventory`, `/inventory/details`, `/inventory/movements`, `/inventory/adjust`, `/inventory/value`, `/inventory/create`, `/ck/dashboard`, etc.
- **Design Standard**: High-density operational data cards with real-time stock alerts and barcode-ready UI.
