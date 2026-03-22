# Features And Flows

## 1. 기능 지형도

MuseArchive의 사용자 기능은 크게 여섯 묶음으로 나뉜다.

1. 컬렉션/위시리스트 탐색
2. 앨범 추가 및 수정
3. 앨범 상세 감상과 관리
4. 아티스트 단위 탐색
5. 곡 단위 탐색
6. 운영 설정과 백업/업데이트

각 기능은 독립적으로 보이지만 실제로는 하나의 로컬 데이터 집합을 공유한다.

## 2. 홈 화면

파일:

- `lib/screens/home_screen.dart`
- `lib/viewmodels/home_viewmodel.dart`

## 2.1 사용자에게 보이는 기능

- 컬렉션 / 위시리스트 세그먼트 전환
- 검색창 토글
- 정렬 옵션 선택
- 보기 모드 전환
  - 2열 그리드
  - 3열 그리드
  - 아티스트 목록
- 드래그 재정렬
- 카드 길게 눌러 이동/삭제
- 설정 진입
- 곡 목록 화면 진입
- 새 앨범 추가

## 2.2 내부 동작

### 컬렉션/위시리스트 전환

- `PageView`와 `CupertinoSlidingSegmentedControl`이 서로 동기화된다.
- 실제 필터링은 `HomeViewModel.getAlbumsForView()`가 담당한다.

### 검색

- 앱바가 검색 모드로 바뀌면 `searchController`가 활성화된다.
- 검색 대상:
  - 앨범 제목
  - 대표 아티스트명
  - 아티스트 alias
  - 장르
  - 스타일
  - 포맷

### 정렬

- 지원 정렬:
  - custom
  - artist
  - title
  - dateDescending
  - dateAscending

### 보기 모드

- `grid2 -> grid3 -> artists -> grid2` 순환 토글
- 같은 데이터라도 표현 방식만 바뀐다.

### 재정렬

- 시각적으로 보이는 목록 인덱스를 실제 `_allAlbums` 인덱스로 환산해 저장소에 전달한다.
- 이 로직은 collection/wishlist 필터가 걸린 상태에서도 동작하도록 설계돼 있다.

## 2.3 주요 사용자 시나리오

### 시나리오 A: 일반 탐색

1. 앱 실행
2. 홈에서 컬렉션 목록 확인
3. 카드 탭
4. 상세 진입

### 시나리오 B: 위시리스트 이동

1. 카드 길게 누름
2. 액션 시트에서 컬렉션/위시리스트 이동
3. `HomeViewModel.toggleWishlistStatus()`
4. 저장소 업데이트
5. 홈 자동 갱신

### 시나리오 C: 아티스트 중심 탐색

1. 보기 모드 전환
2. 아티스트 목록 선택
3. `ArtistDetailScreen` 진입

## 3. 앨범 추가/수정 화면

파일:

- `lib/screens/add_screen.dart`
- `lib/viewmodels/album_form_viewmodel.dart`

## 3.1 화면 구성

섹션은 대략 다음 순서다.

- 기본 정보
  - 커버 이미지
  - 제목
  - 번역 제목
  - 아티스트
  - 카탈로그 번호
- 추가 정보
  - 설명
  - 발매일
  - 음악 링크
- 분류 정보
  - 레이블
  - 포맷
  - 장르
  - 스타일
- 옵션
  - 한정판
  - 특이사항
  - 위시리스트 여부
- 트랙 리스트
  - 디스크 헤더
  - 개별 트랙

## 3.2 가장 중요한 특성: 자동 저장

- 필드가 바뀌면 debounce 타이머가 돈다.
- 일정 시간 후 `_saveIfNeeded()`가 호출된다.
- 제목과 아티스트가 비어 있지 않을 때만 저장한다.
- 최초 저장 성공 후 생성된 앨범 ID를 화면 상태에 보관한다.
- 뒤로 가기 시에도 마지막 저장을 한 번 더 시도한다.

이 구조 때문에 사용자는 "완료 버튼" 없이도 편집이 유지된다고 느끼게 된다.

## 3.3 외부 메타데이터 가져오기

### Discogs

- 바코드 스캔
- 제목/아티스트 검색
- 커버 이미지 전용 검색

### VocaDB

- 제목/아티스트 조합 검색
- 결과 선택 시 앨범 전체 메타데이터 병합

### MusicBrainz

- Lucene 스타일 질의 구성
- 결과 선택 시 상세 조회 + 커버 다운로드 시도

### Spotify

- 커버 이미지 가져오기
- 외부 링크 연결

## 3.4 이미지 선택 흐름

커버 이미지는 세 가지 경로가 있다.

- 기기 갤러리 선택
- Discogs 검색 결과 이미지 사용
- Spotify 검색 결과 이미지 사용

실제 영구 저장은 즉시가 아니라 앨범 저장 시점에 `AlbumRepository`가 앱 문서 폴더로 복사한다.

## 3.5 트랙 편집

지원 기능:

- 트랙 추가
- 트랙 수정
- 트랙 삭제
- 순서 변경
- 새 디스크 헤더 추가

트랙 리스트는 일반 트랙과 `isHeader=true` 항목을 같은 배열에 섞어 보관한다.

## 3.6 사용자 가치

이 화면은 단순 폼이 아니라 다음 역할을 동시에 수행한다.

- 데이터 입력 UI
- 외부 메타데이터 병합 UI
- 커버 선택 UI
- 링크 연결 UI
- 트랙 편집 UI
- 자동 저장 편집기

현재 프로젝트에서 가장 복잡한 화면이다.

## 4. 앨범 상세 화면

파일:

- `lib/screens/detail_screen.dart`

## 4.1 보이는 기능

