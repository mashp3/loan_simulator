// lib/widgets/common_widgets_responsive.dart
import 'package:flutter/material.dart';

/// 共通で使用するレスポンシブウィジェット集
class ResponsiveWidgets {
  // 画面サイズに基づく計算
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 375;
  }
  
  static bool isVerySmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 340;
  }
  
  static double getResponsivePadding(BuildContext context) {
    if (isVerySmallScreen(context)) return 8.0;
    if (isSmallScreen(context)) return 12.0;
    return 16.0;
  }
  
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    if (isVerySmallScreen(context)) return baseSize - 2;
    if (isSmallScreen(context)) return baseSize - 1;
    return baseSize;
  }

  /// レスポンシブ対応のスタイル付きカードを構築
  static Widget buildResponsiveStyledCard({
    required BuildContext context,
    required Widget child,
    Color? color,
    double? elevation,
    EdgeInsets? margin,
    EdgeInsets? padding,
  }) {
    final responsivePadding = getResponsivePadding(context);
    
    return Card(
      color: color ?? Colors.white,
      elevation: elevation ?? (isSmallScreen(context) ? 8 : 12),
      shadowColor: Colors.black.withOpacity(0.08),
      margin: margin ?? EdgeInsets.symmetric(
        vertical: responsivePadding * 0.75, 
        horizontal: responsivePadding * 0.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen(context) ? 12 : 20),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(responsivePadding),
        child: child,
      ),
    );
  }

  /// レスポンシブ対応のセクションタイトルを構築
  static Widget buildResponsiveSectionTitle(
    BuildContext context, 
    String title, 
    IconData icon, 
    {Color? color}
  ) {
    final sectionColor = color ?? Colors.indigo.shade600;
    final fontSize = getResponsiveFontSize(context, 22);
    final iconSize = getResponsiveFontSize(context, 24);
    final padding = getResponsivePadding(context);
    
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(padding * 0.5),
          decoration: BoxDecoration(
            color: sectionColor,
            borderRadius: BorderRadius.circular(isSmallScreen(context) ? 8 : 12),
          ),
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
        SizedBox(width: padding),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: sectionColor.withOpacity(0.8),
            ),
          ),
        ),
      ],
    );
  }

  /// レスポンシブ対応のテキストフィールド
  static Widget buildResponsiveTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    String? hint,
    String? suffix,
    IconData? icon,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    bool enabled = true,
  }) {
    final fontSize = getResponsiveFontSize(context, 16);
    final iconSize = getResponsiveFontSize(context, 20);
    final padding = getResponsivePadding(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: padding * 0.5),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType ?? TextInputType.text,
          enabled: enabled,
          style: TextStyle(fontSize: fontSize),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            prefixIcon: icon != null 
                ? Icon(icon, color: Colors.indigo.shade400, size: iconSize)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallScreen(context) ? 8 : 16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallScreen(context) ? 8 : 16),
              borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
            ),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade100,
            contentPadding: EdgeInsets.symmetric(
              horizontal: padding, 
              vertical: padding,
            ),
            labelStyle: TextStyle(fontSize: fontSize),
            hintStyle: TextStyle(fontSize: fontSize - 1),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// レスポンシブ対応のボタン
  static Widget buildResponsiveButton({
    required BuildContext context,
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    Color? backgroundColor,
    Color? foregroundColor,
    bool isLoading = false,
    bool isFullWidth = true,
  }) {
    final fontSize = getResponsiveFontSize(context, 16);
    final iconSize = getResponsiveFontSize(context, 20);
    final padding = getResponsivePadding(context);
    
    Widget button = ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  foregroundColor ?? Colors.white,
                ),
              ),
            )
          : (icon != null ? Icon(icon, size: iconSize) : SizedBox()),
      label: Text(
        isLoading ? '処理中...' : text,
        style: TextStyle(
          fontSize: fontSize, 
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Colors.indigo.shade600,
        foregroundColor: foregroundColor ?? Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: padding * 1.5, 
          vertical: padding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isSmallScreen(context) ? 8 : 16),
        ),
        elevation: isSmallScreen(context) ? 4 : 8,
      ),
    );
    
    return isFullWidth 
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  /// 小さな画面用の2列レイアウト
  static Widget buildResponsiveRow({
    required BuildContext context,
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.spaceBetween,
    double spacing = 12,
  }) {
    if (isVerySmallScreen(context)) {
      // 非常に小さい画面では縦に並べる
      return Column(
        children: children
            .expand((child) => [child, SizedBox(height: spacing)])
            .toList()
          ..removeLast(),
      );
    }
    
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: children
          .expand((child) => [Expanded(child: child), SizedBox(width: spacing)])
          .toList()
        ..removeLast(),
    );
  }

  /// レスポンシブ対応の情報表示カード
  static Widget buildResponsiveInfoCard({
    required BuildContext context,
    required String title,
    required String value,
    IconData? icon,
    Color? color,
  }) {
    final fontSize = getResponsiveFontSize(context, 14);
    final valueFontSize = getResponsiveFontSize(context, 16);
    final padding = getResponsivePadding(context);
    
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: (color ?? Colors.indigo).withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmallScreen(context) ? 8 : 12),
        border: Border.all(
          color: (color ?? Colors.indigo).withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color ?? Colors.indigo, size: fontSize + 4),
            SizedBox(height: padding * 0.5),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: fontSize - 2,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: padding * 0.25),
          Text(
            value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.indigo,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 成功・エラーメッセージ表示（レスポンシブ対応）
  static void showResponsiveMessage(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final fontSize = getResponsiveFontSize(context, 14);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
              size: fontSize + 4,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: fontSize),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isSmallScreen(context) ? 8 : 10),
        ),
        duration: duration,
        margin: EdgeInsets.all(getResponsivePadding(context)),
      ),
    );
  }

  /// 小さい画面用のスクロール可能なテーブル
  static Widget buildResponsiveTable({
    required BuildContext context,
    required List<String> headers,
    required List<List<String>> rows,
    Color? headerColor,
  }) {
    final fontSize = getResponsiveFontSize(context, 12);
    final headerFontSize = getResponsiveFontSize(context, 13);
    final cellPadding = getResponsivePadding(context) * 0.5;
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: (headerColor ?? Colors.indigo).withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(isSmallScreen(context) ? 8 : 12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: isVerySmallScreen(context) ? 8 : 16,
          headingRowColor: MaterialStateProperty.all(
            (headerColor ?? Colors.indigo).withOpacity(0.1),
          ),
          dataRowHeight: isSmallScreen(context) ? 40 : 48,
          headingRowHeight: isSmallScreen(context) ? 42 : 50,
          columns: headers.map((header) => DataColumn(
            label: Container(
              padding: EdgeInsets.all(cellPadding),
              child: Text(
                header,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: headerFontSize,
                  color: headerColor ?? Colors.indigo.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )).toList(),
          rows: rows.map((row) => DataRow(
            cells: row.map((cell) => DataCell(
              Container(
                padding: EdgeInsets.all(cellPadding),
                child: Text(
                  cell,
                  style: TextStyle(fontSize: fontSize),
                  textAlign: TextAlign.center,
                ),
              ),
            )).toList(),
          )).toList(),
        ),
      ),
    );
  }
}
