import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

class RepaymentSchedulePage extends StatelessWidget {
  final List<List<String>> schedule;
  final String title;
  final bool isPremium;

  const RepaymentSchedulePage({
    Key? key,
    required this.schedule,
    required this.title,
    required this.isPremium,
  }) : super(key: key);

  Future<void> _exportCSV(BuildContext context) async {
    if (!isPremium) {
      _showPremiumRequiredDialog(context);
      return;
    }

    try {
      Directory? directory;
      String folderName = 'LoanCalculator';
      
      if (Platform.isAndroid) {
        // Android: 外部ストレージのDownloadsフォルダまたはアプリ専用フォルダを使用
        try {
          directory = Directory('/storage/emulated/0/Download/$folderName');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        } catch (e) {
          // フォールバック: アプリ専用外部ストレージ
          try {
            directory = await getExternalStorageDirectory();
            if (directory != null) {
              directory = Directory('${directory.path}/$folderName');
              if (!await directory.exists()) {
                await directory.create(recursive: true);
              }
            }
          } catch (e2) {
            // 最終フォールバック: アプリDocumentsフォルダ
            directory = await getApplicationDocumentsDirectory();
          }
        }
      } else if (Platform.isIOS) {
        // iOS: アプリのDocumentsフォルダ内に専用フォルダを作成
        final appDirectory = await getApplicationDocumentsDirectory();
        directory = Directory('${appDirectory.path}/$folderName');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        // その他のプラットフォーム: 基本のDocumentsフォルダ
        directory = await getApplicationDocumentsDirectory();
      }
      
      // フォールバック: 基本のDocumentsフォルダ
      directory ??= await getApplicationDocumentsDirectory();
      
      final timestamp = DateTime.now();
      final filename = 'repayment_schedule_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}.csv';
      final path = '${directory.path}/$filename';
      final file = File(path);

      // CSVデータ作成（日本語ヘッダー）
      List<List<String>> csvData = [
        ['支払回数', '毎月の支払額', '元金', '利息', '残高', '返済種別']
      ];
      csvData.addAll(schedule);

      String csv = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('CSVを保存しました'),
                    Text(
                      path,
                      style: TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.lightBlue.shade400,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('エラーが発生しました: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  static void _showPremiumRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.star, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
            Text('プレミアムプラン'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CSVエクスポート機能は\nプレミアムプラン限定です',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade600, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'プレミアム機能',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text('• ローン計算結果の保存\n• データ比較機能\n• ボーナス返済計算\n• 早期返済計算\n• CSVエクスポート\n• 広告非表示'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('閉じる'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // プレミアム購入画面への遷移はここで実装
            },
            icon: Icon(Icons.shopping_cart),
            label: Text('購入する（¥230）'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledCard({required Widget child, Color? color}) {
    return Card(
      color: color ?? Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.08),
      margin: EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.indigo.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.indigo.shade600, size: 20),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _exportCSV(context),
            icon: Icon(Icons.download),
            tooltip: 'CSVエクスポート',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // エクスポートボタンカード
            _buildStyledCard(
              color: Colors.indigo.shade50,
              child: Column(
                children: [
                  _buildSectionTitle('データエクスポート', Icons.download),
                  SizedBox(height: 16),
                  Text(
                    'CSVファイルとして保存し、Excelなどで詳細な分析ができます',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.indigo.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _exportCSV(context),
                    icon: Icon(Icons.download),
                    label: Text('CSVとして保存'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  if (!isPremium) ...[
                    SizedBox(height: 8),
                    Text(
                      '※プレミアムプラン限定機能',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 返済計画表
            _buildStyledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('返済計画表', Icons.table_chart),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.indigo.shade200, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        headingRowColor: MaterialStateProperty.all(
                          Colors.indigo.shade100,
                        ),
                        columns: [
                          DataColumn(
                            label: Text(
                              '回数',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              '支払額',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              '元金',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              '利息',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              '残高',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              '種別',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ),
                        ],
                        rows: schedule.map((row) {
                          return DataRow(
                            cells: row.map((cell) {
                              return DataCell(
                                Text(
                                  cell,
                                  style: TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
