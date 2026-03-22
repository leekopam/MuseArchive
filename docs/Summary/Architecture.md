# Architecture

## 1. 설계 개요

MuseArchive는 로컬 중심의 Flutter 컬렉션 앱이다.  
핵심 관심사는 "앨범 메타데이터를 저장하고, 화면에서 그 데이터를 검색/정렬/편집/백업 가능한 형태로 유지하는 것"이다.

현재 구조는 완전한 클린 아키텍처라기보다 다음 성격이 섞여 있다.

- UI는 `Screen` 중심
- 상태는 `ChangeNotifier` 기반 ViewModel 일부 사용
- 데이터는 단일 로컬 저장소 객체에 집중
- 외부 API는 서비스 객체로 분리
- 화면에 따라 ViewModel을 통하기도 하고, 저장소/서비스를 직접 부르기도 함

즉, "MVVM 성향의 실용적 구조"로 보는 편이 정확하다.

## 2. 런타임 시작 구조

앱 진입점은 `lib/main.dart`다.

### 시작 순서

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `AlbumRepository` 싱글턴 생성
3. `DiscogsService`, `VocadbService`, `MusicBrainzService` 생성
4. `albumRepository.init()`로 Hive 박스 열기
5. `loadTheme()`로 저장된 테마 모드 읽기
6. `MultiProvider`로 서비스와 ViewModel 주입
7. `MyApp` 실행

### Provider 구성

`lib/main.dart`

- `Provider<IAlbumRepository>`: `AlbumRepository`
- `Provider<DiscogsService>`
- `Provider<VocadbService>`
- `Provider<MusicBrainzService>`
- `Provider<SpotifyService>`
- `ChangeNotifierProvider<HomeViewModel>`
- `ChangeNotifierProvider<GlobalArtistSettings>`
- `ChangeNotifierProxyProvider5<... , AlbumFormViewModel>`

### 해석

- 앱 전체 데이터는 사실상 `AlbumRepository` 하나를 중심으로 돈다.
- `HomeViewModel`은 전역 홈 상태를 가진다.
- `AlbumFormViewModel`은 추가/수정 화면 상태를 담당한다.
- `ArtistViewModel`은 화면 진입 시 로컬 생성되는 화면 단위 ViewModel이다.

## 3. 레이어별 책임

## 3.1 Models

### `Album`

역할:

- 앱의 핵심 aggregate
- 화면 렌더링과 저장 포맷의 중심
- 다음 데이터를 묶는다:
  - 식별자
  - 제목/번역 제목
  - 아티스트 목록
  - 카탈로그 번호
  - 설명
  - 레이블/포맷/장르/스타일
  - 발매일
  - 외부 링크
  - 트랙 목록
  - 한정판/특별판/위시리스트 여부

특징:

- `toMap`/`fromMap`으로 Hive 저장 직렬화
- `copyWith`를 중심으로 상태 변경
- `artist` getter는 첫 번째 아티스트를 단일 대표값처럼 사용

### `Artist`

역할:

- 아티스트 중심 보기에서 사용하는 파생 엔티티
- 저장소 내부에서 앨범과 별도로 관리

포함 데이터:

- 이름
- 이미지 경로
- 연결된 앨범 ID 목록
- alias 목록
- groups 목록

### `Track`

역할:

- 앨범 트랙 목록의 단위

특이점:

- `isHeader`를 통해 "Disc 1", "Disc 2" 같은 구분 행을 같은 리스트 안에 섞어 저장한다.

### `ReleaseDate`

역할:

- 느슨한 날짜 입력을 정규화하는 값 객체

특징:

- `"2024.03.15"`, `"202403"`, `"2024-03-15"` 같은 입력을 흡수
- 내부는 `DateTime?`
- 포맷은 `YYYY.MM.DD`

## 3.2 Services

### `AlbumRepository`

실질적 허브 역할:

- Hive 초기화
- 앨범 CRUD
- 이미지 파일 복사/삭제
- 아티스트 인덱스 갱신
- 백업 zip 생성
- 백업 복원
- 검색용 옵션 목록 생성

현재 프로젝트에서 가장 많은 책임이 몰린 클래스다.

### 외부 메타데이터 서비스

- `DiscogsService`
- `SpotifyService`
- `VocadbService`
- `MusicBrainzService`

공통 책임:

- 원격 API 호출
- 검색 결과를 화면용 `Map`으로 변환
- 상세 정보를 `Album` 모델로 변환
- 일부 서비스는 커버 이미지를 임시 파일로 저장

### 기타 서비스

- `theme_manager.dart`
  - `SharedPreferences` 기반 다크/라이트 모드 저장
- `update_service.dart`
  - GitHub releases 기반 최신 버전 확인
  - APK 다운로드 후 열기

## 3.3 ViewModels

### `HomeViewModel`

책임:

- 전체 앨범 로딩
- 컬렉션/위시리스트 분리
- 검색어 상태
- 정렬 옵션
- 보기 모드 전환
- 홈 재정렬

특징:

