# TagKB Relation Manager Surface

Date: 2026-03-15

## Purpose

This document records the project-local relation manager surface derived from
the reference-only `FYI` corpus, especially:

- `admin_wireframes_v1.md`
- `frontend_component_spec_v1.md`
- `relations_v1.md`

The `FYI` source files remain untouched. This document describes the
implementation that now lives under `Script/client`.

## What Exists Now

- dedicated route: `relations`
- direct route to a specific tag: `relations/<tagName>`
- top-navigation entry: `Relations`
- lookup by:
  - canonical name
  - alias
  - translation
  - search term
- focused outgoing-relation editor
- relation-type reference sidebar using bootstrap metadata
- quick links back to:
  - tag detail
  - tag edit
  - operations screen

## Interaction Model

### 1. Lookup

The search box uses the existing detailed tag search endpoint and can return
matches from canonical name, alias, translation, and search term data.

### 2. Selection

Selecting a search result navigates to `relations/<tagName>` so the current
workspace can be deep-linked and reopened directly.

### 3. Editing

The editor is intentionally narrow in scope:

- it edits one source tag at a time
- it focuses on outgoing relations only
- each row contains:
  - relation type
  - target tag name
  - note

### 4. Save / Reset

- `Save` writes the full outgoing relation set back through the existing
  relation API
- `Reset` reloads the saved relation state for the selected tag

## Why This Exists Separately

The tag edit page still contains relation editing, but the dedicated relation
manager matches the FYI direction more closely:

- relation work gets its own focused workspace
- tag selection and relation editing are no longer buried inside the full tag
  page editor
- admin/settings parity can now grow from this screen instead of overloading
  the tag editor further

## Remaining Gaps

- editable relation type registry
- locale/template/search-rule settings screens
- richer relation browsing:
  - incoming relation view
  - grouped relation sections
  - bulk-edit utilities
- settings persistence and seed/bootstrap parity management
- Playwright coverage for the relation manager route
