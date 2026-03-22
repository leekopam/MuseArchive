# TagKB Structured Body Editor Surface

Date: 2026-03-15

## Purpose

This document records the current structured-body authoring surface derived
from the `FYI` TagKB editor references, while keeping `FYI` itself read-only.

## Current Surface

Structured authoring is now available inside text-family page blocks and block
translations.

Editors can:

- switch between `markdown` and `structured`
- add common nodes directly from the quick-add palette
- add guided rows for:
  - `paragraph`
  - `heading`
  - `blockquote`
  - `bulletList`
  - `orderedList`
  - `tagMention`
  - `mediaEmbed`
  - `horizontalRule`
- reorder rows with explicit `Up` and `Down` controls
- duplicate an existing row in place
- focus a specific row from the row header or outline
- collapse or expand individual rows without changing saved `bodyDoc`
- collapse or expand the whole draft from the toolbar
- reload the row builder from raw `bodyDoc` JSON
- compose inline mentions inside text and list rows with `[[tag]]` or
  `[[tag|label]]`
- insert mention tokens with the inline helper without hand-typing the syntax

The builder now also exposes a shell around the row list:

- live outline sidebar with node count and type summary
- per-row summary line that reflects the current node payload
- quick navigation between rows without scrolling manually
- compact collapsed mode for long drafts with summary-first scanning
- live preview cards for text, heading, quote, list, mention, divider, and
  media-embed rows

## Mention Flow

`tagMention` rows provide:

- autocomplete-backed tag lookup
- canonical-name capture for save payloads
- optional label override

This closes the earlier gap where structured mentions were model-supported but
effectively JSON-only to author.

Text, heading, quote, and list rows now also provide:

- token-aware inline mention authoring
- autocomplete-backed mention token insertion
- mixed text-plus-mention composition in the same row

## Media Embed Flow

`mediaEmbed` rows provide:

- direct `mediaItemId` entry
- search-by-query against the media API
- pick-from-results flow
- selected-media preview card
- optional caption and display mode fields

This makes common media-embed authoring possible without leaving the tag page
editor.

## Editor Shell

The current shell is still guided rather than fully WYSIWYG, but it now closes
much more of the usability gap from the TagKB references.

Current shell capabilities:

- quick-add palette for the most common node types
- outline list with compact summaries for each node
- duplicate/focus actions at the row level
- active-row highlighting while editing
- summary strings for paragraphs, lists, mentions, embeds, and headings
- live inline-preview chips for `[[tag]]` and `[[tag|label]]` tokens
- node preview shells for heading level, quotes, lists, divider, and media
  embed mode/caption

## Render Surface

Structured blocks now also emit `renderedBodyHtml` from the server.

Current live consumers:

- tag summary
- page preview

This means the common structured nodes are no longer visible only through the
markdown-style fallback text when browsing or previewing a page.

## Safety Valve

The raw structured JSON textarea remains visible as an advanced fallback.

This is intentional because the current row builder covers the common node
shapes from the TagKB docs, but not every possible nested or mixed inline
structure.

## Remaining Gaps

- full Tiptap-class editor shell
- richer visual inline editing beyond the current token-based approach
- broader structured HTML usage across the remaining public/translation paths
- richer media embed presentation in public page rendering
