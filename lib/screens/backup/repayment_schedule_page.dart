import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

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

  Future<void> _shareCSV(BuildContext context) async {
    if (!isPremium) {
      _showPremiumRequiredDialog(context);
      return;
    }

    try {
      // CSVデータ作成（日本語ヘッダー）
      List<List<String>> csvData = [
        ['支払回数', '毎月の支払額', '元金', '利息', '残高', '返済種別']
      ];
      csvData.addAll(schedule);

      String csv = const ListToCsvConverter().convert(csvData);
      
      // ファイル名を生成
      final timestamp = DateTime.now();
      final filename = 'repayment_schedule_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}.csv';
      
      // CSVデータを共有
      final result = await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(csv.codeUnits),
          name: filename,
          mimeType: 'text/csv',
        ),
      ], 
      text: '返済計画表のCSVファイルです。',
      subject: title,
      );

      // 実際に共有された場合のみ成功メッセージを表示
      if (result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.share, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('CSVファイルを共有しました'),
                ),
              ],
            ),
            backgroundColor: Colors.lightBlue.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 3),
          ),
        );
      }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              'CSV共有機能は\nプレミアムプラン限定です',
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
                  Text('• ローン計算結果の保存\n• データ比較機能\n• ボーナス返済計算\n• 早期返済計算\n• CSV共有機能\n• 広告非表示'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            color: Colors.indigo.shade600,
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
            color: Colors.indigo.shade600.withOpacity(0.8),
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
            onPressed: () => _shareCSV(context),
            icon: Icon(Icons.share),
            tooltip: 'CSV共有',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 共有ボタンカード
            _buildStyledCard(
              color: Colors.indigo.shade50,
              child: Column(
                children: [
                  _buildSectionTitle('データ共有', Icons.share),
                  SizedBox(height: 16),
                  Text(
                    'CSVファイルを作成してメールやSNSアプリに共有できます\nExcelなどで詳細な分析が可能です',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.indigo.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _shareCSV(context),
                    icon: Icon(Icons.share),
                    label: Text('CSVファイルを共有'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
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
