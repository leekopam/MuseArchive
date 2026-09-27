import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../services/haptic_service.dart';
import '../services/i_album_repository.dart';
import '../utils/file_utils.dart';

// region 텍스트 입력 위젯
class ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool isBold;
  final Color primaryColor;
  final Color bgColor;
  final Color textColor;

  const ModernTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.isBold = false,
    required this.primaryColor,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: TextStyle(
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        color: textColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withAlpha(179)),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: textColor.withAlpha(179))
            : null,
        filled: true,
        fillColor: bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withAlpha(77)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }
}

class DateTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final nonZeroIndex = i + 1;
      if (nonZeroIndex <= 4) {
        if (nonZeroIndex == 4 && nonZeroIndex != text.length) {
          buffer.write('.');
        }
      } else {
        if (nonZeroIndex == 6 && nonZeroIndex != text.length) {
          buffer.write('.');
        }
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
//endregion

// endregion

// region UI 상태 위젯
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        AnimatedOpacity(
          opacity: isLoading ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? Container(
                  color: Colors.black54,
                  child: const Center(child: CircularProgressIndicator()),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: hintColor),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: hintColor),
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
//endregion

// endregion

// region 스낵바 헬퍼
class ErrorSnackBar {
  static void show(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    HapticService.error();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          action: (actionLabel != null && onAction != null)
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: Theme.of(context).colorScheme.onError,
                  onPressed: onAction,
                )
              : null,
        ),
      );
  }
}

class SuccessSnackBar {
  static void show(BuildContext context, String message) {
    HapticService.success();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class InfoSnackBar {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
//endregion

// endregion

// region 앨범 포맷 배지
/// 카드 좌상단 포맷 배지 열. 알려진 포맷은 고유 색, 나머지는 회색으로 표시한다.
class AlbumFormatBadges extends StatelessWidget {
  final List<String> formats;
  final bool isCompact;

  const AlbumFormatBadges({
    super.key,
    required this.formats,
    this.isCompact = false,
  });

  static const _colors = {
    'LP': Color(0xFFD4AF37), // 메탈릭 골드
    'CD': Color(0xFF546E7A), // 실버 톤은 흰 글자 대비 확보를 위해 한 단계 어둡게
    'DVD': Color(0xFF8E24AA), // 퍼플
    'Blu-ray': Color(0xFF2962FF), // 비비드 블루
  };
  static const _priority = ['LP', 'CD', 'DVD', 'Blu-ray'];
  static const _aliases = {
    'LP': ['lp', 'vinyl'],
    'CD': ['cd'],
    'DVD': ['dvd'],
    'Blu-ray': ['blu-ray', 'bluray'],
  };
  static const _unknownColor = Color(0xFF616161);

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];
    final matched = <String>{};

    for (final format in _priority) {
      final hit = formats.any((f) {
        final lower = f.toLowerCase();
        return _aliases[format]!.any((a) => lower.contains(a));
      });
      if (hit) {
        badges.add(_Badge(format, _colors[format]!, isCompact));
        for (final f in formats) {
          final lower = f.toLowerCase();
          if (_aliases[format]!.any((a) => lower.contains(a))) {
            matched.add(lower);
          }
        }
      }
    }

    // 알려진 포맷과 매칭되지 않은 값도 원문 그대로 배지로 노출한다
    for (final f in formats) {
      if (!matched.contains(f.toLowerCase()) && f.trim().isNotEmpty) {
        badges.add(_Badge(f.trim(), _unknownColor, isCompact));
      }
    }

    if (badges.isEmpty) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: badges,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isCompact;

  const _Badge(this.label, this.color, this.isCompact);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 6,
        vertical: isCompact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: isCompact ? 2 : 3,
          ),
        ],
      ),
      // 미지 포맷 원문이 길어도 카드 밖으로 넘치지 않게 너비를 제한한다
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isCompact ? 80 : 110),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            // 밝은 배지(골드 LP)에는 어두운 글자로 대비를 확보한다
            color: color.computeLuminance() > 0.4
                ? Colors.black87
                : Colors.white,
            fontSize: isCompact ? 8 : 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
//endregion

