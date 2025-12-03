import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/album_repository.dart';
import '../services/theme_manager.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiTokenController = TextEditingController();
  final AlbumRepository _repository = AlbumRepository();
  bool _isLoading = false;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadApiToken();
    _isDarkMode = themeNotifier.value == ThemeMode.dark;
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _apiTokenController.dispose();
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

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

  Future<void> _loadApiToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('discogs_api_token') ?? '';
    setState(() {
      _apiTokenController.text = token;
    });
  }

  Future<void> _saveApiToken() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('discogs_api_token', _apiTokenController.text);
      if (mounted) {
        SuccessSnackBar.show(context, 'API 토큰이 저장되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        ErrorSnackBar.show(context, '저장 실패: $e');
      }
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
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
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
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
                    TextField(
                      controller: _apiTokenController,
                      decoration: InputDecoration(
                        labelText: 'API Token',
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
                      child: FilledButton.icon(
                        onPressed: _saveApiToken,
                        icon: const Icon(Icons.save),
                        label: const Text('저장'),
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
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
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
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '나만의 앨범 컬렉션을 관리하세요.',
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                      ),
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
