import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

/// 업데이트 정보 모델
class UpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;

  UpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

/// GitHub 릴리즈 기반 업데이트 서비스
class UpdateService {
  static const String _owner = 'leekopam';
  static const String _repo = 'MuseArchive';

  /// 현재 앱 버전 조회
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// GitHub 최신 릴리스 확인 후 업데이트 정보 반환
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$_owner/$_repo/releases/latest',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestTag = data['tag_name'] as String;
        final releaseNotes = data['body'] as String? ?? '';

        final latestVersion = latestTag.startsWith('v')
            ? latestTag.substring(1)
            : latestTag;

        final currentVersion = await getCurrentVersion();

        if (_isNewerVersion(currentVersion, latestVersion)) {
          // assets에서 .apk 파일 URL 탐색
          String downloadUrl = data['html_url'];
          final List assets = data['assets'] ?? [];
          final apkAsset = assets.firstWhere(
            (asset) => (asset['name'] as String).endsWith('.apk'),
            orElse: () => null,
          );

          if (apkAsset != null) {
            downloadUrl = apkAsset['browser_download_url'];
          }

          return UpdateInfo(
            latestVersion: latestVersion,
            releaseNotes: releaseNotes,
            downloadUrl: downloadUrl,
          );
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('업데이트 확인 실패: $e');
    }
    return null;
  }

  /// 인앱 APK 다운로드 후 설치 프롬프트 실행 (리다이렉트 자동 처리)
  Future<void> downloadAndInstallApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('다운로드 실패: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/update.apk';
      final file = File(filePath);
      final sink = file.openWrite();

      int received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress(received / contentLength);
        }
      }

      await sink.close();

      // APK 설치 인텐트 실행
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('APK 열기 실패: ${result.message}');
      }
    } finally {
      client.close();
    }
  }

  /// 세맨틱 버전 비교 (latest가 더 높으면 true)
  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (var i = 0; i < currentParts.length && i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (e) {
      return current != latest;
    }
  }
}
