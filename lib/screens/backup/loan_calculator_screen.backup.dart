import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import '../services/ad_service.dart';
import '../services/purchase_service.dart';
import 'repayment_schedule_page.dart';

class LoanCalculatorScreen extends StatefulWidget {
  final AppState appState;
  final AdService adService;

  const LoanCalculatorScreen({
    Key? key,
    required this.appState,
    required this.adService,
  }) : super(key: key);

  @override
  _LoanCalculatorScreenState createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _loanAmountController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _loanTermYearsController = TextEditingController();
  final _loanTermMonthsController = TextEditingController(text: '0');
  String _repaymentMethod = '元利均等';

  double _monthlyPayment = 0;
  int _totalPayments = 0;
  double _totalInterest = 0;
  double _totalAmount = 0;
  List<List<String>> _repaymentSchedule = [];

  final formatter = NumberFormat('#,###');
  final _purchaseService = PurchaseService();
  final _scrollController = ScrollController();
  final _resultKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.appState.loadSavedData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ローン計算メソッド（インタースティシャル広告削除）
  void _calculateLoan() async {
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

    double monthlyPayment = 0;
    List<List<String>> schedule = [];
    double balance = loanAmount;
    double totalInterest = 0;

    if (_repaymentMethod == '元利均等') {
      monthlyPayment = loanAmount *
          monthlyInterest /
          (1 - (1 / (pow(1 + monthlyInterest, totalMonths))));

      for (int i = 1; balance > 0 && i <= totalMonths; i++) {
        double interest = balance * monthlyInterest;
        double principal = monthlyPayment - interest;

        balance -= principal;
        balance = balance < 0 ? 0 : balance;
        totalInterest += interest;

        schedule.add([
          '$i',
          formatter.format(monthlyPayment.round()),
          formatter.format(principal.round()),
          formatter.format(interest.round()),
          formatter.format(balance.round()),
          '',
        ]);
      }
    } else {
      // 元金均等の場合
      double principalPayment = loanAmount / totalMonths;
      monthlyPayment = principalPayment + (balance * monthlyInterest);

      for (int i = 1; balance > 0 && i <= totalMonths; i++) {
        double interest = balance * monthlyInterest;
        double payment = principalPayment + interest;

        balance -= principalPayment;
        balance = balance < 0 ? 0 : balance;
        totalInterest += interest;

        schedule.add([
          '$i',
          formatter.format(payment.round()),
          formatter.format(principalPayment.round()),
          formatter.format(interest.round()),
          formatter.format(balance.round()),
          '',
        ]);
      }
    }

    setState(() {
      _monthlyPayment = monthlyPayment;
      _totalPayments = totalMonths;
      _totalInterest = totalInterest;
      _totalAmount = loanAmount + totalInterest;
      _repaymentSchedule = schedule;
    });

    // 計算結果が表示されている部分まで自動スクロール
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

    // インタースティシャル広告の呼び出しを削除
    // 計算完了のみ（広告表示なし）
  }

