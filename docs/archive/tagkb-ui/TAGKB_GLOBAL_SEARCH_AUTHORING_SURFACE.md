# Global Search Authoring Surface

Date: 2026-03-15

## Purpose

This document records the FYI-driven shift from a passive tag list toward a
search-first authoring entrypoint.

## Current Behavior

### Tags page

- `tags` is now a global-search-first authoring page
- an empty query shows a landing state instead of a passive full list
- results expose match reasons from:
  - canonical name
  - alias
  - translation
  - search term
- when there is no exact match and the query can normalize into a valid
  canonical tag name, the page shows `Quick Create`
- global search result cards now expose alias, translation, and search-term
  counts in the same result surface
- global search result cards now expose page status, block count, backlink
  count, and published-baseline presence for document-style triage
- quick create supports:
  - canonical name suggestion from the query
  - primary category choice
  - page template choice
  - short description
  - immediate redirect into tag edit after creation
- shared tag autocomplete now shows canonical/category/match-reason metadata
  across the broader client surface, not only on the dedicated search page

### Home search

- the home search now routes into the tag authoring search flow
- this follows the FYI direction that search is the default authoring entrypoint

### Relation manager

- relation manager lookup reuses the same detailed tag search metadata
- when no exact match exists, the screen exposes `Quick Create`
- if a current tag is selected and the operator chooses a relation type, quick
  create adds a new draft relation row to the current editing workspace
- the relation is not auto-saved; the operator still explicitly saves the final
  outgoing relation set
- search result cards now expose direct `Load`, `Detail`, and `Edit` actions
- when a source tag is already selected, search result cards can add a new
  outgoing relation row without leaving the relation manager

### Tag detail relation editor

- the tag edit screen now supports relation-aware quick create per relation row
- when a target tag does not exist yet, the operator can create it directly
  from the current relation draft
- the newly created tag name is written back into the row immediately
- the outgoing relation is still draft-only until the operator explicitly saves
  the tag editor form

### Manual block entry editor

- manual block entry rows now support inline quick create for `tag` entries
- if a referenced tag does not exist yet, the operator can create it without
  leaving the page builder
- the created canonical name is written back into the row immediately
- the block entry remains draft-only until the operator explicitly saves the
  current page editor state

## Remaining Gaps

- some search-driven surfaces still need stronger card-level result polish
- some non-authoring surfaces still need richer search result presentation
