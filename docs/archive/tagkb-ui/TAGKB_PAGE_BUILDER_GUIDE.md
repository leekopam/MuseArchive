# TagKB Page Builder Guide

기준일: 2026-03-15

## 목적

`tagkb_docs`의 page builder 문서를 바탕으로,
현재 TagMaster 편집 UI가 실제로 어떻게 동작하는지 정리한다.

## 현재 편집기에서 가능한 것

- 블록 추가
- 블록 삭제
- 블록 순서 이동
- 블록 복제
- 블록 접기/펼치기
- 저장 전 dirty 상태 표시
- block translation 추가
- relation query 방향 선택
- media ref용 media picker 검색
- page template 선택 및 적용

## 현재 편집기 block type 목록

- `basic_info`
- `alias_badges`
- `header`
- `rich_text`
- `relation_list`
- `relation_gallery`
- `manual_tag_list`
- `manual_tag_gallery`
- `item_gallery`
- `auto_related`
- `tag_collection`
- `post_gallery`
- `metadata_table`

## source mode 기본 규칙

- `relation_list`, `relation_gallery`, `auto_related`, `item_gallery`
  - 비워 두면 `query`

- `manual_tag_list`, `manual_tag_gallery`
  - 비워 두면 `manual`

- `tag_collection`
  - 사용자가 직접 선택

## display mode 기본 규칙

- `relation_gallery`, `manual_tag_gallery`, `item_gallery`
  - 비워 두면 `gallery`

- `relation_list`, `manual_tag_list`, `auto_related`
  - 비워 두면 `list`

## block type별 편집 포인트

### `basic_info`

- 추가 본문 없이 읽기용 요약 블록으로 사용
- canonical/category/alias/translation 수를 표시

### `alias_badges`

- 현재 태그의 alias 배지를 요약해서 표시

### `header`

- 짧은 상단 설명용
- `markdown` 또는 `structured` body 사용
- structured 모드에서는 JSON 기반 `bodyDoc` 입력 가능

### `rich_text`

- 일반 설명 블록
- `markdown` 또는 `structured` body 사용
- structured 모드에서는 JSON 기반 `bodyDoc` 입력 가능
- 아직 Tiptap형 시각 편집기는 아님

### `relation_list`

- query 중심
- list 출력
- `incoming`/`outgoing` 가능

### `relation_gallery`

- query 중심
- gallery 출력
- 캐릭터 appearance/costume 같은 용도에 적합

### `manual_tag_list`

- 수동 태그 목록
- `Others` 같은 텍스트 중심 섹션에 적합

### `manual_tag_gallery`

- 수동 태그 카드 갤러리
- `By volume / length`, `Styles` 같은 구역에 적합

### `item_gallery`

- 포스트/아이템 예시 영역
- query/manual/mixed 지원

### `auto_related`

- 자동 연관 태그 표시
- list 출력

## 현재 UI에서 아직 없는 것

- drag and drop
- block inspector 분리 패널
- rich text mention picker
- structured body 시각 편집기
- media embed 편집기
- per-entry preview override 편집기
- publish review polish

## page template 흐름

- 템플릿 선택
- `기존 블록 교체`
- `현재 블록 뒤에 추가`

현재 템플릿:

- `character_core`
- `work_core`
- `group_core`

## publish 흐름

- page 저장 시 상태는 `draft`
- summary 화면에서 `페이지 게시` 버튼으로 explicit publish
- 게시 후 다시 page를 수정하면 다음 저장부터 다시 `draft`

## 운영 팁

- `tag_group`, `anatomy`, `reference` 계열은
  `manual_tag_gallery + manual_tag_list` 조합이 현재 UI와 가장 잘 맞는다.

- 캐릭터 페이지는
  `relation_gallery + relation_list + item_gallery` 조합이 가장 안정적이다.

- 아직 semantic block type이 새로 추가된 직후라서,
  import나 seed에서 block payload를 만들 때는 `settings.relationKeys`와
  `relationDirection`을 함께 넣는 편이 안전하다.
