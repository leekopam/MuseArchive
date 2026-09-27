import 'dart:io';

final Map<String, bool> _existsCache = <String, bool>{};

/// build() 안에서 경로별 파일 존재 여부를 메모이즈한다.
/// 이미지 경로는 교체 시 타임스탬프가 붙어 새 경로가 되므로 캐시가 안전하다.
bool fileExistsSync(String path) =>
    _existsCache.putIfAbsent(path, () => File(path).existsSync());

/// 파일이 삭제/교체된 경로의 캐시를 무효화한다.
/// 삭제 직후 호출하지 않으면 사라진 파일을 존재하는 것으로 잘못 판단한다.
void invalidateFileExists(String path) => _existsCache.remove(path);

/// 캐시 전체를 비운다. 백업 복원처럼 이미지 디렉터리가 통째로 교체될 때 사용한다.
void clearFileExistsCache() => _existsCache.clear();