- 상단 커버 헤더
- 접힘/펼침 상태에 따라 바뀌는 앱바
- 아티스트 클릭 이동
- 음악 링크 실행
- 즐겨찾기(위시리스트) 토글
- 편집 진입
- 삭제
- 설명 표시
- 트랙 리스트 표시

## 4.2 내부 동작

- 화면은 `Album` 객체를 직접 받는다.
- 스크롤 위치에 따라 앱바 스타일을 계산한다.
- 편집 후 돌아오면 저장소에서 같은 ID의 최신 앨범을 다시 읽어 현재 상태를 갱신한다.
- 삭제 성공 시 이전 화면으로 `true`를 반환해 홈이 새로고침할 수 있게 한다.

## 4.3 데이터 사용 방식

표시 우선순위:

- 제목: `titleKr`가 있으면 우선
- 부제: `titleKr`가 있을 때 원제목을 보조 제목으로 사용
- 아티스트: 여러 명이면 `Wrap`으로 렌더링
- 링크: `linkUrl`이 비어 있지 않을 때만 버튼 표시
- 설명/트랙 리스트: 데이터가 있을 때만 섹션 노출

## 5. 아티스트 상세 화면

파일:

- `lib/screens/artist_detail_screen.dart`
- `lib/viewmodels/artist_viewmodel.dart`
- `lib/viewmodels/global_artist_settings.dart`

## 5.1 사용자 기능

- 아티스트 이미지 보기/변경/삭제
- alias 관리
- 그룹/소속 문자열 관리
- 연결된 앨범 목록 보기
- 발매일 순 정렬 토글
- 현재 상세 화면에서 넘어온 원본 앨범 강조

## 5.2 내부 흐름

1. 화면 진입
2. `ArtistViewModel.loadArtistData(artistName)`
3. 저장소에서 아티스트와 연결 앨범 조회
4. `GlobalArtistSettings`에 따라 발매일 정렬
5. 목록 렌더링

## 5.3 시각적 특징

- 상단 대형 헤더
- 원형 프로필 이미지
- 위시리스트 앨범은 흐리게 표시
- source album은 강조 색상과 배지 사용
- 포맷 배지는 LP/CD/DVD/Blu-ray 우선순위 기반으로 그림

## 6. 곡 목록 화면

파일:

- `lib/screens/all_songs_screen.dart`

## 6.1 사용자 기능

- 모든 곡 한 번에 보기
- 곡/아티스트 검색
- 위시리스트 포함 여부 토글
- 같은 곡이 실린 다른 앨범 찾기
- 곡에서 바로 앨범 상세 이동

## 6.2 내부 처리 방식

1. 저장소에서 모든 앨범 로드
2. 각 앨범의 트랙을 순회
3. `isHeader=false`인 실제 곡만 평탄화
4. `_SongWithAlbumRef`로 곡과 원본 앨범을 묶어 유지
5. 검색어/필터에 맞게 재필터링

## 6.3 검색 기준

- 곡 제목
- 곡 번역 제목
- 아티스트명
- 아티스트 alias

## 7. 설정 화면

파일:

- `lib/screens/settings_screen.dart`
- `lib/services/theme_manager.dart`
- `lib/services/update_service.dart`

## 7.1 기능 목록

- 다크/라이트 테마 전환
- Discogs API 토큰 저장
- Discogs 연결 테스트
- Spotify Client ID/Secret 저장
- Spotify 연결 테스트
- 백업 파일 생성 및 기기 저장
- 백업 복원
- 업데이트 확인
- APK 다운로드/설치 유도

## 7.2 설정이 연결되는 실제 기능

### Discogs 설정

- 바코드 검색
- 제목/아티스트 검색
- Discogs 기반 커버 검색

### Spotify 설정

- 앨범 링크 검색
- 커버 검색

### 테마 설정

- 앱 전체 `ThemeMode` 반영

### 백업/복원

- 저장소 전체 로컬 데이터 관리

## 7.3 업데이트 기능 해석

- GitHub releases의 최신 릴리스를 조회한다.
- 현재 버전보다 최신이면 다이얼로그를 연다.
- APK 자산이 있으면 해당 URL을 우선 사용한다.
- 다운로드 후 시스템에 파일 열기를 요청한다.

## 8. 바코드 스캐너

파일:

- `lib/screens/barcode_scanner_screen.dart`

## 8.1 역할

- 독립 화면으로 카메라를 열고 바코드를 한 번 스캔한 뒤 결과를 부모 화면으로 반환한다.

## 8.2 부가 기능

- 플래시 토글
- 전면/후면 카메라 전환

## 9. 기능 간 연결 관계 요약

```text
HomeScreen
  -> DetailScreen
  -> AddScreen
  -> ArtistDetailScreen
  -> AllSongsScreen
  -> SettingsScreen

AddScreen
  -> BarcodeScannerScreen
  -> Discogs / VocaDB / MusicBrainz / Spotify Service 호출
  -> AlbumRepository 저장

DetailScreen
  -> AddScreen
  -> ArtistDetailScreen
  -> AlbumRepository update/delete

ArtistDetailScreen
  -> ArtistViewModel
  -> AlbumRepository artist update
  -> DetailScreen

SettingsScreen
  -> ThemeManager
  -> DiscogsService / SpotifyService
  -> AlbumRepository backup/restore
  -> UpdateService
```

## 10. 기능적으로 눈에 띄는 설계 특징

- "앨범"이 앱의 중심 엔티티이며, 아티스트와 곡 화면은 모두 앨범 집합에서 파생된다.
- 입력 화면은 완료형 폼보다 편집기형 문서에 가깝다.
- 상세 화면은 읽기 전용 뷰 같지만 실제로는 상태 변경 허브이기도 하다.
- 설정 화면은 단순 환경설정이 아니라 운영 콘솔 역할을 한다.
