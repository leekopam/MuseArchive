# TagKB Template Browser Surface

Date: 2026-03-15

## Purpose

This document describes the project-local template preview/apply surface that
was derived from the `FYI` references without modifying the original `FYI`
files.

Primary reference sources:

- `admin_wireframes_v1.md`
- `frontend_component_spec_v1.md`
- `sample_seed_dataset_and_bootstrap_strategy_v1.md`

## What Exists Now

- template selector inside the tag page editor
- browser-style template card list
- selected-template detail preview
- selected-template metrics for:
  - query-driven block count
  - gallery-oriented block count
  - translated block count
  - manual entry row count
  - relation query key coverage
- block-by-block template snapshot
- block-level source/display chips
- block-level relation-query chips
- current page snapshot alongside the template snapshot
- quick result metrics for:
  - current block count
  - replace result count
  - append result count

## Interaction Model

### 1. Browse

Each template is shown as a selectable card with:

- title
- key
- block count
- description

### 2. Preview

When a template is selected, the editor now shows:

- template summary metrics
- template composition metrics
- template description
- the block sequence that the template will apply
- relation query semantics for each applicable block
- the current page block sequence for comparison

### 3. Apply

Editors can still choose between:

- replace the current block set
- append template blocks after the current block set

The preview exists to make that choice less blind.

## Remaining Gaps

- dedicated template management CRUD
- template versioning/history
- richer visual block thumbnails
- Playwright coverage for template browser interactions
