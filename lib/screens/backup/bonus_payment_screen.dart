import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import 'repayment_schedule_page.dart';

class BonusPaymentScreen extends StatefulWidget {
  final AppState appState;

  const BonusPaymentScreen({
    Key? key,
    required this.appState,
  }) : super(key: key);

  @override
  _BonusPaymentScreenState createState() => _BonusPaymentScreenState();
}

class _BonusPaymentScreenState extends State<BonusPaymentScreen> {
  final _loanAmountController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _loanTermYearsController = TextEditingController();
  final _loanTermMonthsController = TextEditingController(text: '0');
  final _bonusAmountController = TextEditingController();

  String _repaymentMethod = '元利均等';
  List<int> _bonusMonths = [6, 12];

  double _monthlyPaymentWithoutBonus = 0;
  double _monthlyPaymentWithBonus = 0;
  double _totalInterestWithoutBonus = 0;
  double _totalInterestWithBonus = 0;
  double _totalAmountWithoutBonus = 0;
  double _totalAmountWithBonus = 0;
  int _totalPayments = 0;
  List<List<String>> _scheduleWithBonus = [];

  final formatter = NumberFormat('#,###');
  final _scrollController = ScrollController();
  final _resultKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ボーナス月判定メソッド
  bool _isBonusMonth(int monthNumber) {
    int monthInYear = monthNumber % 12;
    if (monthInYear == 0) monthInYear = 12;
    return _bonusMonths.contains(monthInYear);
  }

  // ボーナス返済を考慮した月々返済額計算
  double _calculateMonthlyPaymentWithBonus(
    double loanAmount,
    double monthlyInterest,
    int totalMonths,
    double bonusAmount,
  ) {
    if (bonusAmount <= 0) {
      return loanAmount *
          monthlyInterest /
          (1 - (1 / pow(1 + monthlyInterest, totalMonths)));
    }

    // ボーナス返済の現在価値を計算
    double bonusPresentValue = 0;
    for (int i = 1; i <= totalMonths; i++) {
      if (_isBonusMonth(i)) {
        bonusPresentValue += bonusAmount / pow(1 + monthlyInterest, i);
      }
    }

    // ボーナス返済を差し引いた実質借入額
    double adjustedLoanAmount = loanAmount - bonusPresentValue;

    // 月々返済額を計算
    return adjustedLoanAmount *
        monthlyInterest /
        (1 - (1 / pow(1 + monthlyInterest, totalMonths)));
  }

