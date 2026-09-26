import 'dart:convert';
import 'dart:io';

/// Boogle SDK 연동 hook.
///
/// `BOOGLE_METRICS_PATH` / `BOOGLE_ARTIFACTS_PATH` / `BOOGLE_ARTIFACTS_DIR`
/// 환경 변수가 있을 때만 동작한다. 일반 `flutter test` 실행에서는 모든 호출이
/// 조용히 무시되므로 테스트 코드를 분기하지 않아도 된다.
///
/// `flutter test`는 테스트 파일을 여러 isolate로 병렬 실행하므로, 제출 파일은
/// lock 파일(`boogle-hook.lock`)로 직렬화한 뒤 읽기-병합-쓰기한다.
class BoogleHook {
  BoogleHook._();

  static String? get _metricsPath =>
      Platform.environment['BOOGLE_METRICS_PATH'];
  static String? get _artifactsPath =>
      Platform.environment['BOOGLE_ARTIFACTS_PATH'];
  static String? get _artifactsDir =>
      Platform.environment['BOOGLE_ARTIFACTS_DIR'];

  /// Boogle 경유 실행 여부.
  static bool get enabled => _metricsPath != null;

  // SDK protocol.ts 스키마와 동일한 제약
  static final _metricNamePattern = RegExp(
    r'^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$',
  );
  static final _fileNamePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');
  static const _artifactKinds = {'capture', 'video', 'output', 'trace'};
  static const _aggregations = {
    'single', 'mean', 'median', 'min', 'max', 'p95', 'sum',
  };

  // metric()은 metricsPath, artifact()는 artifactsPath/Dir가 이미 검증된 뒤 호출되므로
  // 셋 중 하나가 반드시 존재한다. 부분 설정(artifact만 설정된 실행)에서도 크래시하지 않는다.
  static String _lockPath() {
    final anchor = _metricsPath ?? _artifactsPath ?? _artifactsDir;
    assert(anchor != null, 'BOOGLE_* 환경 변수 없이 lock 경로를 요청했습니다');
    return '${File(anchor!).parent.path}${Platform.pathSeparator}boogle-hook.lock';
  }

  static Future<T> _withLock<T>(Future<T> Function() body) async {
    final lockFile = File(_lockPath());
    await lockFile.parent.create(recursive: true);
    final raf = await lockFile.open(mode: FileMode.write);
    try {
      await raf.lock(FileLock.blockingExclusive);
      return await body();
    } finally {
      await raf.unlock();
      await raf.close();
    }
  }

  /// metric 제출. `name`은 `category/name` 형식이며 실행 내에서 유일해야 한다.
  /// 같은 이름이 이미 있으면 마지막 값으로 덮어쓴다.
  static Future<void> metric(
    String name, {
    required num value,
    required String unit,
    String direction = 'higher',
    num thresholdValue = 0,
    String aggregation = 'single',
    String definitionVersion = '1',
  }) async {
    if (!enabled) return;
    assert(_metricNamePattern.hasMatch(name));
    assert(_aggregations.contains(aggregation));
    assert(direction == 'lower' || direction == 'higher');
    assert(value.isFinite && thresholdValue.isFinite);

    final record = <String, dynamic>{
      'name': name,
      'value': value,
      'unit': unit,
      'definitionVersion': definitionVersion,
      'aggregation': aggregation,
      'direction': direction,
      'threshold': {'kind': 'absolute', 'value': thresholdValue},
    };

    await _withLock(() async {
      final file = File(_metricsPath!);
      var records = <dynamic>[];
      if (await file.exists()) {
        records = List<dynamic>.from(
          jsonDecode(await file.readAsString()) as List<dynamic>,
        );
      }
      records.removeWhere(
        (entry) => entry is Map && entry['name'] == name,
      );
      records.add(record);
      await file.writeAsString(jsonEncode(records), flush: true);
    });
  }

  /// artifact 제출. 파일을 제출 폴더로 복사하고 manifest에 등록한다.
  /// 같은 `fileName`이 있으면 파일과 manifest 항목을 덮어쓴다.
  static Future<void> artifact(
    String sourcePath, {
    required String fileName,
    required String kind,
  }) async {
    final artifactsPath = _artifactsPath;
    final artifactsDir = _artifactsDir;
    if (artifactsPath == null || artifactsDir == null) return;
    assert(_fileNamePattern.hasMatch(fileName));
    assert(_artifactKinds.contains(kind));

    await _withLock(() async {
      await Directory(artifactsDir).create(recursive: true);
      await File(sourcePath).copy(
        '$artifactsDir${Platform.pathSeparator}$fileName',
      );

      var artifacts = <dynamic>[];
      final manifestFile = File(artifactsPath);
      if (await manifestFile.exists()) {
        final manifest =
            jsonDecode(await manifestFile.readAsString())
                as Map<String, dynamic>;
        artifacts = List<dynamic>.from(
          manifest['artifacts'] as List<dynamic>,
        );
      }
      artifacts.removeWhere(
        (entry) => entry is Map && entry['fileName'] == fileName,
      );
      artifacts.add({'fileName': fileName, 'kind': kind});
      await manifestFile.writeAsString(
        jsonEncode({'artifacts': artifacts}),
        flush: true,
      );
    });
  }
}
