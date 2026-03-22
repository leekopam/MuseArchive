# Audit And Risks

## 1. 감사 범위

이번 감사는 다음 기준으로 수행됐다.

- 코드베이스 전체 구조 읽기
- 핵심 화면/저장소/서비스 직접 확인
- 서브 에이전트 병렬 분석
  - 아키텍처 관점
  - 설정/플랫폼 관점
  - 런타임/회귀 관점
- 로컬 검증 실행
  - `flutter analyze`
  - `flutter test`
  - `flutter pub outdated`

주의:

- 워킹트리는 이미 dirty 상태였다.
- 기존 미커밋 변경은 사용자의 작업으로 간주하고 건드리지 않았다.
- 이번 문서는 진단과 구조화가 목적이며, 앱 동작을 바꾸는 코드 수정은 수행하지 않았다.

## 2. 검증 결과 요약

### 정적 분석

- 에러/워닝 없음
- `info 15건`

주요 발생 파일:

- `lib/screens/add_screen.dart`
- `lib/screens/all_songs_screen.dart`

### 테스트

- 총 5개 테스트 통과

현재 테스트 파일:

- `test/widget_test.dart`
- `test/detail_screen_test.dart`

### 패키지 상태

- lockfile 기준 업그레이드 가능 패키지 다수
- 직접 제약 때문에 최신 해상 버전까지 못 가는 패키지 2개
- 전이 의존성 `path_provider_foundation 2.5.0` retracted

## 3. 심각도 기준

- `높음`
  - 실제 기능 오동작, 배포 차단, 데이터 손실, 플랫폼 실행 실패 가능성
- `중간`
  - 즉시 치명적이지 않지만 유지보수성/회귀 위험을 키우는 구조 문제
- `낮음`
  - 지금 당장 문제는 아니지만 품질을 떨어뜨리는 불일치나 부채

## 4. 주요 발견 사항

## 4.1 높음

### A1. `AddScreen` 비동기 컨텍스트 사용 경고 집중

파일:

- `lib/screens/add_screen.dart`

대표 라인:

- 226
- 228
- 511
- 733
- 962
- 966
- 1139
- 1266
- 1360
- 1362
- 1418

설명:

- `await` 이후 기존 `context`를 사용해 다이얼로그, 스낵바, 화면 전환을 이어가는 패턴이 남아 있다.
- 현재는 analyzer level이 `info`지만, 실제로는 화면 dispose 타이밍과 겹치면 회귀가 날 수 있다.

영향:

- 다이얼로그/바텀시트 닫힌 뒤 잘못된 context 사용
- 이미 pop된 화면에 Snackbar 표시 시도
- 빠른 연속 조작에서 상태 꼬임

권장 조치:

- `if (!mounted) return;` 위치 재정리
- 필요한 경우 local context 분리
- 다이얼로그를 닫은 뒤 부모 context 접근 패턴 정리

### A2. `AddScreen` 초기화/해제 레이스 가능성

파일:

- `lib/screens/add_screen.dart`

설명:

- `_viewModel`은 post-frame callback에서 할당된다.
- 하지만 `dispose()`는 해당 필드를 항상 사용한다.

영향:

- 아주 빠른 pop 시 `LateInitializationError` 가능성

권장 조치:

- nullable로 전환하거나
- listener 등록 여부를 별도 플래그로 관리

### A3. Spotify 설정 판별 경로는 현재 해결됨

파일:

- `lib/viewmodels/album_form_viewmodel.dart`

현재 상태:

- `isSpotifyConfigured()`는 `SharedPreferences` 기반 실제 설정값을 읽는다.
- 설정 화면과 같은 키 경로를 공유하도록 정리됐다.

잔여 메모:

- 회귀 방지를 위해 관련 테스트는 계속 유지하는 편이 좋다.

### A4. 백업/복원 무결성 리스크

파일:

- `lib/services/album_repository.dart`

설명:

- 백업은 앨범 이미지 중심
- 복원은 기존 박스를 먼저 비운다
- 실패 시 롤백이 없다

영향:

- 부분 복원
- 데이터 손실
- 아티스트 이미지 누락

권장 조치:

- 임시 박스/스테이징 복원
- 성공 후 swap 방식
- 백업 범위 명확화

### A5. 플랫폼 실행/배포 설정 미완성

영역:

- Android
- iOS
- macOS
- web
- Windows/Linux/macOS 앱명/ID

설명:

- Android release는 debug signing 기준
- `org.gradle.java.home`가 특정 PC 경로에 고정
- iOS `Info.plist`에 카메라/사진 권한 설명 부재
- macOS entitlement에 네트워크 사용과 불일치
- web와 데스크톱에 템플릿 앱명/식별자 잔존

영향:

- 다른 PC/CI 빌드 실패
- 스토어/배포 준비 불가
- 플랫폼 런타임 기능 제한

## 4.2 중간

### B1. DI 불일치

파일:

- `lib/main.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/all_songs_screen.dart`

설명:

- Provider로 넣은 객체를 일부 화면이 직접 새로 만든다.
- `SpotifyService`는 Provider와 ViewModel 생성 시 중복 생성된다.

영향:

- 테스트 대체 어려움
- 설정/상태 일관성 추적 난이도 증가

### B2. ViewModel 우회 경로 존재

파일:

- `lib/screens/detail_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/all_songs_screen.dart`

설명:

- 홈/폼/아티스트는 ViewModel이 있으나, 일부 화면은 저장소를 직접 호출한다.

영향:

- 구조 설명이 일관되지 않음
- 화면 테스트가 상태 테스트와 분리되기 어려움

### B3. 저장소 비대화

파일:

- `lib/services/album_repository.dart`

설명:

- CRUD
- 파일 복사/삭제
- 아티스트 인덱스
- 백업/복원
- 옵션 집계

이 모든 책임이 한 클래스에 모여 있다.

영향:

- 변경 영향 범위 확대
- 테스트 복잡도 증가

### B4. 폼 ViewModel 비대화

파일:

- `lib/viewmodels/album_form_viewmodel.dart`

설명:

- 저장
- 네 개 외부 서비스 연동
- 커버 업데이트
- 트랙 편집
- 옵션 목록 제공

영향:

- 폼 관련 회귀가 한 군데로 집중
- 관심사 분리가 약함

### B5. 테스트 범위가 얇음

현재 자동 테스트는 다음 정도만 보장한다.

- `ReleaseDate` 파싱
- `EmptyState` 렌더링
- 상세 화면 앱바 스타일

비어 있는 영역:

- 저장소 CRUD
- 백업/복원
- 홈 정렬/재정렬
- AddScreen 자동 저장
- 설정 실패 경로

## 4.3 낮음

### C1. 템플릿 흔적

- `my_album_app`
- `com.example`
- 기본 web 설명 문구

### C2. 코드 위생 문제

- `docs/qa/testsprite/tmp/`에 생성 산출물과 민감 정보가 섞여 들어간 이력
- `docs/Role/AGENTS.md`의 오래된 문서 경로 참조
- `add_screen.dart`의 잔여 구조 복잡도와 테스트 공백

## 5. 우선순위별 정리 계획

## Phase 1. 안전한 위생 정리

목표:

- 동작 변화 없이 눈에 띄는 저위험 문제 제거

항목:

- QA 생성 산출물 ignore 및 민감 정보 차단
- 문서 경로 드리프트 정리
- 레거시 문서 archive 정리

## Phase 2. 회귀 방지와 함께 처리할 작업

목표:

- 사용자 조작 중 터질 수 있는 흐름 안정화

항목:

- `AddScreen` async context 정리
- `AddScreen` dispose race 방지
- 홈/폼/설정 관련 테스트 추가

## Phase 3. 구조 정리

목표:

- 유지보수 비용 감소

항목:

- DI 방식 통일
- 상세/설정/곡 목록의 상태 계층 정리
- 저장소 분리 검토

## Phase 4. 배포 정리

목표:

- 실제 배포 가능한 상태 확보

항목:

- Android release signing
- PC 고정 JDK 경로 제거
- iOS 권한 키 추가
- macOS entitlement 조정
- 앱명/번들 ID/manifest 정리

## 6. 지금 당장 수정하지 않은 이유

이번 턴의 핵심 요구는 "프로젝트 전체 분석"과 "아주 자세한 문서화"였다.  
또한 사용자는 현재 작동 중인 기능에 문제가 생기면 안 된다고 명시했다.

따라서 이번에는 다음 원칙을 적용했다.

- 코드 동작을 바꾸는 변경은 하지 않음
- 기준선 검증만 수행
- 리스크를 우선 문서화
- 이후 수정은 우선순위와 검증 계획이 있는 상태에서 진행

이 접근은 특히 dirty worktree 환경에서 안전하다.