// region 다이얼로그 헬퍼
class ConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '확인',
    String cancelText = '취소',
    bool isDestructive = false,
  }) async {
    HapticService.warning();
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            // 삭제·복원 같은 파괴적 행동은 에러 색으로 구분한다
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// endregion

// region 앨범 삭제 실행취소
/// 앨범을 삭제하고 스낵바로 "실행 취소"를 제공한다.
/// 삭제 레코드는 즉시 지우되 커버 파일은 스낵바가 닫힐 때까지 보존해,
/// 실행 취소 시 add()로 완전 복원한다.
/// [messenger]는 호출 화면이 pop되어도 유효한 루트 메신저여야 하므로
/// 반드시 삭제 전에 `ScaffoldMessenger.of(context)`로 미리 얻는다.
Future<void> deleteAlbumWithUndo(
  IAlbumRepository repository,
  Album album,
  ScaffoldMessengerState messenger,
) async {
  // 삭제로 아티스트 레코드가 사라질 수 있어 복원용 스냅샷을 먼저 둔다
  final artists = album.artists
      .map(repository.getArtistByName)
      .whereType<Artist>()
      .toList();

  // 수동 정렬 순서를 되돌릴 수 있게 삭제 전 위치를 기억한다
  final before = await repository.getAll();
  final originalIndex = before.indexWhere((a) => a.id == album.id);

  await repository.delete(album.id, preserveFiles: true);

  messenger
      .showSnackBar(
        SnackBar(
          content: const Text('앨범이 삭제되었습니다.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: '실행 취소', onPressed: () {}),
        ),
      )
      .closed
      .then((reason) async {
        try {
          if (reason == SnackBarClosedReason.action) {
            await _restoreDeletedAlbum(
              repository,
              album,
              artists,
              originalIndex,
            );
          } else {
            await _purgePreservedFiles(album);
          }
        } catch (e) {
          // 복원/정리 실패를 조용히 삼키지 않고 로그와 사용자 안내를 남긴다
          debugPrint('삭제 후처리 실패 (reason=$reason): $e');
          if (reason == SnackBarClosedReason.action) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('앨범 복원에 실패했습니다. 앨범 목록을 확인해주세요.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      });
}

Future<void> _restoreDeletedAlbum(
  IAlbumRepository repository,
  Album album,
  List<Artist> artists,
  int originalIndex,
) async {
  // 보존된 커버 파일을 add()가 새 경로로 복사한다
  final preservedCoverPath = album.imagePath;
  await repository.add(album);

  final all = await repository.getAll();
  final currentIndex = all.indexWhere((a) => a.id == album.id);
  if (currentIndex < 0) {
    // add()가 조용히 실패한 경우를 복원 실패로 명시한다
    throw StateError('복원된 앨범 레코드를 찾을 수 없습니다: ${album.id}');
  }

  if (preservedCoverPath != null && preservedCoverPath.isNotEmpty) {
    // add()가 커버를 새 경로로 복사했을 때만 보존 원본을 지운다.
    // 복사가 실패해 원본 경로가 그대로 저장됐다면 그 파일이 라이브 커버다.
    if (all[currentIndex].imagePath != preservedCoverPath) {
      try {
        final preserved = File(preservedCoverPath);
        if (await preserved.exists()) await preserved.delete();
        invalidateFileExists(preservedCoverPath);
      } catch (e) {
        // 정리 실패는 고아 파일로만 남고 복원 결과 자체에는 영향이 없다
        debugPrint('보존 커버 정리 실패: $e');
      }
    }
  }

  // add()는 맨 끝에 붙으므로 원래 위치로 다시 이동한다
  if (originalIndex >= 0 && currentIndex != originalIndex) {
    await repository.reorder(
      currentIndex,
      originalIndex.clamp(0, all.length - 1),
    );
  }

  // 앨범의 마지막 연결이었다면 아티스트 레코드·이미지·별명이 함께 사라졌으므로 재적용
  for (final artist in artists) {
    final current = repository.getArtistByName(artist.name);
    if (current == null) continue;
    if (current.aliases.length != artist.aliases.length ||
        current.groups.length != artist.groups.length) {
      await repository.updateArtistMetadata(
        artist.name,
        artist.aliases,
        artist.groups,
      );
    }
    final savedImagePath = artist.imagePath;
    if (current.imagePath == null &&
        savedImagePath != null &&
        savedImagePath.isNotEmpty) {
      // 삭제 시 아티스트 파일은 고아로 남는다 — 있으면 새 경로로 복사 후 정리
      if (fileExistsSync(savedImagePath)) {
        await repository.updateArtistImage(artist.name, savedImagePath);
        try {
          final orphan = File(savedImagePath);
          if (await orphan.exists()) await orphan.delete();
          invalidateFileExists(savedImagePath);
        } catch (e) {
          // 고아 파일 정리 실패는 저장소 정합성에 영향이 없다
          debugPrint('아티스트 고아 이미지 정리 실패: $e');
        }
      }
    }
  }
}

/// 실행 취소 없이 스낵바가 닫히면 보존한 커버 파일을 확정 삭제한다.
Future<void> _purgePreservedFiles(Album album) async {
  final path = album.imagePath;
  if (path == null || path.isEmpty) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (e) {
    // 확정 삭제의 파일 정리 실패는 고아 파일로만 남는다
    debugPrint('커버 파일 확정 삭제 실패: $e');
  } finally {
    invalidateFileExists(path);
  }
}

// endregion
