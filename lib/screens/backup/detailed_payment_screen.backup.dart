import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import 'repayment_schedule_page.dart';

class EarlyPayment {
  int month;
  double amount;

  EarlyPayment({required this.month, required this.amount});
}

class DetailedPaymentScreen extends StatefulWidget {
  final AppState appState;

  const DetailedPaymentScreen({
    Key? key,
    required this.appState,
  }) : super(key: key);

  @override
  _DetailedPaymentScreenState createState() => _DetailedPaymentScreenState();
}

class _DetailedPaymentScreenState extends State<DetailedPaymentScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;  // 画面の状態を保持する
  
  // 基本情報
  final _loanAmountController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _loanTermYearsController = TextEditingController();
  final _loanTermMonthsController = TextEditingController(text: '0');
  String _repaymentMethod = '元利均等';

  // ボーナス返済設定
  bool _enableBonusPayment = false;
  final _bonusAmountController = TextEditingController();
  List<int> _bonusMonths = [6, 12];

  // 繰上返済設定
  bool _enableEarlyPayment = false;
  List<Map<String, TextEditingController>> _earlyPayments = [];

  // 計算結果
  double _basicMonthlyPayment = 0;
  int _basicTotalPayments = 0;
  double _basicTotalInterest = 0;
  double _basicTotalAmount = 0;

  double _detailedMonthlyPayment = 0;
  int _detailedTotalPayments = 0;
  double _detailedTotalInterest = 0;
  double _detailedTotalAmount = 0;
  List<List<String>> _detailedSchedule = [];

  final formatter = NumberFormat('#,###');
  final _scrollController = ScrollController();
  final _resultKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _addEarlyPaymentField();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _loanAmountController.dispose();
    _interestRateController.dispose();
    _loanTermYearsController.dispose();
    _loanTermMonthsController.dispose();
    _bonusAmountController.dispose();
    for (var payment in _earlyPayments) {
      payment['month']!.dispose();
      payment['amount']!.dispose();
    }
    super.dispose();
  }

  void _addEarlyPaymentField() {
    setState(() {
      _earlyPayments.add({
        'month': TextEditingController(),
        'amount': TextEditingController(),
      });
    });
  }

  void _removeEarlyPaymentField(int index) {
    if (_earlyPayments.length > 1) {
      setState(() {
        _earlyPayments[index]['month']!.dispose();
        _earlyPayments[index]['amount']!.dispose();
        _earlyPayments.removeAt(index);
      });
    }
  }

  // バリデーションメソッドを追加
  String? _validateInputs() {
    // ローン金額のバリデーション
    String loanAmountText = _loanAmountController.text.replaceAll(',', '').trim();
    if (loanAmountText.isEmpty || double.tryParse(loanAmountText) == null) {
      return '「借入金額」に数字を入力してください';
    }
    double loanAmount = double.parse(loanAmountText);
    if (loanAmount <= 0) {
      return '「借入金額」に0より大きい数字を入力してください';
    }

    // 年利のバリデーション
    String interestRateText = _interestRateController.text.trim();
    if (interestRateText.isEmpty || double.tryParse(interestRateText) == null) {
      return '「年利」に数字を入力してください';
    }
    double interestRate = double.parse(interestRateText);
    if (interestRate < 0) {
      return '「年利」に0以上の数字を入力してください';
    }

    // 年数のバリデーション
    String yearsText = _loanTermYearsController.text.trim();
    if (yearsText.isEmpty || int.tryParse(yearsText) == null) {
      return '「年数」に数字を入力してください';
    }
    int years = int.parse(yearsText);
    if (years < 0) {
      return '「年数」に0以上の数字を入力してください';
    }

    // ヶ月のバリデーション
    String monthsText = _loanTermMonthsController.text.trim();
    if (monthsText.isEmpty || int.tryParse(monthsText) == null) {
      return '「ヶ月」に数字を入力してください';
    }
    int months = int.parse(monthsText);
    if (months < 0 || months >= 12) {
      return '「ヶ月」に0～11の数字を入力してください';
    }

    // 合計期間のチェック
    int totalMonths = years * 12 + months;
    if (totalMonths <= 0) {
      return '借入期間を1ヶ月以上に設定してください';
    }

    // ボーナス返済額のバリデーション（有効な場合のみ）
    if (_enableBonusPayment) {
      String bonusAmountText = _bonusAmountController.text.replaceAll(',', '').trim();
      if (bonusAmountText.isNotEmpty && double.tryParse(bonusAmountText) == null) {
        return '「ボーナス返済額」に数字を入力してください';
      }
    }

    // 繰上返済のバリデーション（有効な場合のみ）
    if (_enableEarlyPayment) {
      for (int i = 0; i < _earlyPayments.length; i++) {
        String monthText = _earlyPayments[i]['month']!.text.trim();
        String amountText = _earlyPayments[i]['amount']!.text.replaceAll(',', '').trim();
        
        if (monthText.isNotEmpty && int.tryParse(monthText) == null) {
          return '繰上返済の「返済月」に数字を入力してください';
        }
        if (amountText.isNotEmpty && double.tryParse(amountText) == null) {
          return '繰上返済の「繰上金額」に数字を入力してください';
        }
      }
    }

    return null; // エラーなし
  }

  // 詳細計算メイン
  void _calculateDetailed() async {
    // キーボードを閉じる
    FocusScope.of(context).unfocus();

    // バリデーションチェック
    String? validationError = _validateInputs();
    if (validationError != null) {
      _showErrorDialog(validationError);
      return;
    }

    double loanAmount =
        double.parse(_loanAmountController.text.replaceAll(',', ''));
    double annualInterest = double.parse(_interestRateController.text);
    int years = int.parse(_loanTermYearsController.text);
    int months = int.parse(_loanTermMonthsController.text);
    int totalMonths = years * 12 + months;
    double monthlyInterest = annualInterest / 100 / 12;

    // 基本計算
    _calculateBasic(loanAmount, monthlyInterest, totalMonths);

    // オプション込み計算
    _calculateWithOptions(loanAmount, monthlyInterest, totalMonths);

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
  }

  void _calculateBasic(double loanAmount, double monthlyInterest, int totalMonths) {
    if (_repaymentMethod == '元利均等') {
      double monthlyPayment = loanAmount *
          monthlyInterest /
          (1 - (1 / pow(1 + monthlyInterest, totalMonths)));
      
      setState(() {
        _basicMonthlyPayment = monthlyPayment;
        _basicTotalPayments = totalMonths;
        _basicTotalInterest = (monthlyPayment * totalMonths) - loanAmount;
        _basicTotalAmount = loanAmount + _basicTotalInterest;
      });
    }
  }

  // ボーナス月判定メソッド
  bool _isBonusMonth(int monthNumber) {
    int monthInYear = monthNumber % 12;
    if (monthInYear == 0) monthInYear = 12;
    return _bonusMonths.contains(monthInYear);
  }

  void _calculateWithOptions(double loanAmount, double monthlyInterest, int totalMonths) {
    // ボーナス返済情報の準備
    double bonusAmount = 0;
    if (_enableBonusPayment) {
      bonusAmount = double.tryParse(_bonusAmountController.text.replaceAll(',', '')) ?? 0;
    }

    // 繰上返済情報の準備
    Map<int, double> earlyPaymentMap = {};
    if (_enableEarlyPayment) {
      for (var payment in _earlyPayments) {
        int? month = int.tryParse(payment['month']!.text);
        double? amount = double.tryParse(payment['amount']!.text.replaceAll(',', ''));
        if (month != null && amount != null && month > 0 && amount > 0) {
          earlyPaymentMap[month] = (earlyPaymentMap[month] ?? 0) + amount;
        }
      }
    }

    // ボーナス返済を考慮した月々返済額の計算
    double monthlyPayment = _basicMonthlyPayment;
    
    if (_enableBonusPayment && bonusAmount > 0) {
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
      monthlyPayment = adjustedLoanAmount *
          monthlyInterest /
          (1 - (1 / pow(1 + monthlyInterest, totalMonths)));
    }

    List<List<String>> schedule = [];
    double balance = loanAmount;
    double totalInterest = 0;
    int actualMonths = 0;

    for (int i = 1; balance > 0 && i <= totalMonths; i++) {
      double interest = balance * monthlyInterest;
      double principal = monthlyPayment - interest;
      double currentPayment = monthlyPayment;
      String specialNote = '';

      // ボーナス返済の処理
      bool isBonusMonth = _enableBonusPayment && _isBonusMonth(i);
      if (isBonusMonth && bonusAmount > 0) {
        currentPayment += bonusAmount;
        principal += bonusAmount;
        specialNote = 'ボーナス';
      }

      // 繰上返済の処理
      bool hasEarlyPayment = _enableEarlyPayment && earlyPaymentMap.containsKey(i);
      if (hasEarlyPayment) {
        double earlyPaymentAmount = earlyPaymentMap[i]!;
        currentPayment += earlyPaymentAmount;
        principal += earlyPaymentAmount;
        specialNote = specialNote.isEmpty ? '繰上返済' : '$specialNote・繰上返済';
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
        specialNote,
      ]);

      if (balance <= 0) break;
    }

    setState(() {
      _detailedMonthlyPayment = monthlyPayment;
      _detailedTotalPayments = actualMonths;
      _detailedTotalInterest = totalInterest;
      _detailedTotalAmount = loanAmount + totalInterest;
      _detailedSchedule = schedule;
    });
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(20),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);  // AutomaticKeepAliveClientMixinで必要
    
    return Scaffold(
      appBar: AppBar(
        title: Text('詳細返済計算'),
        backgroundColor: Colors.indigo.shade600,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基本情報入力
            _buildStyledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('基本情報', Icons.info_outline),
                  SizedBox(height: 16),
                  TextField(
                    controller: _loanAmountController,
                    decoration: InputDecoration(
                      labelText: '借入金額(円)',
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
                  SizedBox(height: 16),
                  TextField(
                    controller: _interestRateController,
                    decoration: InputDecoration(
                      labelText: '年利(%)',
                      prefixIcon: Icon(Icons.percent_rounded,
                          color: Colors.indigo.shade600),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _loanTermYearsController,
                          decoration: InputDecoration(
                            labelText: '年数',
                            prefixIcon: Icon(Icons.calendar_today_rounded,
                                color: Colors.indigo.shade600),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _loanTermMonthsController,
                          decoration: InputDecoration(
                            labelText: 'ヶ月',
                            prefixIcon: Icon(Icons.calendar_month_rounded,
                                color: Colors.indigo.shade600),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ボーナス返済設定
            _buildStyledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('ボーナス返済設定', Icons.card_giftcard_outlined),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('ボーナス返済を利用する'),
                    value: _enableBonusPayment,
                    onChanged: (bool value) {
                      setState(() {
                        _enableBonusPayment = value;
                      });
                    },
                  ),
                  if (_enableBonusPayment) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ボーナス返済は毎年6月と12月に実施されます',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _bonusAmountController,
                      decoration: InputDecoration(
                        labelText: 'ボーナス返済額(円)',
                        hintText: '例: 100,000',
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
                  ],
                ],
              ),
            ),

            // 繰上返済設定
            _buildStyledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('繰上返済設定', Icons.add_circle_outline),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('繰上返済を利用する'),
                    value: _enableEarlyPayment,
                    onChanged: (bool value) {
                      setState(() {
                        _enableEarlyPayment = value;
                      });
                    },
                  ),
                  if (_enableEarlyPayment) ...[
                    SizedBox(height: 16),
                    ..._earlyPayments.asMap().entries.map((entry) {
                      int index = entry.key;
                      var payment = entry.value;
                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.indigo.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: payment['month']!,
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
                              controller: payment['amount']!,
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
                                  payment['amount']!.value = TextEditingValue(
                                    text: formatter.format(parsed.round()),
                                    selection: TextSelection.collapsed(
                                      offset: formatter.format(parsed.round()).length,
                                    ),
                                  );
                                }
                              },
                            ),
                            SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                onPressed: () => _removeEarlyPaymentField(index),
                                icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _addEarlyPaymentField,
                        icon: Icon(Icons.add),
                        label: Text('繰上返済を追加'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade400,
                        ),
                      ),
                    ),
                  ],
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
                  onPressed: _calculateDetailed,
                  icon: Icon(Icons.calculate_rounded, size: 24),
                  label: Text('詳細計算',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  ),
                ),
              ),
            ),

            // 計算結果表示
            if (_detailedMonthlyPayment > 0) ...[
              _buildStyledCard(
                key: _resultKey,
                color: Colors.indigo.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('詳細計算結果', Icons.assessment),
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
                              Text('毎月支払額:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${formatter.format(_detailedMonthlyPayment.round())} 円',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('支払回数:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('$_detailedTotalPayments 回',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('総利息:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${formatter.format(_detailedTotalInterest.round())} 円',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('支払総額:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${formatter.format(_detailedTotalAmount.round())} 円',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToSchedulePage(_detailedSchedule, '詳細返済計画表'),
                        icon: Icon(Icons.table_chart),
                        label: Text('返済計画表を見る'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade600,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                      ),
                    ),
                  ],
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
