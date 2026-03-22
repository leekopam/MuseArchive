# TagKB Entry Details Editor

Date: 2026-03-15

## Where It Appears

The tag edit page now has a structured manual entry editor inside manual or
mixed page blocks.

Quick fields:

- `block-tags` is still the fastest path for simple manual tag links.
- `block-posts` is still the fastest path for simple manual post links.

Structured field:

- `Manual entries` row editor is now the default path for preview override,
  captions, body copy, standalone media items, and external links.

Advanced field:

- `Advanced JSON` is still available as a fallback for uncommon payloads.

## Input Format

Preferred path: use the row editor.

Fallback path: use one JSON object per line, or paste a JSON array into the
advanced JSON box.

Example for a manual tag gallery card:

```json
{"tag":"handlebar_mustache","previewItemId":42,"titleOverride":"Handlebar","caption":"Classic curved style","bodyText":"Often used for exaggerated comic styling."}
```

Example for a standalone media item inside `item_gallery`:

```json
{"itemId":108,"titleOverride":"Reference sheet","caption":"Standalone media card","bodyText":"No linked post is required."}
```

Example for an external reference card:

```json
{"entryType":"external_link","url":"https://example.com/reference","titleOverride":"Reference article","caption":"External reading"}
```

## Recommended Rules

- Keep simple entries in `block-tags` or `block-posts`.
- Use the row editor for normal cards that need overrides.
- Use `Advanced JSON` only when a payload does not fit the current row fields.
- Prefer `previewItemId` when the linked tag/item should show a different
  thumbnail.
- Use `titleOverride` for the visible card title and `bodyText` for the longer
  explanatory copy.

## Validation Notes

- Each JSON line must be a valid object.
- `item_gallery` entries require `postId` or `itemId`.
- `previewItemId` must point to an existing media item.
- Invalid JSON blocks stop save and surface an inline error message in the edit
  screen.
