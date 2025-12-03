// lib/widgets/common_widgets.dart
import 'package:flutter/material.dart';

/// 共通で使用するウィジェット集
class CommonWidgets {
  /// スタイル付きカードを構築
  static Widget buildStyledCard({
    required Widget child,
    Color? color,
    double? elevation,
    EdgeInsets? margin,
    EdgeInsets? padding,
  }) {
    return Card(
      color: color ?? Colors.white,
      elevation: elevation ?? 12,
      shadowColor: Colors.black.withOpacity(0.08),
      margin: margin ?? EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(24.0),
        child: child,
      ),
    );
  }

  /// セクションタイトルを構築
  static Widget buildSectionTitle(String title, IconData icon, {Color? color}) {
    final sectionColor = color ?? Colors.indigo.shade600;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: sectionColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        SizedBox(width: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: sectionColor.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  /// テーブルヘッダーを構築
  static Widget buildTableHeader(String text, {Color? color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? Colors.lightBlue.shade700,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// テーブルセルを構築
  static Widget buildTableCell(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 情報アイテムを構築（プラン比較用）
  static Widget buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// プレミアム機能ゲートウィジェット
  static Widget buildPremiumFeatureGate({
    required Widget child,
    required bool isPremiumFeature,
    required bool hasAccess,
    required VoidCallback onUpgradePressed,
    String featureName = 'プレミアム機能',
  }) {
    if (!isPremiumFeature || hasAccess) {
      return child;
    }

    return Stack(
      children: [
        // ブラーエフェクト付きの元のウィジェット
        Opacity(opacity: 0.3, child: AbsorbPointer(child: child)),
        // プレミアムアップグレード促進オーバーレイ
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 48, color: Colors.amber.shade600),
                  SizedBox(height: 16),
                  Text(
                    '$featureName',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'この機能を使用するには\nプレミアム版が必要です',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onUpgradePressed,
                    icon: Icon(Icons.star),
                    label: Text('アップグレード'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ローディングインジケータ付きボタン
  static Widget buildLoadingButton({
    required String text,
    required VoidCallback onPressed,
    required bool isLoading,
    IconData? icon,
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsets? padding,
  }) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  foregroundColor ?? Colors.white,
                ),
              ),
            )
          : Icon(icon ?? Icons.check),
      label: Text(isLoading ? '処理中...' : text),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Colors.indigo.shade600,
        foregroundColor: foregroundColor ?? Colors.white,
        padding: padding ?? EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  /// 成功・エラーメッセージ表示
  static void showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: duration,
      ),
    );
  }

  /// 確認ダイアログ
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '確認',
    String cancelText = 'キャンセル',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive
                  ? Colors.red.shade400
                  : Colors.indigo.shade600,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
