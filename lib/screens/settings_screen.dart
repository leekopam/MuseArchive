import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/album_repository.dart';
import '../services/discogs_service.dart';
import '../services/spotify_service.dart';
import '../services/theme_manager.dart';
import '../services/update_service.dart';
import '../widgets/common_widgets.dart';

// region 설정 화면 메인
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiTokenController = TextEditingController();
  final TextEditingController _spotifyClientIdController =
      TextEditingController();
  final TextEditingController _spotifyClientSecretController =
      TextEditingController();

  final AlbumRepository _repository = AlbumRepository();
  final UpdateService _updateService = UpdateService();
  bool _isLoading = false;
  bool _isDarkMode = false;
  String _currentVersion = '1.0.0';

  // region 라이프사이클
  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _isDarkMode = themeNotifier.value == ThemeMode.dark;
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _apiTokenController.dispose();
    _spotifyClientIdController.dispose();
    _spotifyClientSecretController.dispose();
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }
  // endregion

  // region 기능 메서드
  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _isDarkMode = themeNotifier.value == ThemeMode.dark;
      });
    }
  }

  void _toggleDarkMode(bool value) {
    saveTheme(value);
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final discogsToken = prefs.getString('discogs_api_token') ?? '';
    final spotifyId = prefs.getString('spotify_client_id') ?? '';
    final spotifySecret = prefs.getString('spotify_client_secret') ?? '';
    final version = await _updateService.getCurrentVersion();

    setState(() {
      _apiTokenController.text = discogsToken;
      _spotifyClientIdController.text = spotifyId;
      _spotifyClientSecretController.text = spotifySecret;
      _currentVersion = version;
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isLoading = true);
    try {
      final updateInfo = await _updateService.checkForUpdate();
      if (!mounted) return;

      if (updateInfo != null) {
        _showUpdateDialog(updateInfo);
      } else {
        SuccessSnackBar.show(context, '현재 최신 버전을 사용 중입니다.');
      }
    } catch (e) {
      if (mounted) ErrorSnackBar.show(context, '업데이트 확인 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _UpdateDialog(info: info, updateService: _updateService);
      },
    );
  }

  Future<void> _saveApiToken() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('discogs_api_token', _apiTokenController.text);
      if (mounted) {
        SuccessSnackBar.show(context, 'Discogs 토큰이 저장되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        ErrorSnackBar.show(context, '저장 실패: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSpotifyCredentials() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'spotify_client_id',
        _spotifyClientIdController.text,
      );
      await prefs.setString(
        'spotify_client_secret',
        _spotifyClientSecretController.text,
      );
      if (mounted) {
        SuccessSnackBar.show(context, 'Spotify 키가 저장되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        ErrorSnackBar.show(context, '저장 실패: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testDiscogsConnection() async {
    setState(() => _isLoading = true);
    try {
      // 테스트 전 현재 입력값으로 설정 업데이트

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('discogs_api_token', _apiTokenController.text);

      final success = await DiscogsService().testConnection();
      if (mounted) {
        if (success) {
          SuccessSnackBar.show(context, 'Discogs 연결 성공!');
        } else {
          ErrorSnackBar.show(context, 'Discogs 연결 실패. 토큰을 확인하세요.');
        }
      }
    } catch (e) {
      if (mounted) ErrorSnackBar.show(context, '테스트 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testSpotifyConnection() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'spotify_client_id',
        _spotifyClientIdController.text,
      );
      await prefs.setString(
        'spotify_client_secret',
        _spotifyClientSecretController.text,
      );

      final success = await SpotifyService().testConnection();
      if (mounted) {
        if (success) {
          SuccessSnackBar.show(context, 'Spotify 연결 성공!');
        } else {
          ErrorSnackBar.show(context, 'Spotify 연결 실패. 키를 확인하세요.');
        }
      }
    } catch (e) {
      if (mounted) ErrorSnackBar.show(context, '테스트 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);
    try {
      final success = await _repository.saveBackupToDevice();
      if (mounted) {
        if (success) {
          SuccessSnackBar.show(context, '백업이 생성되었습니다.');
        } else {
          ErrorSnackBar.show(context, '백업 생성에 실패했습니다.');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorSnackBar.show(context, '백업 생성 중 오류: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirm = await ConfirmDialog.show(
      context,
      title: '백업 복원',
      content: '현재 데이터가 모두 삭제되고 백업 데이터로 복원됩니다. 계속하시겠습니까?',
      confirmText: '복원',
    );

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final success = await _repository.importBackup();
      if (mounted) {
        if (success) {
          SuccessSnackBar.show(context, '백업이 복원되었습니다.');
        } else {
          ErrorSnackBar.show(context, '백업 복원에 실패했습니다.');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorSnackBar.show(context, '백업 복원 중 오류: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  // endregion

  // region 메인 UI
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          '설정',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '앱 설정',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: cardColor,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.brightness_6, color: Colors.purple),
                title: Text('다크 모드', style: TextStyle(color: textColor)),
                trailing: Switch(
                  value: _isDarkMode,
                  onChanged: _toggleDarkMode,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Discogs API',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discogs API 토큰을 입력하여 앨범 정보를 검색할 수 있습니다.',
              style: TextStyle(fontSize: 14, color: subTextColor),
            ),
            const SizedBox(height: 16),
            Card(
              color: cardColor,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _apiTokenController,
                      decoration: InputDecoration(
                        labelText: 'Discogs API Token',
                        hintText: '토큰을 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.help_outline),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('API 토큰 발급'),
                                content: const Text(
                                  '1. discogs.com에 로그인\n'
                                  '2. Settings > Developers\n'
                                  '3. Generate new token\n'
                                  '4. 생성된 토큰 복사',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('확인'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _testDiscogsConnection,
                              child: const Text('연결 확인'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _saveApiToken,
                              icon: const Icon(Icons.save),
                              label: const Text('저장'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Spotify API',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Spotify Client ID와 Secret을 입력하여 고화질 앨범 아트를 검색할 수 있습니다.',
              style: TextStyle(fontSize: 14, color: subTextColor),
            ),
            const SizedBox(height: 16),
            Card(
              color: cardColor,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _spotifyClientIdController,
                      decoration: InputDecoration(
                        labelText: 'Client ID',
                        hintText: 'Client ID 입력',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _spotifyClientSecretController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Client Secret',
                        hintText: 'Client Secret 입력',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _testSpotifyConnection,
                              child: const Text('연결 확인'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _saveSpotifyCredentials,
                              icon: const Icon(Icons.save),
                              label: const Text('저장'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF1DB954,
                                ), // 스포티파이 그린
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '백업 및 복원',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '앨범 데이터를 백업하거나 복원할 수 있습니다.',
              style: TextStyle(fontSize: 14, color: subTextColor),
            ),
            const SizedBox(height: 16),
            Card(
              color: cardColor,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.backup, color: Colors.blue),
                    title: Text('백업 생성', style: TextStyle(color: textColor)),
                    subtitle: Text(
                      '현재 데이터를 백업 파일로 저장합니다.',
                      style: TextStyle(color: subTextColor),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _createBackup,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restore, color: Colors.green),
                    title: Text('백업 복원', style: TextStyle(color: textColor)),
                    subtitle: Text(
                      '백업 파일에서 데이터를 복원합니다.',
                      style: TextStyle(color: subTextColor),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _restoreBackup,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text(
              '앱 정보',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: cardColor,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MuseArchive',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version $_currentVersion',
                      style: TextStyle(fontSize: 14, color: subTextColor),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _checkForUpdates,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('업데이트 확인'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '나만의 앨범 컬렉션을 관리하세요.',
                      style: TextStyle(fontSize: 14, color: subTextColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// endregion

// region 업데이트 다이얼로그
/// 인앱 다운로드 진행률 및 설치를 처리하는 다이얼로그
class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final UpdateService updateService;

  const _UpdateDialog({required this.info, required this.updateService});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _error = null;
    });

    try {
      await widget.updateService.downloadAndInstallApk(
        widget.info.downloadUrl,
        (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _error = '다운로드 실패: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            _isDownloading ? Icons.downloading : Icons.system_update_alt,
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          Text(_isDownloading ? '다운로드 중...' : '새로운 버전 업데이트'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '새로운 버전 v${widget.info.latestVersion}이 준비되었습니다.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (!_isDownloading) ...[
            const SizedBox(height: 12),
            const Text(
              '업데이트 내용:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.info.releaseNotes,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
          if (_isDownloading) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
        if (!_isDownloading)
          FilledButton(
            onPressed: _startDownload,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('지금 업데이트'),
          ),
      ],
    );
  }
}

// endregion
