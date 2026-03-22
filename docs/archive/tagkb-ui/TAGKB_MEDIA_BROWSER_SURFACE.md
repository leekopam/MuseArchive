# TagKB Media Browser Surface

Date: 2026-03-15

## Purpose

This document records the project-local media search/browser card polish that
was derived from the FYI references without modifying the original `FYI`
materials.

Primary reference sources:

- `docs/screen_interaction_spec_v1.md`
- `docs/e2e_scenario_book_v1.md`
- `manual/tagkb_master_manual_v5.md`

## What Exists Now

- media search/list page keeps the dense card layout
- each result card now surfaces:
  - visibility
  - standalone vs linked-post state
  - MIME mismatch warning
  - translation locale badges
  - resolved-tag count
  - last update time
  - direct actions for detail, post, and edit

## Why This Matters

The FYI corpus treats media search as more than a thumbnail wall. Operators
need to see whether a result is:

- safe to trust as a standalone library item
- still linked to a source post
- carrying integrity issues
- already localized enough for tag-page usage

The current browser card now exposes those cues without forcing the operator
to open the inspector first.

## Remaining Gaps

- query-match reason is still tag search only; media search does not yet expose
  equivalent match metadata
- browser cards still do not show source-domain summaries or gallery-role hints
- Playwright coverage for these enriched media result cards is still missing
