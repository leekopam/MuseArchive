# TagKB Page Preview Flow

Date: 2026-03-15

## Goal

Allow tag editors to review the current page block layout without saving or
publishing the page first.

## Current Behavior

- The tag edit screen includes a `Preview` button inside the page block section.
- Clicking `Preview` collects the current in-form block state.
- The client sends the block payload to `POST /tag/<name>/page/preview`.
- The server saves the payload inside a nested transaction, serializes the
  rendered page result, and rolls the transaction back.
- The client renders the returned block payload in the inline preview panel.
- The preview intro now also shows saved-page context:
  - saved version
  - saved status
  - published baseline presence
  - last published time
  - saved backlink count
- Block-level translation cards now render in preview when the draft contains
  translated block payloads.

## UX Notes

- Preview does not mark the page as saved.
- Preview does not change the page publish state.
- After a successful preview, further edits mark the preview panel as stale.
- Validation errors from manual entry rows or block payload parsing are shown
  before the preview request is sent.

## Current Limits

- This is a render preview, not a publish diff review.
- The preview panel uses the existing tag page rendering family, not a separate
  inspector.
- Rich text blocks are still textarea and markdown based.

## Related Files

- `Script/server/szurubooru/api/tag_api.py`
- `Script/server/szurubooru/func/tag_master.py`
- `Script/client/js/controllers/tag_controller.js`
- `Script/client/js/views/tag_edit_view.js`
- `Script/client/html/tag_page_preview.tpl`
- `Script/client/css/tag-view.styl`
