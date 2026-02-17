# DealInfo Terminology

## Purpose
Preferred names for app features, labels, and records.
Use this list for UI text, docs, and code naming consistency.

## Core Terms
- **Main Menu**: First screen with unlock button and current dealer indicators.
- **Unlock**: Password verification action to access protected content.
- **Settings**: Screen for password and background image controls.
- **Dealers**: App users who rotate turns for sales and tick assignments.
- **Dealer ID**: Sequential numeric identity (`1`, `2`, `3`, ...).
- **Customers**: People associated with sales and tick records.

## Rotation Terms
- **Current Sales Dealer**: Dealer whose turn is active for the next sale.
- **Current Tick Dealer**: Dealer whose turn is active for the next new tick.
- **Sales Cycle**: Automatic round-robin dealer rotation after each sale.
- **Tick Cycle**: Automatic round-robin dealer rotation after each new tick.

## Record Terms
- **Sale Record**: Saved event for a sale with dealer, customer, and timestamp.
- **Tick Record**: Saved event for a tick with dealer and timestamp.
- **Paid Status**: Whether a tick is paid (`Paid` / `Not paid`).
- **Edit Window**: One-hour period where paid status can still be changed.
- **Permanent Status**: Tick paid status after the one-hour edit window expires.

## Image & Security Terms
- **Profile Photo**: Dealer or customer image.
- **Encrypted Image**: Photo encrypted using app password before storage.
- **Secure Image Storage**: App-internal storage location for encrypted images.
- **Background Image**: Main menu image, encrypted and password-protected.

## UI Label Preferences
- Use **Unlock** (not Save) for password verification prompts.
- Use **Sell** for recording a sale action.
- Use **Add Tick** for creating a new tick entry.
- Use **Paid / Not paid** for tick payment state labels.
- Use **Editable / Permanent** for tick status mutability labels.

## Naming Preferences for Code
- `DealersScreen`, `CustomersScreen`, `CustomerDetailsScreen`, `MainMenuScreen`, `SettingsScreen`
- `currentSalesDealerId`, `currentTickDealerId`
- `SaleEntry`, `TickEntry`, `Dealer`, `Customer`
- `onRecordSale`, `onAddTick`, `onUpdateTickPaidStatus`