  // データの保存
  Future<void> _saveData(String title) async {
    if (_monthlyPayment <= 0) return;

    final loanData = LoanData(
      title: title,
      savedDate: DateTime.now(),
      loanAmount:
          double.tryParse(_loanAmountController.text.replaceAll(',', '')) ?? 0,
      interestRate: double.tryParse(_interestRateController.text) ?? 0,
      years: int.tryParse(_loanTermYearsController.text) ?? 0,
      months: int.tryParse(_loanTermMonthsController.text) ?? 0,
      repaymentMethod: _repaymentMethod,
      monthlyPayment: _monthlyPayment,
      totalPayments: _totalPayments,
      totalInterest: _totalInterest,
      totalAmount: _totalAmount,
      schedule: _repaymentSchedule,
      enableBonusPayment: false,
      bonusAmount: 0,
      bonusMonths: [6, 12],
    );

    await widget.appState.saveLoanData(loanData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「$title」として保存しました'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // プレミアムプラン案内ダイアログ（無料ユーザー向け）
  void _showPremiumPromptDialog() {
    // 既に購入済みの場合は処理しない
    if (widget.appState.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('既にプレミアムプランをご利用中です'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
              'ローン計算結果の保存・削除機能は\nプレミアムプラン限定です',
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
                  Text(
                      '• ローン計算結果の保存\n• データ比較機能\n• ボーナス返済計算\n• 早期返済計算\n• 広告非表示'),
                ],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade600, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '一度の購入で永続利用可能',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                bool success = await _purchaseService.purchasePremium();
                if (success) {
                  await widget.appState.savePremiumStatus(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.star, color: Colors.white),
                          SizedBox(width: 8),
                          Text('プレミアムプランへアップグレードしました！'),
                        ],
                      ),
                      backgroundColor: Colors.amber,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  setState(() {});
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('購入に失敗しました。もう一度お試しください。'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: Icon(Icons.shopping_cart),
            label: Text('¥230で購入'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // エラーダイアログ表示
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600, size: 28),
            SizedBox(width: 8),
            Text('入力エラー'),
          ],
        ),
        content: Text(message, style: TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // 保存ダイアログ表示
  void _showSaveDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.save, color: Colors.green.shade600, size: 28),
            SizedBox(width: 8),
            Text('計算結果を保存'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('保存名を入力してください'),
            SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: '保存名',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                _saveData(titleController.text.trim());
              }
            },
            child: Text('保存'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // 返済スケジュール画面への遷移
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

  // スタイル付きカード作成
  Widget _buildStyledCard({
    required Widget child,
    Color? color,
    Key? key,
  }) {
    return Container(
      key: key,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // セクションタイトル作成
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo.shade600, size: 28),
        SizedBox(width: 12),
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

  // テーブルヘッダー作成
  Widget _buildTableHeader(String text) {
    return Container(
      padding: EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.indigo.shade700,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // テーブルセル作成
  Widget _buildTableCell(String text) {
    return Container(
      padding: EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 余白をタップした時にキーボードを閉じる
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.calculate, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text(
                '基本計算',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.indigo.shade600,
          elevation: 0,
          centerTitle: false,
        ),
        body: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              // 広告表示エリア
              if (!widget.appState.isPremium) widget.adService.getBannerAdWidget(),

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 入力フォーム
                  _buildStyledCard(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('ローン情報の入力', Icons.edit),
                        SizedBox(height: 20),
                        TextField(
                          controller: _loanAmountController,
                          decoration: InputDecoration(
                            labelText: '借入金額（元本）',
                            prefixIcon: Icon(Icons.monetization_on_rounded,
                                color: Colors.indigo.shade600),
                            suffixText: '円',
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
                            labelText: '金利（年利 %）',
                            prefixIcon: Icon(Icons.percent_rounded,
                                color: Colors.indigo.shade600),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: _loanTermYearsController,
                          decoration: InputDecoration(
                            labelText: 'ローン期間（年）',
                            prefixIcon: Icon(Icons.calendar_today_rounded,
                                color: Colors.indigo.shade600),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: _loanTermMonthsController,
                          decoration: InputDecoration(
                            labelText: 'ローン期間（月）',
                            prefixIcon: Icon(Icons.calendar_month_rounded,
                                color: Colors.indigo.shade600),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 20),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _repaymentMethod,
                              isExpanded: true,
                              icon: Icon(Icons.arrow_drop_down_rounded,
                                  color: Colors.indigo.shade600),
                              items: ['元利均等', '元金均等']
                                  .map((method) => DropdownMenuItem(
                                        value: method,
                                        child: Row(
                                          children: [
                                            Icon(Icons.payment_rounded,
                                                color: Colors.indigo.shade600,
                                                size: 20),
                                            SizedBox(width: 12),
                                            Text(method,
                                                style: TextStyle(fontSize: 16)),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _repaymentMethod = value!;
                                });
                              },
                            ),
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
                        onPressed: _calculateLoan,
                        icon: Icon(Icons.calculate_rounded, size: 24),
                        label: Text('計算する',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding:
                              EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        ),
                      ),
                    ),
                  ),

                  // 計算結果表示セクション
                  if (_monthlyPayment > 0) ...[
                    _buildStyledCard(
                      key: _resultKey,
                      color: Colors.indigo.shade50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('計算結果', Icons.assessment),
                          SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.indigo.shade200, width: 2),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                            ),
                            child: Table(
                              columnWidths: {
                                0: FlexColumnWidth(1.2),
                                1: FlexColumnWidth(1.0),
                                2: FlexColumnWidth(1.1),
                                3: FlexColumnWidth(1.1),
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade100,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      topRight: Radius.circular(10),
                                    ),
                                  ),
                                  children: [
                                    _buildTableHeader('毎月の支払額'),
                                    _buildTableHeader('支払回数'),
                                    _buildTableHeader('総利息'),
                                    _buildTableHeader('支払総額'),
                                  ],
                                ),
                                TableRow(children: [
                                  _buildTableCell(
                                      '${formatter.format(_monthlyPayment.round())} 円'),
                                  _buildTableCell('$_totalPayments 回'),
                                  _buildTableCell(
                                      '${formatter.format(_totalInterest.round())} 円'),
                                  _buildTableCell(
                                      '${formatter.format(_totalAmount.round())} 円'),
                                ]),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _navigateToSchedulePage(
                                    _repaymentSchedule, '返済計画表'),
                                icon: Icon(Icons.table_chart),
                                label: Text('返済計画表'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo.shade600,
                                ),
                              ),
                              // 無料ユーザーには保存ボタンではなく課金誘導ボタンを表示
                              widget.appState.isPremium
                                  ? ElevatedButton.icon(
                                      onPressed: _showSaveDialog,
                                      icon: Icon(Icons.save),
                                      label: Text('プラン保存'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade400,
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: _showPremiumPromptDialog,
                                      icon: Icon(Icons.star),
                                      label: Text('プレミアムへ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