  // ボーナス返済効果を計算
  void _calculateBonusEffect() {
    // キーボードを閉じる
    FocusScope.of(context).unfocus();

    double loanAmount =
        double.tryParse(_loanAmountController.text.replaceAll(',', '')) ?? 0;
    double annualInterest = double.tryParse(_interestRateController.text) ?? 0;
    int years = int.tryParse(_loanTermYearsController.text) ?? 0;
    int months = int.tryParse(_loanTermMonthsController.text) ?? 0;
    int totalMonths = years * 12 + months;
    double monthlyInterest = annualInterest / 100 / 12;
    double bonusAmount =
        double.tryParse(_bonusAmountController.text.replaceAll(',', '')) ?? 0;

    if (loanAmount <= 0 || totalMonths <= 0) {
      _showErrorDialog('入力値を確認してください');
      return;
    }

    // ボーナス返済なしの計算
    double monthlyPaymentWithoutBonus = loanAmount *
        monthlyInterest /
        (1 - (1 / pow(1 + monthlyInterest, totalMonths)));
    double totalInterestWithoutBonus =
        (monthlyPaymentWithoutBonus * totalMonths) - loanAmount;

    // ボーナス返済ありの計算
    double monthlyPaymentWithBonus = _calculateMonthlyPaymentWithBonus(
        loanAmount, monthlyInterest, totalMonths, bonusAmount);

    // 詳細スケジュール計算（ボーナス返済あり）
    List<List<String>> schedule = [];
    double balance = loanAmount;
    double totalInterestWithBonus = 0;

    for (int i = 1; balance > 0 && i <= totalMonths; i++) {
      double interest = balance * monthlyInterest;
      double principal = monthlyPaymentWithBonus - interest;
      double currentPayment = monthlyPaymentWithBonus;

      // ボーナス月の判定と処理
      bool isBonusMonth = _isBonusMonth(i);
      if (isBonusMonth) {
        currentPayment += bonusAmount;
        principal += bonusAmount;
      }

      balance -= principal;
      balance = balance < 0 ? 0 : balance;
      totalInterestWithBonus += interest;

      schedule.add([
        '$i',
        formatter.format(currentPayment.round()),
        formatter.format(principal.round()),
        formatter.format(interest.round()),
        formatter.format(balance.round()),
        isBonusMonth ? 'ボーナス月' : '',
      ]);
    }

    setState(() {
      _monthlyPaymentWithoutBonus = monthlyPaymentWithoutBonus;
      _monthlyPaymentWithBonus = monthlyPaymentWithBonus;
      _totalInterestWithoutBonus = totalInterestWithoutBonus;
      _totalInterestWithBonus = totalInterestWithBonus;
      _totalAmountWithoutBonus = loanAmount + totalInterestWithoutBonus;
      _totalAmountWithBonus = loanAmount + totalInterestWithBonus;
      _totalPayments = totalMonths;
      _scheduleWithBonus = schedule;
    });

    // 計算結果が表示される部分まで自動スクロール
    if (_resultKey.currentContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _resultKey.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('エラー'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
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

  Widget _buildStyledCard({Key? key, required Widget child, Color? color}) {
    return Card(
      key: key,
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

  Widget _buildComparisonCard(
    String title,
    double amount,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '${formatter.format(amount.round())} $unit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ボーナス返済計算'),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 入力フォームセクション
            _buildStyledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('ローン情報入力', Icons.edit_note),
                  SizedBox(height: 20),
                  TextField(
                    controller: _loanAmountController,
                    decoration: InputDecoration(
                      labelText: 'ローン金額(円)',
                      prefixIcon: Icon(Icons.monetization_on_rounded,
                          color: Colors.indigo.shade600),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      String cleaned = value.replaceAll(',', '');
                      double? parsed = double.tryParse(cleaned);
                      if (parsed != null) {
                        _loanAmountController.value = TextEditingValue(
                          text: formatter.format(parsed.round()),
                          selection: TextSelection.collapsed(
                            offset: formatter.format(parsed.round()).length,
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _interestRateController,
                    decoration: InputDecoration(
                      labelText: '金利(年利 %)',
                      prefixIcon: Icon(Icons.percent_rounded,
                          color: Colors.indigo.shade600),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _loanTermYearsController,
                    decoration: InputDecoration(
                      labelText: 'ローン期間(年)',
                      prefixIcon: Icon(Icons.calendar_today_rounded,
                          color: Colors.indigo.shade600),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _loanTermMonthsController,
                    decoration: InputDecoration(
                      labelText: 'ローン期間(月)',
                      prefixIcon: Icon(Icons.calendar_month_rounded,
                          color: Colors.indigo.shade600),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _bonusAmountController,
                    decoration: InputDecoration(
                      labelText: 'ボーナス返済額(円)',
                      prefixIcon: Icon(Icons.card_giftcard_rounded,
                          color: Colors.indigo.shade600),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      String cleaned = value.replaceAll(',', '');
                      double? parsed = double.tryParse(cleaned);
                      if (parsed != null) {
                        _bonusAmountController.value = TextEditingValue(
                          text: formatter.format(parsed.round()),
                          selection: TextSelection.collapsed(
                            offset: formatter.format(parsed.round()).length,
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.indigo.shade700, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'ボーナス返済について',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• 毎年6月と12月にボーナス返済を行います\n• ボーナス返済分は全額元金返済に充当されます\n• 月々の返済額は自動的に調整されます',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 計算ボタン
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _calculateBonusEffect,
                  icon: Icon(Icons.calculate_rounded, size: 24),
                  label: Text('ボーナス返済効果を計算',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  ),
                ),
              ),
            ),

            // 計算結果表示セクション
            if (_monthlyPaymentWithBonus > 0) ...[
              // 比較結果
              _buildStyledCard(
                key: _resultKey,
                color: Colors.indigo.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('比較結果', Icons.compare),
                    SizedBox(height: 20),

                    // ボーナス返済なし vs あり
                    Row(
                      children: [
                        Expanded(
                          child: _buildComparisonCard(
                            'ボーナス返済なし\n月々支払額',
                            _monthlyPaymentWithoutBonus,
                            '円',
                            Colors.blue.shade600,
                            Icons.payment,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildComparisonCard(
                            'ボーナス返済あり\n月々支払額',
                            _monthlyPaymentWithBonus,
                            '円',
                            Colors.indigo.shade600,
                            Icons.card_giftcard,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildComparisonCard(
                            'ボーナス返済なし\n総利息',
                            _totalInterestWithoutBonus,
                            '円',
                            Colors.red.shade600,
                            Icons.trending_up,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildComparisonCard(
                            'ボーナス返済あり\n総利息',
                            _totalInterestWithBonus,
                            '円',
                            Colors.orange.shade600,
                            Icons.trending_up,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // 月々支払額の軽減効果の詳細表示
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.indigo.shade300, width: 2),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.trending_down_rounded,
                              color: Colors.indigo.shade600, size: 36),
                          SizedBox(height: 12),
                          Text(
                            '月々支払額の軽減',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade700,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${formatter.format((_monthlyPaymentWithoutBonus - _monthlyPaymentWithBonus).round())} 円',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'ボーナス返済により、月々の負担を軽減できます',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.indigo.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // アクションボタン
              SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToSchedulePage(
                      _scheduleWithBonus, 'ボーナス返済 返済計画表'),
                  icon: Icon(Icons.table_chart),
                  label: Text('返済計画表を見る'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ), // GestureDetector
    );
  }
}