- 저장소 `listenable`을 직접 구독
- 홈에서 보이는 목록은 항상 `_allAlbums`에서 파생

### `AlbumFormViewModel`

책임:

- 추가/수정 대상 앨범 상태 보유
- 저장 처리
- Discogs/VocaDB/MusicBrainz/Spotify 메타데이터 병합
- 커버 업데이트
- 트랙 편집
- 옵션 목록 조회

특징:

- 입력 상태 관리와 외부 연동 orchestration이 한 객체에 집중돼 있다.

### `ArtistViewModel`

책임:

- 특정 아티스트 상세 데이터 로드
- 아티스트 이미지 수정
- alias/groups 수정
- 발매일 정렬 적용

### `GlobalArtistSettings`

책임:

- 아티스트 화면 공통 정렬 순서 보관

성격:

- 매우 작은 전역 설정 저장소

## 3.4 Screens

### `HomeScreen`

역할:

- 앱 메인 허브
- 컬렉션/위시리스트 전환
- 그리드/아티스트 모드 전환
- 검색, 정렬, 재정렬, 상세 진입, 설정 진입

### `AddScreen`

역할:

- 신규 앨범 생성
- 기존 앨범 편집
- 자동 저장형 폼
- 외부 메타데이터 가져오기

### `DetailScreen`

역할:

- 앨범 단건 보기
- 즐겨찾기/편집/삭제
- 링크 실행
- 아티스트 상세 진입

### `ArtistDetailScreen`

역할:

- 아티스트 프로필 보기
- 연결된 앨범 목록 보기
- alias/groups 편집
- 이미지 변경

### `AllSongsScreen`

역할:

- 모든 앨범의 트랙을 곡 기준으로 탐색
- 같은 곡이 다른 앨범에도 있는지 확인

### `SettingsScreen`

역할:

- 운영/관리 허브
- 테마, API 자격 증명, 백업/복원, 업데이트

### `BarcodeScannerScreen`

역할:

- 바코드 스캔 결과를 문자열로 반환하는 보조 화면

## 4. 상태 소유권

### 전역 상태

- 테마: `themeNotifier`
- 홈 목록 상태: `HomeViewModel`
- 아티스트 정렬 방향: `GlobalArtistSettings`
- 앨범 추가/수정 상태: `AlbumFormViewModel`

### 화면 로컬 상태

- `AddScreen`
  - 폼 컨트롤러
  - debounce 타이머
  - 현재 앨범 ID
- `DetailScreen`
  - 스크롤 상태
  - 수정 여부
- `SettingsScreen`
  - 로딩 상태
  - 현재 입력 중인 API 자격 증명
- `AllSongsScreen`
  - 평탄화된 곡 목록
  - 검색어
  - 위시리스트 포함 여부

## 5. 데이터 흐름 요약

```text
UI Event
  -> Screen
  -> ViewModel 또는 직접 Service/Repository 호출
  -> AlbumRepository / External Service
  -> Model 변환
  -> notifyListeners 또는 setState
  -> Screen rebuild
```

실제 프로젝트에서는 이 흐름이 두 가지로 갈린다.

### ViewModel 경유 경로

- 홈 검색/정렬/재정렬
- 추가/수정 저장
- 외부 메타데이터 병합
- 아티스트 정렬

### 화면 직통 경로

- 상세 화면의 위시리스트 토글/삭제
- 설정 화면의 백업/복원/업데이트
- 곡 목록 화면의 전체 조회

## 6. 저장 계층 구조

### Hive 박스

- `albumBox`
- `artistBox`

### 파일 시스템

- `album_images/`
- `artist_images/`
- 임시 다운로드 파일
- 백업 zip 생성용 임시 폴더

### 해석

- 데이터는 "구조화된 메타데이터는 Hive", "이미지는 파일 시스템"으로 분리 저장된다.
- 따라서 단순 DB 백업만으로는 완전한 복원이 안 되고, 이미지 파일까지 함께 다뤄야 한다.

## 7. 현재 구조의 장점

- 작은 코드베이스에서 기능 추가가 빠르다.
- 저장소 하나로 로컬 데이터 흐름을 따라가기 쉽다.
- 외부 API 서비스가 분리되어 메타데이터 소스 확장이 가능하다.
- 홈, 폼, 아티스트라는 핵심 상태가 화면 단위로 비교적 잘 분리돼 있다.

## 8. 현재 구조의 한계

- 저장소 비대화
- ViewModel 계층 우회
- DI 일관성 부족
- 테스트하기 어려운 경로 존재
- 플랫폼 설정과 앱 코드의 분리 수준이 낮음

## 9. 구조적으로 추천되는 다음 단계

### 1단계

- DI 방식 통일
- 설정 판별 로직 실제화
- 경고 제거

### 2단계

- `AlbumRepository`를
  - `AlbumStore`
  - `ArtistIndexStore`
  - `BackupService`
  - `ImageStorageService`
  로 분리 검토

### 3단계

- 상세/설정/곡 목록도 ViewModel 경유 구조로 통일

### 4단계

- 테스트 기준선을 저장소/폼/홈 흐름까지 확대
