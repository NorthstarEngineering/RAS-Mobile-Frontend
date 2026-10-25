# RASS-60: Menu Price Change Requests

## Overview
This branch implements the mobile frontend experience for Branch Menu Pricing and Price Modification Approval Workflows as part of Jira task [RASS-60](https://omarabdelazez1.atlassian.net/browse/RASS-60).

## Key Screens & Features
- **PRICE-01 (Price Change Requests)**: Queue of price adjustment proposals submitted by branch managers with status badges.
- **PRICE-02 (Price Change Review & Approval)**: Detailed comparison card showing old vs. new price, margin variance, and effective date picker.
- **PRICE-03 (Price History Archive)**: Chronological audit trail of price changes across all menu items and channels.

## Architecture
- **Location**: `lib/features/pricing/`
- **Routing**: `/pricing/requests`, `/pricing/review`, `/pricing/history`
- **Design Standard**: Clean tabular and card layouts with clear profit-margin and currency indicators.
