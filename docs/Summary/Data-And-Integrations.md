# Data And Integrations

## 1. 로컬 데이터 저장 구조

MuseArchive는 네트워크 앱이 아니라 "로컬 우선 저장 + 필요 시 외부 메타데이터 조회" 구조다.

핵심 저장 매체는 두 가지다.

- Hive 박스
- 앱 문서 폴더 내부 이미지 파일

## 2. Hive 박스

파일:

- `lib/services/album_repository.dart`
- `lib/services/i_album_repository.dart`

### 박스 종류

- `albumBox`
- `artistBox`

### 저장 단위

- `Album.toMap()`
- `Artist.toMap()`

### 접근 방식

- `AlbumRepository.getAll()`
- `AlbumRepository.add()`
- `AlbumRepository.update()`
- `AlbumRepository.delete()`
- `AlbumRepository.getAllArtists()`
- `AlbumRepository.getArtistByName()`

### 해석

- 앨범과 아티스트는 별도 박스로 나뉘지만 강하게 연동된다.
- 아티스트 데이터는 독립 원천 데이터라기보다 앨범 데이터에서 파생된 인덱스에 가깝다.

## 3. 앨범 저장 라이프사이클

### 신규 저장

1. `AddScreen`에서 폼 변경
2. `AlbumFormViewModel.saveAlbum(null)`
3. `AlbumRepository.add(album)`
4. 필요 시 이미지 파일을 앱 문서 폴더로 복사
5. `albumBox`에 앨범 저장
6. `_updateArtistAlbums()`로 아티스트 인덱스 갱신

### 수정 저장

1. 기존 ID 기반 수정 요청
2. `albumBox`를 순회해 해당 ID의 내부 key 탐색
3. 이미지가 달라졌으면 기존 이미지 삭제 후 새 파일 복사
4. 앨범 정보 갱신
5. old/new artist set diff 계산
6. 아티스트 인덱스 추가/삭제 반영

### 삭제

1. ID로 박스 항목 탐색
2. 커버 파일 삭제
3. 앨범 레코드 삭제
4. 아티스트 인덱스에서 albumId 제거
5. 비어 있는 아티스트는 삭제

## 4. 이미지 처리

### 앨범 커버

입력 경로:

- 기기 갤러리
- Discogs 이미지 다운로드
- Spotify 이미지 다운로드
- VocaDB 상세에서 원본 이미지 다운로드
- MusicBrainz Cover Art Archive 다운로드

영구화 방식:

- 외부 서비스는 우선 임시 디렉터리에 파일 저장
- 실제 영구 저장은 `AlbumRepository.add/update` 시 `album_images/`로 복사

### 아티스트 이미지

- `ArtistDetailScreen`에서 갤러리 선택
- `AlbumRepository.updateArtistImage()`가 `artist_images/`로 복사

### 주의점

- 백업은 현재 앨범 이미지 중심이며, 아티스트 이미지까지 완전하게 다루지 못한다.

## 5. 아티스트 인덱싱 방식

아티스트는 별도 입력 폼으로 처음 생성되는 구조가 아니다.  
기본적으로 앨범 저장 시 `album.artists`를 보고 생성/갱신된다.

### `_updateArtistAlbums()`의 의미

- 앨범 추가 시 없던 아티스트를 생성
- 앨범 수정 시 추가된 아티스트에 albumId 연결
- 앨범 수정/삭제 시 빠진 아티스트에서 albumId 제거
- albumIds가 비면 아티스트 엔트리 삭제

### 결과

- 아티스트는 "앨범에 연결된 이름들의 정규화된 인덱스"다.
- alias/groups/image는 여기에 덧붙는 보조 메타데이터다.

## 6. 검색용 파생 데이터

저장소는 단순 CRUD뿐 아니라 검색 보조 데이터도 제공한다.

### 옵션 목록 생성

- `getAllFormats()`
- `getAllGenres()`
- `getAllStyles()`
- `getAllLabels()`

### 아티스트 추천

- `getSmartArtistSuggestions(query)`
- startsWith 우선
- contains 차순위
- 최대 10개 제한

### alias 검색

- `getArtistNamesMatching(query)`
- 아티스트 이름과 alias 둘 다 탐색

## 7. 백업 구조

### 백업 생성

`AlbumRepository.exportBackup()`

절차:

1. 임시 폴더 생성
2. `albums.json` 작성
3. `artists.json` 작성
4. 앨범 이미지 복사
5. zip 생성
6. 임시 폴더 정리

### zip 내부 예상 구조

```text
backup_xxx/
  albums.json
  artists.json
  images/
    <album image files>
```

### 백업 공유/저장

- `shareBackup()`
- `saveBackupToDevice()`

### 백업 복원

`AlbumRepository.importBackup()`

