# TagKB Destructive Tag Workflows

Date: 2026-03-15

## Scope

This document tracks the FYI-driven split between soft authoring actions and
destructive tag operations. `FYI` remains reference-only; the live behavior is
implemented in `Script`.

## Implemented Baseline

### Draft editor removals

- alias rows now use inline removal preview with scoped impact copy
- relation rows now use inline removal preview with scoped impact copy
- manual block entry rows now use inline removal preview with scoped impact copy
- each of the above requires typing `REMOVE` before the row is actually removed
- alias, relation, and manual block entry removals stay draft-only until the
  operator explicitly saves the parent tag/page editor

### Direct media assignment removal

- direct media tag assignments now use inline removal preview
- the card explains that resolved tags may shrink after recalculation
- removal requires typing `UNASSIGN` before the server call is sent

### Merge

- route: `tag/:name/merge`
- preview source: `GET /tag/<name>/merge-preview?mergeTo=<target>`
- current behavior:
  - requires an explicit target tag
  - loads an impact preview before submit
  - shows move counts for:
    - direct post usages
    - aliases
    - relations
    - page blocks
    - manual page entries
    - backlinks
    - media refs
    - direct item assignments
    - resolved item tags
  - shows category mismatch and rewrite warnings
  - requires typing `MERGE` before submit
  - keeps redirect-alias creation as an explicit checkbox

### Hard delete

- route: `tag/:name/delete`
- preview source: `GET /tag/<name>/delete-preview`
- current behavior:
  - loads a delete impact preview automatically on screen entry
  - shows blocker counts for:
    - direct post usages
    - aliases
    - search terms
    - relations
    - page blocks
    - manual page entries
    - backlinks
    - media refs
    - resolved item tags
  - disables submit when hard delete is blocked
  - requires typing `DELETE TAG` before submit
  - recommends merge or deprecate when blockers exist

### Deprecate

- route: `tag/:name/deprecate`
- preview source: `GET /tag/<name>/deprecate-preview?redirectTo=<target>`
- current behavior:
  - loads a base deprecate preview automatically on screen entry
  - supports an optional redirect target
  - shows the difference between non-destructive deprecation and merge
  - keeps usages and references in place while marking the tag as deprecated
  - shows redirect-target context when a replacement tag is selected
  - stores a deprecation note
  - requires typing `DEPRECATE` before submit
  - surfaces deprecated status and redirect guidance on the tag summary screen

## Not Done Yet

- restore/rebuild impact previews

## Verification

- `npm run build` passes with the new destructive workflow UI
- Docker API tests pass for:
  - `test_getting_tag_delete_preview_reports_blockers`
  - `test_getting_tag_delete_preview_for_unused_tag_allows_hard_delete`
  - `test_getting_tag_merge_preview_returns_move_summary`
  - `test_getting_tag_merge_preview_rejects_same_tag`
  - `test_getting_tag_deprecate_preview_returns_target_context`
  - `test_deprecating_tag_marks_status_and_redirect_target`
