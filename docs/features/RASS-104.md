# RASS-104: Mobile Experience for Dashboard

## Overview
This branch implements the mobile frontend experience for Multi-Role Dashboards (CEO, Branch Manager, Supply Manager) as part of Jira task [RASS-104](https://omarabdelazez1.atlassian.net/browse/RASS-104).

## Key Screens & Features
- **COMMON-01 (CEO Executive Dashboard)**: High-level executive KPIs, total gross revenue, network food cost %, labor cost %, and branch rankings.
- **COMMON-02 (Branch Manager Dashboard)**: Real-time active shift metrics, hourly sales velocity, attendance status, and pending approvals.
- **COMMON-03 (Supply Manager Dashboard)**: Outstanding replenishment requests, cold-chain transport status, and low-stock alerts.
- **COMMON-04 & Role Routing**: Dynamic role-based landing redirection ensuring users see their appropriate dashboard immediately upon login.

## Architecture
- **Location**: `lib/features/dashboards/`
- **Routing**: `/dashboard/ceo`, `/dashboard/branch`, `/dashboard/supply`, `/role-dashboards`, `/home`
- **Design Standard**: Modular KPI metric cards, interactive revenue trend indicators, and quick-action toolbars.
