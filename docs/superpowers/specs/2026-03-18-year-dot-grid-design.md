# Year Dot Grid — Design Spec

**Issue:** #9
**Date:** 2026-03-18

## Overview

Add a year view to the Timeline tab, navigable via pinch gestures. Year view shows a 12-month dot-grid calendar — a compact 4×3 grid of mini-months where each day is a small rounded square colored by city. Month view remains unchanged. No picker/toggle — navigation is gesture-driven.

Insights tab is unchanged. "All Time" is removed from the year picker.

## Navigation Model

- **Swipe left/right** in month view → prev/next month
- **Swipe left/right** in year view → prev/next year
- **Pinch out** on month view → transition to year view (for the displayed year)
- **Tap a mini-month** in year view → transition to that month in month view
- **Pinch in** on year view → transition to month view (today's month if viewing current year, otherwise January of the displayed year)
- **Arrow nav** still available as secondary navigation in both views
- Uses `MagnifyGesture` for pinch, `DragGesture` or `TabView(.page)` for swipe

## Year View Layout

- **4 columns × 3 rows** of mini-month grids (Jan–Dec), left-to-right, top-to-bottom
- Each mini-month: short month label ("Jan") in `.secondary` color, then a 7-column day grid
- **No weekday headers** — too cramped at this scale
- **No section title** — the year nav makes context clear
- **No card background** — dots sit directly in the view for more space
- Year displayed in nav bar with prev/next arrows (same style as month nav)
- Weekday offset calculation reused from `CalendarGridView`

## Day Cell Styling (Year View)

| State | Style |
|---|---|
| Confirmed | Filled `RoundedRectangle(cornerRadius: ~2.5)`, city color from `ColorPalette` |
| Unresolved | `RoamTheme.unresolvedFill` + dashed border (`RoamTheme.unresolvedBorder`) |
| Future | `RoamTheme.surfaceSubtle` at 0.5 opacity |
| No data (past, no log) | Transparent |

Cells are small rounded squares (aspect ratio 1:1). No day numbers — too small. No today highlight.

## Legend

Reuse the existing Timeline legend — horizontal scrolling city color swatches sorted by frequency, formatted with `CityDisplayFormatter`. Include "Unresolved" entry with dashed styling. In year view, legend shows all cities for the selected year.

## File Changes

### New Files
- `Roam/Views/Timeline/YearDotGridView.swift` — the 4×3 grid container, accepts logs and city colors for the year
- `Roam/Views/Timeline/MiniMonthGridView.swift` — single mini-month: month label + 7-column grid of mini day cells

### Modified Files
- `Roam/Views/Timeline/TimelineView.swift` — add year/month view state, `MagnifyGesture` on month view to trigger zoom out, year nav when in year mode, hide month nav/weekday headers in year mode, tap handler on mini-months to zoom in
- `Roam/Views/Insights/YearPicker.swift` — change `selectedYear` from `Int?` to `Int`, remove "All Time" chip
- `Roam/Views/Insights/InsightsView.swift` — update to use non-optional `selectedYear: Int`

### Unchanged
- `Roam/Views/Timeline/DayCell.swift` — month view cell unchanged
- `Roam/Views/Timeline/CalendarGridView.swift` — unchanged
- `Roam/Views/Insights/HighlightsGrid.swift` — no changes
- `Roam/Views/Insights/MonthlyBreakdownChart.swift` — no changes
- `Roam/Views/Insights/YearOverYearView.swift` — no changes

## Non-Interactive

The year dot-grid is read-only except for tapping a mini-month to navigate. No day tapping — that stays in month view only.

## Out of Scope

- "All Time" in Insights — removed from year picker only. `DataExportView` keeps its "All Time" option so users can export full history.
- Animated transitions between month/year (nice-to-have, not required)
- Changes to Insights tab visualizations

## Test Plan

- Year view shows 12 mini-month grids with correct day counts per month
- Weekday offsets are correct (first day of each month lands on the right column)
- Each day cell matches the city color from NightLog data
- Unresolved days show dashed border styling
- Future days show subtle fill at reduced opacity
- Pinch out on month view transitions to year view
- Tapping a mini-month transitions to that month in month view
- Year nav arrows cycle through years
- Legend shows cities present in the selected year
- Year picker in Insights no longer has "All Time" option

## Mockup

See `docs/mockup-dot-grid.html` for a browser-based mockup showing both views side by side.
