# MuseArchive Summary

작성 기준일: 2026-03-22  
작성 범위: 현재 워킹트리 전체 읽기 전용 분석 + `flutter analyze` + `flutter test` + `flutter pub outdated` 결과 반영

## 목적

이 폴더는 MuseArchive 프로젝트를 빠르게 이해하고, 현재 상태를 안전하게 개선하기 위한 기준 문서 세트다.  
문서의 목표는 다음과 같다.

- 프로젝트의 전체 구조를 한 번에 파악할 수 있게 한다.
- 화면, ViewModel, 저장소, 외부 API가 어떻게 연결되는지 추적 가능하게 만든다.
- 지금 구현된 기능이 무엇을 하는지, 어디서 시작되고 어디로 이어지는지 설명한다.
- 현재 코드베이스에서 실제로 주의해야 하는 구조 리스크와 설정 문제를 분리해 기록한다.
- 이후 리팩터링과 테스트 확장을 할 때 기준선 역할을 하게 한다.

## 현재 상태 요약

### 실행/검증 기준선

- `flutter test`: 통과, `9 tests passed`
- `flutter analyze`: `No issues found!`
- `flutter pub outdated`: 잠긴 구버전 다수, 직접 제약으로 최신 해상 버전까지 못 올라가는 패키지 2개

### 구조 요약

- 앱은 `Provider + ChangeNotifier` 기반의 MVVM 성격을 가진다.
- 하지만 모든 화면이 ViewModel을 통하지는 않는다.
- 핵심 데이터 허브는 `lib/services/album_repository.dart` 하나에 집중되어 있다.
- 외부 메타데이터 소스는 `Discogs`, `Spotify`, `VocaDB`, `MusicBrainz` 네 갈래다.
- 유지보수 화면은 테마, API 자격 증명, 백업/복원, 업데이트 확인을 한 화면에 모아둔 운영 허브 역할을 한다.

### 가장 중요한 리스크

- `AddScreen`에 비동기 `BuildContext` 사용 경고가 집중되어 있다.
- `AlbumFormViewModel.isSpotifyConfigured()`가 항상 `true`를 반환한다.
- DI가 일관되지 않아 일부 화면이 Provider 대신 저장소/서비스를 직접 만든다.
- `AlbumRepository`가 CRUD, 파일 복사, 아티스트 인덱싱, 백업/복원을 모두 떠안고 있다.
- 플랫폼 설정에는 템플릿 흔적과 배포 준비 미완성 항목이 남아 있다.

## 문서 목록

- [Architecture.md](./Architecture.md)
  - 레이어 구조, 책임 분리, 의존성 흐름, 상태 소유권
- [Features-And-Flows.md](./Features-And-Flows.md)
  - 화면별 기능 설명, 사용자 플로우, 호출 관계
- [Data-And-Integrations.md](./Data-And-Integrations.md)
  - 로컬 저장 구조, 이미지 처리, 백업 포맷, 외부 API 연동 방식
- [Audit-And-Risks.md](./Audit-And-Risks.md)
  - 구조/설정/플랫폼/런타임 리스크 감사 결과와 우선순위
- [Testing-And-QA.md](./Testing-And-QA.md)
  - 현재 테스트 범위, 공백, 수동 QA 체크리스트, 확장 제안

## 빠른 구조 지도

```text
lib/
  main.dart                         앱 시작점, Provider 구성
  models/                           Album, Artist, Track, ReleaseDate
  services/                         저장소, 외부 API, 테마, 업데이트
  viewmodels/                       홈/폼/아티스트 상태 관리
  screens/                          홈, 추가/수정, 상세, 아티스트, 설정, 곡 목록, 바코드
  widgets/common_widgets.dart       공용 UI 조각
  utils/theme.dart                  Material 테마 정의
test/
  widget_test.dart                  ReleaseDate, EmptyState
  detail_screen_test.dart           상세 화면 앱바 스타일
```

## 진행도

- 프로젝트 구조 분석: `100%`
- 기능 연결 분석: `100%`
- 설정/플랫폼 감사: `100%`
- 자동 검증 기준선 확보: `100%`
- `docs/Summary` 문서화: `100%`

## 남은 작업

### 즉시 수정해도 되는 안전한 작업

- `docs/qa/testsprite/` 생성 산출물 및 민감 정보 유입 재발 방지
- `docs/Role/AGENTS.md`의 문서 경로 드리프트 정리
- 레거시 TagMaster 문서 archive 정리

### 회귀 테스트와 같이 묶어야 하는 작업

- `lib/screens/add_screen.dart`의 async `BuildContext` 경고 정리
- `AddScreen`의 `_viewModel` 초기화/해제 레이스 방지
- `lib/services/album_repository.dart`의 백업/복원 회귀 테스트 추가

### 배포 전 필수 작업

- Android release 서명/최적화 설정 정리
- `org.gradle.java.home`의 로컬 PC 고정 경로 제거
- iOS/macOS 권한 및 entitlement 재검토
- 템플릿 앱명/번들 ID 정리

### 품질 투자 작업

- 저장소 CRUD/백업/복원 테스트 추가
- 홈 재정렬, 추가 화면 자동 저장, 설정 실패 경로 테스트 추가
- 플랫폼별 실제 기기 QA 시나리오 정착

## 읽는 순서 권장

1. 구조를 먼저 파악하려면 `Architecture.md`
2. 사용자 관점 기능을 먼저 보려면 `Features-And-Flows.md`
3. 저장/백업/API 연동을 보려면 `Data-And-Integrations.md`
4. 무엇부터 고쳐야 하는지 보려면 `Audit-And-Risks.md`
5. 검증 전략까지 이어서 보려면 `Testing-And-QA.md`
