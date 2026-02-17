# DealInfo — Flutter Android App Plan

## Purpose
Track customer credit/ticks across multiple staff members (dealers/users) in a shared app.

## App Type
- Flutter Android app

## MVP Scope

### 1) Main Menu (Customers)
- Show a list/grid of customer cards/buttons.
- Each customer item displays `CUSTOMER_DATA`:
	- Customer name
	- Total tick count
- Include `+` action to add a new customer.
- Allow removing a customer (with confirmation).

### 2) Dealers (App Users)
- Add a `+` button on main menu (or Dealers screen) to create dealers.
- Dealers represent people using the app and recording customer ticks.
- Each dealer must be trackable for what they are owed.

### 3) Customer Details
- On customer tap, open customer detail screen.
- Show list of ticks for that customer.
- Each tick item must include:
	- Dealer name (who is owed)
	- Timestamp/date
- Include `+` button to add a tick.

### 4) Add Tick Flow
- When adding a tick:
	- Dealer selection is required from existing dealers.
	- Save tick to selected customer.

### 5) Camera / Profile Photo
- Allow customer profile photo capture via camera.
- Store image path in local data model.

### 6) Local Storage
- Persist all app data in a single local file named `dealer_customer.dat`.
- File stores:
	- Dealers
	- Customers
	- Customer profile image path
	- Ticks (with dealer reference and timestamp)

## Suggested Data Model

### Dealer
- `id`
- `name`

### Customer
- `id`
- `name`
- `profileImagePath` (optional)
- `ticks` (List<Tick>)

### Tick
- `id`
- `dealerId`
- `createdAt`

## File Format Recommendation
- Use JSON serialization into `dealer_customer.dat`.
- Root object:
	- `dealers: []`
	- `customers: []`

## Minimal Screen List
1. Customers screen (main menu)
2. Dealers management screen
3. Customer details / ticks screen
4. Add dealer dialog
5. Add customer dialog
6. Add tick dialog (dealer picker)

## Core Packages (Flutter)
- `path_provider` (file location)
- `image_picker` (camera capture)
- `uuid` (ids)

## Acceptance Criteria
- Can add/remove dealers.
- Can add/remove customers.
- Can open customer and add tick with required dealer selection.
- Tick list shows dealer name for each tick.
- Customer list shows tick count.
- Customer profile photo can be captured.
- App state is restored from `dealer_customer.dat` on restart.
