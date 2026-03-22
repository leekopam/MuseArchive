# TagKB Publish Review Flow

Date: 2026-03-15

## Goal

Let editors compare the current draft page shape against the last published page
before they publish new changes.

## Current Behavior

- The tag edit screen includes a `Review publish diff` button in the page block
  section.
- Clicking the button collects the current in-form block payload.
- The client sends the payload to `POST /tag/<name>/page/review`.
- The server stores the latest published page as `published_snapshot_json` when
  a page is published.
- Review requests render the current draft in a nested transaction, compare it
  against the published snapshot, and roll the transaction back.
- The client renders block-level review state as `added`, `removed`,
  `changed`, or `unchanged`.
- Changed blocks now expose field-level diff summaries.
- The review panel now includes:
  - highlights
  - checklist items
  - per-block changed field summaries
- The review summary now also includes a readiness strip for:
  - publish readiness
  - unchanged block count
  - recent page-event count
- The review panel also includes recent page history entries from audit logs.
- The tag summary sidebar also exposes the same recent page history timeline.

## Diff Rules

- The comparison uses stable editor-facing block fields:
  - `type`
  - `title`
  - `sourceMode`
  - `displayMode`
  - `body`
  - `settings`
  - `tagNames`
  - `postIds`
  - `entryDetails`
  - `translations`
- Dynamic resolved query results are not diffed item-by-item.

## Current Limits

- This is still a structured block review, not a prose-level text diff view.
- Rich text is still textarea and markdown based.
- There is no dedicated publish review dashboard yet.
- Publish history is currently a recent timeline, not a filterable full activity
  screen.

## Related Files

- `Script/server/szurubooru/model/tag_meta.py`
- `Script/server/szurubooru/func/tag_master.py`
- `Script/server/szurubooru/api/tag_api.py`
- `Script/client/js/models/tag.js`
- `Script/client/js/controllers/tag_controller.js`
- `Script/client/js/views/tag_edit_view.js`
- `Script/client/html/tag_page_review.tpl`
- `Script/client/css/tag-view.styl`
