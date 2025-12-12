import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import 'repayment_schedule_page.dart';

class EarlyPaymentScreen extends StatefulWidget {
  final AppState appState;

  const EarlyPaymentScreen({
    Key? key,
    required this.appState,
  }) : super(key: key);

  @override
  _EarlyPaymentScreenState createState() => _EarlyPaymentScreenState();
}

class _EarlyPaymentScreenState extends State<EarlyPaymentScreen> {
  final _loanAmountController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _loanTermYearsController = TextEditingController();
  final _loanTermMonthsController = TextEditingController(text: '0');

  String _repaymentMethod = '元利均等';
  List<Map<String, TextEditingController>> _prepayments = [];

  double _monthlyPaymentBefore = 0;
  double _totalInterestBefore = 0;
  double _totalAmountBefore = 0;
  int _totalPaymentsBefore = 0;
  List<List<String>> _repaymentScheduleBefore = [];

  double _monthlyPaymentAfter = 0;
  double _totalInterestAfter = 0;
  double _totalAmountAfter = 0;
  int _totalPaymentsAfter = 0;
  List<List<String>> _repaymentScheduleAfter = [];

  final formatter = NumberFormat('#,###');
  final _scrollController = ScrollController();
  final _resultKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _addPrepaymentField();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addPrepaymentField() {
    setState(() {
      _prepayments.add({
        'month': TextEditingController(),
        'amount': TextEditingController(),
      });
    });
  }

  void _removePrepaymentField(int index) {
    if (_prepayments.length > 1) {
      setState(() {
        _prepayments[index]['month']!.dispose();
        _prepayments[index]['amount']!.dispose();
        _prepayments.removeAt(index);
      });
    }
  }

