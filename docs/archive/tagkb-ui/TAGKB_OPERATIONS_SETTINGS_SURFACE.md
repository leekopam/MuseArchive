# TagKB Operations Settings Surface

Date: 2026-03-15

## Purpose

This document records the TagMaster-side implementation that maps the FYI
admin/settings wireframes into the existing `operations` screen without
modifying the reference files inside `FYI`.

## Implemented

- Operations dashboard summary
  - recent tags
  - recent media
  - active jobs
  - validation warnings
  - job status metrics
  - media processing metrics
  - operations service metrics
  - recovery readiness metrics
- Catalog snapshot panel
  - supported locales
  - locale registry
  - relation type registry
  - built-in page template registry
  - search ranking summary
- Locale registry editor
  - load existing locale metadata
  - create custom locales
  - update locale title/default/enabled metadata
  - delete custom locales
  - keep system locales undeletable
- Search-rule settings editor
  - edit the active search-rule JSON profile
  - persist ranking, display, normalization, and support flags
  - reset the active profile back to project defaults
- Page-template registry editor
  - load built-in and custom templates from the same catalog
  - create custom templates with page-block JSON
  - update custom template metadata and block payload
  - delete custom templates
  - keep built-in templates locked
  - show a live block preview for the current registry draft
  - surface block count, query/gallery mix, and entry-row totals
  - highlight invalid JSON before save
- Custom relation type registry editor
  - load existing relation type metadata
  - create custom relation types
  - update custom relation types
  - delete custom relation types
  - keep system relation types locked
- Feature flag snapshot
- quick-job runner
  - resolved-tag rebuild preview
  - cooccurrence rebuild preview
  - backlink rebuild preview
- import preview and import execution
- export, backup, restore preview, and restore execution
- recent audit log feed

## Data Sources

- `GET /bootstrap`
  - `supportedLocales`
  - `defaultLocale`
  - `localeRegistry`
  - `relationTypes`
  - `blockTypes`
  - `pageTemplates`
  - `searchRules`
  - `featureFlags`
- `GET /settings/locales`
- `POST /settings/locales`
- `PUT /settings/locales/<locale_code>`
- `DELETE /settings/locales/<locale_code>`
- `GET /settings/search-rules`
- `PUT /settings/search-rules`
- `POST /settings/search-rules/reset`
- `GET /settings/page-templates`
- `POST /settings/page-templates`
- `PUT /settings/page-templates/<template_key>`
- `DELETE /settings/page-templates/<template_key>`
- `GET /operations/dashboard`
  - summary stats
  - job metrics
  - media metrics
  - operation metrics
  - recovery metrics
  - warnings
  - recent tags
  - recent media
  - active jobs
- `GET /jobs`
- `POST /jobs/rebuild-resolved-tags/preview`
- `POST /jobs/rebuild-cooccurrence/preview`
- `POST /jobs/rebuild-backlinks/preview`
- `GET /backups`
- `GET /audit-logs`

## Remaining Gaps

The FYI corpus still implies additional work beyond the current read-only
snapshot.

### Missing admin/settings surfaces

- richer guided template editor beyond the current JSON + live preview registry surface
- richer guided search-rule tuning screen beyond the current JSON editor

### Missing safety and review polish

- dangerous settings change review flow
- publish checklist integration inside the admin surface
- restore drill checklist and release smoke actions from the UI

## Practical Interpretation

The current screen is now a useful operations dashboard, locale/relation
registry editor, search-rule settings editor, page-template registry editor,
metrics snapshot, and reference panel, but it is not yet a full
settings-management console. It
should be treated as `read-heavy with targeted registry/settings CRUD`, not
`full admin parity`.
