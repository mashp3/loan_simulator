import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import 'repayment_schedule_page.dart';

class ComparisonScreen extends StatefulWidget {
  final AppState appState;

  const ComparisonScreen({
    Key? key,
    required this.appState,
  }) : super(key: key);

  @override
  _ComparisonScreenState createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  final formatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await widget.appState.loadSavedData();
    setState(() {});
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
            color: Colors.indigo.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(
      LoanData data, int index, bool isBestInterest, bool isBestAmount) {
    return _buildStyledCard(
      color: (isBestInterest || isBestAmount)
          ? Colors.green.shade50
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bookmark,
                    color: Colors.indigo.shade600,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    data.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                  if (isBestInterest || isBestAmount) ...[
                    SizedBox(width: 8),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'おすすめ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                onSelected: (value) {
                  if (value == 'detail') {
                    _navigateToSchedulePage(data.schedule, data.title);
                  } else if (value == 'delete') {
                    _showDeleteConfirmDialog(index);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'detail',
                    child: Row(
                      children: [
                        Icon(Icons.table_chart, size: 20),
                        SizedBox(width: 8),
                        Text('返済計画表'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('削除', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),

          // 基本情報
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem('ローン金額',
                        '${formatter.format(data.loanAmount.round())} 円'),
                    _buildInfoItem(
                        '金利', '${data.interestRate.toStringAsFixed(2)}%'),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem('期間', '${data.years}年${data.months}ヶ月'),
                    _buildInfoItem('返済方法', data.repaymentMethod),
                  ],
                ),
                // ボーナス返済情報の表示
                if (data.enableBonusPayment && data.bonusAmount > 0) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.card_giftcard,
                            color: Colors.orange.shade700, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'ボーナス返済: ${formatter.format(data.bonusAmount.round())} 円(年2回)',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 20),

          // 重要な結果
          Row(
            children: [
              Expanded(
                child: _buildResultCard(
                  title: '毎月の支払額',
                  value: '${formatter.format(data.monthlyPayment.round())} 円',
                  icon: Icons.calendar_month,
                  color: Colors.blue.shade600,
                  isHighlight: isBestAmount,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildResultCard(
                  title: '総利息',
                  value: '${formatter.format(data.totalInterest.round())} 円',
                  icon: Icons.trending_down,
                  color: isBestInterest ? Colors.green.shade600 : Colors.red.shade600,
                  isHighlight: isBestInterest,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildResultCard(
                  title: '支払総額',
                  value: '${formatter.format(data.totalAmount.round())} 円',
                  icon: Icons.payment,
                  color: Colors.purple.shade600,
                  isHighlight: false,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildResultCard(
                  title: '支払回数',
                  value: '${data.totalPayments} 回',
                  icon: Icons.repeat,
                  color: Colors.orange.shade600,
                  isHighlight: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isHighlight,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlight ? color.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight ? color : Colors.grey.shade300,
          width: isHighlight ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateToSchedulePage(List<List<String>> schedule, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RepaymentSchedulePage(
          schedule: schedule,
          title: title,
          isPremium: widget.appState.isPremium,
        ),
      ),
    );
  }

  void _deletePlan(int index) {
    widget.appState.deleteLoanData(index);
    setState(() {});
  }

  void _showDeleteConfirmDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('プランを削除'),
        content:
            Text('「${widget.appState.savedLoanData[index].title}」を削除しますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              _deletePlan(index);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('プランを削除しました'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('削除'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('全プランを削除'),
        content: Text('保存されている全てのプランを削除しますか?\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.appState.clearAllLoanData();
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('全てのプランを削除しました'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('全て削除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int bestInterestIndex = widget.appState.getBestInterestIndex();
    int bestAmountIndex = widget.appState.getBestMonthlyPaymentIndex();

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: widget.appState.savedLoanData.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.compare_arrows_rounded,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'プラン比較',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '保存済みのローンプランを比較できます',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    SizedBox(height: 32),
                    Text(
                      '現在 ${widget.appState.savedLoanData.length}/${widget.appState.isPremium ? 10 : 3} 件保存済み',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    SizedBox(height: 24),
                    Container(
                      padding: EdgeInsets.all(16),
                      margin: EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.indigo.shade600, size: 32),
                          SizedBox(height: 12),
                          Text(
                            'まだプランが保存されていません',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '基本計算タブで計算を実行し、\n「プラン保存」ボタンでプランを保存してください',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.indigo.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ヘッダー
                    _buildStyledCard(
                      color: Colors.indigo.shade50,
                      child: Column(
                        children: [
                          _buildSectionTitle('保存済みプランの比較', Icons.compare),
                          SizedBox(height: 12),
                          Text(
                            '保存された各プランを比較して、最適なローンを見つけましょう',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.indigo.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 保存されたプランの比較表示
                    ...widget.appState.savedLoanData.asMap().entries.map((entry) {
                      int index = entry.key;
                      LoanData data = entry.value;
                      return _buildPlanCard(
                        data,
                        index,
                        index == bestInterestIndex,
                        index == bestAmountIndex,
                      );
                    }).toList(),

                    // 管理ボタン
                    SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _showDeleteAllConfirmDialog,
                        icon: Icon(Icons.delete_sweep),
                        label: Text('全て削除'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          padding:
                              EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}