절차:

1. 사용자가 zip 선택
2. 임시 폴더에 압축 해제
3. `albums.json` 존재 확인
4. 기존 `albumBox`, `artistBox` 비우기
5. 기존 `album_images` 폴더 재생성
6. 앨범/이미지/아티스트 복원
7. 임시 폴더 정리

### 구조적 위험

- 복원 중간 실패 시 롤백이 없다.
- 기존 데이터를 먼저 비우므로 부분 복원 위험이 있다.
- 아티스트 이미지 보존 범위가 부족하다.

## 8. 외부 API 연동

## 8.1 Discogs

파일:

- `lib/services/discogs_service.dart`

주요 기능:

- 토큰 기반 인증 요청
- 제목/아티스트 검색
- 바코드 검색
- release 상세 조회
- 이미지 다운로드
- `Album` 변환

특징:

- `SharedPreferences`에서 `discogs_api_token` 읽음
- `User-Agent` 헤더 사용
- 트랙 `type_ == heading`이면 헤더 트랙으로 변환

맵핑되는 데이터:

- 제목
- 아티스트
- notes -> description
- labels
- formats
- release date
- genres/styles
- tracks
- limited edition 여부

## 8.2 Spotify

파일:

- `lib/services/spotify_service.dart`

주요 기능:

- client credentials 인증
- 앨범 검색
- 이미지 다운로드

사용처:

- 커버 검색
- 외부 링크 검색

제한:

- 이 서비스는 앨범 전체를 `Album`으로 만들지 않고, 연결/보조 검색 결과 제공에 가깝다.

현재 문제:

- ViewModel의 설정 판별이 실제 자격 증명을 확인하지 않는다.

## 8.3 VocaDB

파일:

- `lib/services/vocadb_service.dart`

주요 기능:

- 앨범 검색
- 상세 조회
- 이미지 다운로드
- `Album` 변환

특징:

- Producer/Circle 카테고리 위주 아티스트 파싱
- Label 카테고리와 identifiers를 labels에 합침
- tags를 genres/styles/formats로 분배
- 여러 disc가 있으면 헤더 트랙 자동 삽입

## 8.4 MusicBrainz

파일:

- `lib/services/musicbrainz_service.dart`

주요 기능:

- release 검색
- release 상세 조회
- Cover Art Archive에서 커버 다운로드
- `Album` 변환

특징:

- `503` 응답에 대한 재시도 로직 존재
- 상세 조회와 커버 다운로드를 병렬로 시작
- 이미지가 늦으면 타임아웃 후 이미지 없이 진행
- 검색 결과에는 썸네일을 제공하지 않는다

## 8.5 UpdateService

파일:

- `lib/services/update_service.dart`

주요 기능:

- 현재 앱 버전 확인
- GitHub 최신 release 확인
- APK 다운로드
- 설치 파일 열기
- 설치된 버전 기록

해석:

- 앱 배포 경로가 Android APK 설치 흐름을 중심으로 설계돼 있다.
- iOS/macOS/web 배포 관리 서비스는 아니다.

## 9. 데이터 변환 관점에서 본 핵심 설계

이 앱의 외부 연동은 "원격 데이터를 그대로 보여주는 앱"이 아니라  
"외부 데이터를 내부 `Album` 모델로 흡수해 로컬 데이터베이스에 병합하는 앱"이다.

즉, 최종 권위 데이터는 외부 API가 아니라 로컬 저장소다.

### 장점

- 오프라인 중심 사용 가능
- 여러 메타데이터 출처를 하나의 공통 모델로 통합 가능
- 사용자가 수동 편집으로 최종 상태를 결정 가능

### 비용

- 서비스별 파싱 차이를 모두 앱이 흡수해야 한다.
- 이미지/파일/메타데이터 동기화 책임이 앱 내부로 들어온다.

## 10. 연동 실패 시 사용자 경험

현재 코드 기준으로 실패는 주로 다음 형태로 노출된다.

- 검색 결과 없음
- Snackbar 에러 메시지
- 설정 화면 연결 테스트 실패
- 이미지 없이 계속 진행

다만 일부 흐름은 "설정 부족"과 "검색 실패"를 분리하지 못한다.  
대표 예가 Spotify 설정 판별 경로다.

## 11. 데이터/연동 관점에서 추천되는 정리 방향

### 우선순위 높음

- Spotify 설정 판별 실제화
- 백업/복원 트랜잭션성 강화
- 아티스트 이미지 백업 범위 정의

### 중기

- 저장소를 파일 저장/메타데이터 저장/백업 서비스로 분리
- 외부 API 결과를 공통 DTO로 한 번 더 정규화

### 장기

- 서비스별 캐시 정책
- 병합 규칙 명문화
- 실패 유형별 사용자 메시지 분리
