# DealInfo v1.2.0

Release date: 18 Feb 2026
Tag: v1.2.0

## Highlights

- Added richer history analytics with line and pie charts.
- Added dealer totals visibility in both history and dealer stats.
- Added stock tracking expansion for gifted and lost stock.
- Added stock-type and item-level stock addition charts.
- Added keyboard-safe bottom-sheet input flows for better mobile usability.
- Added global search, encrypted backup/restore, integrity tools, and undo for stock actions.

## New Features

### History and Analytics
- Customer history line chart and pie chart for sales/ticks trends and totals.
- Dealer totals charts and dedicated dealer stats screen.
- Gifted/Lost dedicated history tab with:
  - sortable/searchable event feed,
  - totals summary,
  - line + pie charts for gifted vs lost quantities.

### Stock Management
- Stock additions now tracked as historical events.
- Stock addition graph screen by stock type and item:
  - per-item cumulative line chart,
  - per-type item-share pie chart,
  - tap pie slice to jump to item chart,
  - temporary visual highlight + selected-item label.
- Added gifted stock flow from customer details (Gift button next to Sell).
- Added lost stock recording flow (select stock item + quantity lost).
- Stock list now shows per-item usage, gifted, and lost counts.
- Configurable low-stock threshold in settings with low-stock indicators.

### Data Safety and Ops
- Encrypted backup creation and restore flow.
- Global search across customers, dealers, stock items, and event records.
- Integrity tools screen with issue detection and auto-repair for common data problems.
- Undo support for recent stock-affecting actions (sell/tick/gift/lost/add/increase).

## UX Improvements

- Soft-glass visual theme and large-text mobile-friendly styling.
- Dialog/input flows migrated to keyboard-safe bottom sheets.
- System navigation overlap fixes for selection sheets.
- Better readability improvements in history with filtering and empty-state feedback.

## Security

- Image encryption/decryption retained for profile/background images.
- Password-based re-encryption support retained when password changes.
- Encrypted backups require the app password for decrypt/restore.

## Notes

- Existing data is preserved and migrated via backward-compatible model parsing.
- New fields (gift/lost/threshold) default safely when absent in older data files.