  // ローン計算（通常・繰上返済両対応）
  void _calculateLoan({bool includePrepayment = false}) {
    // キーボードを閉じる
    FocusScope.of(context).unfocus();

    double loanAmount =
        double.tryParse(_loanAmountController.text.replaceAll(',', '')) ?? 0;
    double annualInterest = double.tryParse(_interestRateController.text) ?? 0;
    int years = int.tryParse(_loanTermYearsController.text) ?? 0;
    int months = int.tryParse(_loanTermMonthsController.text) ?? 0;
    int totalMonths = years * 12 + months;
    double monthlyInterest = annualInterest / 100 / 12;

    if (loanAmount <= 0 || totalMonths <= 0) {
      _showErrorDialog('入力値を確認してください');
      return;
    }

    // 繰上返済情報の準備
    Map<int, double> prepaymentMap = {};
    if (includePrepayment) {
      for (var prepay in _prepayments) {
        int? m = int.tryParse(prepay['month']!.text);
        double? a = double.tryParse(prepay['amount']!.text.replaceAll(',', ''));
        if (m != null && a != null && m > 0 && a > 0) {
          prepaymentMap[m] = (prepaymentMap[m] ?? 0) + a; // 同月複数対応
        }
      }
    }

    // 基本月々返済額計算
    double monthlyPayment = loanAmount *
        monthlyInterest /
        (1 - (1 / (pow(1 + monthlyInterest, totalMonths))));

    List<List<String>> schedule = [];
    double balance = loanAmount;
    double totalInterest = 0;
    int actualMonths = 0;

    for (int i = 1; balance > 0 && i <= totalMonths; i++) {
      double interest = balance * monthlyInterest;
      double principal = monthlyPayment - interest;
      double currentPayment = monthlyPayment;

      // 繰上返済がある月の処理
      bool hasPrepayment = includePrepayment && prepaymentMap.containsKey(i);
      if (hasPrepayment) {
        double prepaymentAmount = prepaymentMap[i]!;
        currentPayment += prepaymentAmount;
        principal += prepaymentAmount;
      }

      // 元金が残高を超える場合の調整
      if (principal > balance) {
        principal = balance;
        currentPayment = principal + interest;
      }

      balance -= principal;
      balance = max(balance, 0);
      totalInterest += interest;
      actualMonths = i;

      schedule.add([
        '$i',
        formatter.format(currentPayment.round()),
        formatter.format(principal.round()),
        formatter.format(interest.round()),
        formatter.format(balance.round()),
        hasPrepayment ? '繰上返済' : '',
      ]);

      if (balance <= 0) break;
    }

    setState(() {
      if (!includePrepayment) {
        _monthlyPaymentBefore = monthlyPayment;
        _totalInterestBefore = totalInterest;
        _totalAmountBefore = loanAmount + totalInterest;
        _totalPaymentsBefore = actualMonths;
        _repaymentScheduleBefore = schedule;
      } else {
        _monthlyPaymentAfter = monthlyPayment;
        _totalInterestAfter = totalInterest;
        _totalAmountAfter = loanAmount + totalInterest;
        _totalPaymentsAfter = actualMonths;
        _repaymentScheduleAfter = schedule;
      }
    });

    // 計算結果が表示されている部分まで自動スクロール（繰上返済計算時のみ）
    if (includePrepayment && _resultKey.currentContext != null) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('早期返済計算'),
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
            // 基本ローン情報入力
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
                ],
              ),
            ),

            // 繰上返済設定
            _buildStyledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('繰上返済を追加', Icons.add_circle_outline),
                  SizedBox(height: 20),
                  ..._prepayments.asMap().entries.map((entry) {
                    int index = entry.key;
                    var prepay = entry.value;
                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.indigo.shade200),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade600,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.payment_rounded,
                                    color: Colors.white, size: 20),
                              ),
                              SizedBox(width: 12),
                              Text(
                                '繰上返済 ${index + 1} 回目',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Spacer(),
                              IconButton(
                                onPressed: () => _removePrepaymentField(index),
                                icon: Icon(Icons.remove_circle_outline,
                                    color: Colors.red),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Column(
                            children: [
                              TextField(
                                controller: prepay['month']!,
                                decoration: InputDecoration(
                                  labelText: '返済月',
                                  hintText: '例: 12',
                                  prefixIcon: Icon(Icons.calendar_month,
                                      color: Colors.indigo.shade600),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: 16),
                              TextField(
                                controller: prepay['amount']!,
                                decoration: InputDecoration(
                                  labelText: '繰上金額(円)',
                                  hintText: '例: 1,000,000',
                                  prefixIcon: Icon(Icons.monetization_on,
                                      color: Colors.indigo.shade600),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  String cleaned = value.replaceAll(',', '');
                                  double? parsed = double.tryParse(cleaned);
                                  if (parsed != null) {
                                    prepay['amount']!.value = TextEditingValue(
                                      text: formatter.format(parsed.round()),
                                      selection: TextSelection.collapsed(
                                        offset: formatter.format(parsed.round()).length,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _addPrepaymentField,
                      icon: Icon(Icons.add),
                      label: Text('繰上返済を追加'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 計算ボタン
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _calculateLoan(includePrepayment: false),
                    icon: Icon(Icons.calculate_rounded),
                    label: Text('通常計算'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _calculateLoan(includePrepayment: true),
                    icon: Icon(Icons.calculate_rounded),
                    label: Text('効果を計算'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            // 繰上返済後の結果
            if (_repaymentScheduleAfter.isNotEmpty) ...[
              _buildStyledCard(
                key: _resultKey,
                color: Colors.indigo.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('繰上返済後の結果', Icons.trending_down_rounded),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('支払回数:',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${_totalPaymentsAfter} 回',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo.shade700)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('総利息:',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${formatter.format(_totalInterestAfter.round())} 円',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo.shade700)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('支払総額:',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${formatter.format(_totalAmountAfter.round())} 円',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo.shade700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToSchedulePage(
                            _repaymentScheduleAfter, '繰上返済後 返済計画表'),
                        icon: Icon(Icons.table_chart_rounded),
                        label: Text('返済計画表を見る'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 効果サマリー（通常計算も実行されている場合のみ表示）
              if (_totalPaymentsBefore > 0) ...[
                _buildStyledCard(
                  color: Colors.green.shade50,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.celebration_rounded,
                                color: Colors.white, size: 24),
                          ),
                          SizedBox(width: 16),
                          Text(
                            '繰上返済効果',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '利息軽減額',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                '${formatter.format((_totalInterestBefore - _totalInterestAfter).round())} 円',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '期間短縮',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              Text(
                                '${_totalPaymentsBefore - _totalPaymentsAfter} ヶ月',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      ), // GestureDetector
    );
  }
}
