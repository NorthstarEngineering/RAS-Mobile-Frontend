# RASS-23: Branch and Central Kitchen Configuration

## Overview
This branch implements the mobile frontend experience for Branch Management and Central Kitchen configuration as part of Jira task [RASS-23](https://omarabdelazez1.atlassian.net/browse/RASS-23).

## Key Screens & Features
- **BR-01 (Branch List)**: Active branches overview, operational status, search, and branch capacity indicators.
- **BR-02 (Create Branch)**: Interactive form for adding new branches with operational timing, warehouse linkage, and location.
- **BR-03 (Branch Details & Edit)**: Detailed branch profile, shift configuration, and associated storage capacities.
- **BR-04 (Central Kitchen Configuration)**: Central production kitchen capabilities, cold storage capacities, and dispatch management.

## Architecture
- **Location**: `lib/features/branches/`
- **Routing**: `/branches`, `/branches/create`, `/branches/details`, `/central-kitchen`
- **Design Standard**: Toast Now RTL-first design system with primary orange `#FF4C00` and high-contrast typography.
