import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

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

class UpdateService {
  static const String _owner = 'leekopam';
  static const String _repo = 'MuseArchive';

  /// 현재 앱 버전을 가져옵니다.
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// GitHub에서 최신 릴리스 정보를 가져옵니다.
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
        final releaseNotes = data['body'] as String;

        // v1.0.0 형태의 태그에서 'v' 제거
        final latestVersion = latestTag.startsWith('v')
            ? latestTag.substring(1)
            : latestTag;

        final currentVersion = await getCurrentVersion();

        if (_isNewerVersion(currentVersion, latestVersion)) {
          // HTML URL 또는 직접 APK 링크를 찾습니다.
          String downloadUrl = data['html_url'];

          // assets 리스트에서 .apk 파일을 찾습니다.
          final List assets = data['assets'];
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
      print('Update check failed: $e');
    }
    return null;
  }

  /// 버전 비교 로직 (단순 세마틱 버전 비교)
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
      // 파싱 실패 시 문자열 단순 비교
      return current != latest;
    }
  }
}
