// Enhanced reverse calculation screen with bonus payment functionality
// File location: lib/screens/reverse_calculation_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import 'repayment_schedule_page.dart';

class ReverseCalculationScreen extends StatefulWidget {
  final AppState appState;

  const ReverseCalculationScreen({
    Key? key,
    required this.appState,
  }) : super(key: key);

  @override
  _ReverseCalculationScreenState createState() => _ReverseCalculationScreenState();
}

class _ReverseCalculationScreenState extends State<ReverseCalculationScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // 共通入力フィールド
  final _monthlyPaymentController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _loanTermYearsController = TextEditingController();
  final _loanTermMonthsController = TextEditingController(text: '0');
  final _bonusAmountController = TextEditingController();
  
  String _repaymentMethod = '元利均等';
  bool _enableBonusPayment = false;  // ボーナス返済の有効/無効
  List<int> _bonusMonths = [6, 12];  // ボーナス返済月

  // 計算結果
  double _calculatedAmount = 0;  // 借入可能額
  double _totalInterest = 0;     // 総利息
  double _totalAmount = 0;       // 総返済額
  List<List<String>> _repaymentSchedule = [];

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
    _monthlyPaymentController.dispose();
    _interestRateController.dispose();
    _loanTermYearsController.dispose();
    _loanTermMonthsController.dispose();
    _bonusAmountController.dispose();
    super.dispose();
  }

  // ボーナス月判定メソッド
  bool _isBonusMonth(int monthNumber) {
    int monthInYear = monthNumber % 12;
    if (monthInYear == 0) monthInYear = 12;
    return _bonusMonths.contains(monthInYear);
  }

  // 入力値の検証
  String? _validateInputs() {
    // 毎月返済額の検証
    String monthlyPaymentText = _monthlyPaymentController.text.replaceAll(',', '').trim();
    if (monthlyPaymentText.isEmpty || double.tryParse(monthlyPaymentText) == null) {
      return '「毎月の返済額」に数値を入力してください';
    }
    double monthlyPayment = double.parse(monthlyPaymentText);
    if (monthlyPayment <= 0) {
      return '「毎月の返済額」に0より大きい数値を入力してください';
    }

    // 金利の検証
    String interestRateText = _interestRateController.text.trim();
    if (interestRateText.isEmpty || double.tryParse(interestRateText) == null) {
      return '「年利」に数値を入力してください';
    }
    double interestRate = double.parse(interestRateText);
    if (interestRate < 0) {
      return '「年利」に0以上の数値を入力してください';
    }

    // 返済期間の検証
    String yearsText = _loanTermYearsController.text.trim();
    if (yearsText.isEmpty || int.tryParse(yearsText) == null) {
      return '「年数」に数値を入力してください';
    }
    int years = int.parse(yearsText);
    if (years < 0) {
      return '「年数」に0以上の数値を入力してください';
    }

    String monthsText = _loanTermMonthsController.text.trim();
    if (monthsText.isEmpty || int.tryParse(monthsText) == null) {
      return '「ヶ月」に数値を入力してください';
    }
    int months = int.parse(monthsText);
    if (months < 0 || months >= 12) {
      return '「ヶ月」に0～11の数値を入力してください';
    }

    int totalMonths = years * 12 + months;
    if (totalMonths <= 0) {
      return '返済期間を1ヶ月以上に設定してください';
    }

    // ボーナス返済の検証
    if (_enableBonusPayment) {
      String bonusAmountText = _bonusAmountController.text.replaceAll(',', '').trim();
      if (bonusAmountText.isEmpty || double.tryParse(bonusAmountText) == null) {
        return '「ボーナス返済額」に数値を入力してください';
      }
      double bonusAmount = double.parse(bonusAmountText);
      if (bonusAmount < 0) {
        return '「ボーナス返済額」に0以上の数値を入力してください';
      }
    }

    return null; // エラーなし
  }

  // 逆算計算メイン（借入可能額のみ）
  void _calculateLoanAmount() async {
    // キーボードを閉じる
    FocusScope.of(context).unfocus();

    // バリデーションチェック
    String? validationError = _validateInputs();
    if (validationError != null) {
      _showErrorDialog(validationError);
      return;
    }

    double monthlyPayment = double.parse(_monthlyPaymentController.text.replaceAll(',', ''));
    double annualInterest = double.parse(_interestRateController.text);
    double monthlyInterest = annualInterest / 100 / 12;
    double bonusAmount = _enableBonusPayment 
        ? double.parse(_bonusAmountController.text.replaceAll(',', ''))
        : 0;

    _calculateMaxLoanAmount(monthlyPayment, monthlyInterest, bonusAmount);

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

  // ボーナス返済を考慮した借入可能額計算
  void _calculateMaxLoanAmount(double monthlyPayment, double monthlyInterest, double bonusAmount) {
    int years = int.parse(_loanTermYearsController.text);
    int months = int.parse(_loanTermMonthsController.text);
    int totalMonths = years * 12 + months;

    double maxLoanAmount;

    if (_repaymentMethod == '元利均等') {
      // 元利均等方式での借入可能額（ボーナス返済考慮）
      if (monthlyInterest > 0) {
        if (bonusAmount > 0) {
          // ボーナス返済の現在価値を計算
          double bonusPresentValue = 0;
          for (int i = 1; i <= totalMonths; i++) {
            if (_isBonusMonth(i)) {
              bonusPresentValue += bonusAmount / pow(1 + monthlyInterest, i);
            }
          }
          
          // 月々返済の現在価値を計算
          double monthlyPresentValue = monthlyPayment * 
              (1 - (1 / pow(1 + monthlyInterest, totalMonths))) / 
              monthlyInterest;
          
          // 総借入可能額
          maxLoanAmount = monthlyPresentValue + bonusPresentValue;
        } else {
          // ボーナス返済なしの場合
          maxLoanAmount = monthlyPayment * 
              (1 - (1 / pow(1 + monthlyInterest, totalMonths))) / 
              monthlyInterest;
        }
      } else {
        // 金利0%の場合
        double bonusTotalPayment = 0;
        for (int i = 1; i <= totalMonths; i++) {
          if (_isBonusMonth(i)) {
            bonusTotalPayment += bonusAmount;
          }
        }
        maxLoanAmount = (monthlyPayment * totalMonths) + bonusTotalPayment;
      }
    } else {
      // 元金均等方式での借入可能額（ボーナス返済考慮）
      if (monthlyInterest > 0) {
        // 簡易計算：初回返済額として計算し、ボーナス分を加算
        double baseAmount = monthlyPayment / ((1.0 / totalMonths) + monthlyInterest);
        double bonusTotalPayment = 0;
        for (int i = 1; i <= totalMonths; i++) {
          if (_isBonusMonth(i)) {
            bonusTotalPayment += bonusAmount;
          }
        }
        // ボーナス分の現在価値を近似計算で加算
        maxLoanAmount = baseAmount + (bonusTotalPayment * 0.7); // 簡易現在価値
      } else {
        double bonusTotalPayment = 0;
        for (int i = 1; i <= totalMonths; i++) {
          if (_isBonusMonth(i)) {
            bonusTotalPayment += bonusAmount;
          }
        }
        maxLoanAmount = (monthlyPayment * totalMonths) + bonusTotalPayment;
      }
    }

    // 返済スケジュールの生成
    _generateSchedule(maxLoanAmount, monthlyInterest, totalMonths, bonusAmount);

    setState(() {
      _calculatedAmount = maxLoanAmount;
    });
  }

  // 返済スケジュール生成（ボーナス返済考慮）
  void _generateSchedule(double loanAmount, double monthlyInterest, int totalMonths, double bonusAmount) {
    List<List<String>> schedule = [];
    double balance = loanAmount;
    double totalInterestCalc = 0;

    if (_repaymentMethod == '元利均等') {
      // 元利均等での実際の月額計算
      double actualMonthlyPayment;
      if (monthlyInterest > 0) {
        actualMonthlyPayment = loanAmount * monthlyInterest / 
            (1 - (1 / pow(1 + monthlyInterest, totalMonths)));
      } else {
        actualMonthlyPayment = loanAmount / totalMonths;
      }

      for (int i = 1; i <= totalMonths && balance > 0; i++) {
        double interest = balance * monthlyInterest;
        double principal = actualMonthlyPayment - interest;
        double currentPayment = actualMonthlyPayment;
        bool isBonusMonth = _isBonusMonth(i);
        
        // ボーナス月の場合
        if (isBonusMonth && bonusAmount > 0) {
          principal += bonusAmount;
          currentPayment += bonusAmount;
        }
        
        if (principal > balance) {
          principal = balance;
          currentPayment = principal + interest;
        }
        
        balance -= principal;
        balance = max(balance, 0);
        totalInterestCalc += interest;

        schedule.add([
          i.toString(),
          formatter.format(principal.round()),
          formatter.format(interest.round()),
          formatter.format(currentPayment.round()),
          formatter.format(balance.round()),
          isBonusMonth ? 'ボーナス' : '',
        ]);
      }
    } else {
      // 元金均等
      double principalPayment = loanAmount / totalMonths;

      for (int i = 1; i <= totalMonths && balance > 0; i++) {
        double interest = balance * monthlyInterest;
        double principal = principalPayment;
        double currentPayment = principalPayment + interest;
        bool isBonusMonth = _isBonusMonth(i);
        
        // ボーナス月の場合
        if (isBonusMonth && bonusAmount > 0) {
          principal += bonusAmount;
          currentPayment += bonusAmount;
        }
        
        balance -= principal;
        balance = max(balance, 0);
        totalInterestCalc += interest;

        schedule.add([
          i.toString(),
          formatter.format(principal.round()),
          formatter.format(interest.round()),
          formatter.format(currentPayment.round()),
          formatter.format(balance.round()),
          isBonusMonth ? 'ボーナス' : '',
        ]);
      }
    }

    setState(() {
      _repaymentSchedule = schedule;
      _totalInterest = totalInterestCalc;
      _totalAmount = loanAmount + totalInterestCalc;
    });
  }

  // エラーダイアログ表示
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('入力エラー'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ページタイトル
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade600, Colors.indigo.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.calculate, color: Colors.white, size: 32),
                  SizedBox(height: 8),
                  Text(
                    '借入診断',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '月々の返済額から借入可能額を計算',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // 返済方式選択
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '返済方式',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('元利均等'),
                          subtitle: Text('毎月一定額', style: TextStyle(fontSize: 12)),
                          value: '元利均等',
                          groupValue: _repaymentMethod,
                          onChanged: (value) {
                            setState(() {
                              _repaymentMethod = value!;
                              _calculatedAmount = 0;
                              _repaymentSchedule.clear();
                            });
                          },
                          activeColor: Colors.indigo,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('元金均等'),
                          subtitle: Text('元金一定額', style: TextStyle(fontSize: 12)),
                          value: '元金均等',
                          groupValue: _repaymentMethod,
                          onChanged: (value) {
                            setState(() {
                              _repaymentMethod = value!;
                              _calculatedAmount = 0;
                              _repaymentSchedule.clear();
                            });
                          },
                          activeColor: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // 入力フィールド
            _buildInputSection(),

            SizedBox(height: 24),

            // 計算ボタン
            Container(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _calculateLoanAmount,
                icon: Icon(Icons.calculate, size: 24),
                label: Text(
                  _enableBonusPayment ? '借入可能額を計算' : '借入可能額を計算',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),

            SizedBox(height: 32),

            // 計算結果表示
            if (_calculatedAmount > 0) _buildResultSection(),
          ],
        ),
      ),
    );
  }

  // 入力セクション構築
  Widget _buildInputSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '借入条件を入力',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade700,
            ),
          ),
          SizedBox(height: 20),

          // 毎月の返済額
          _buildInputField(
            label: '毎月の返済額',
            controller: _monthlyPaymentController,
            suffix: '円',
            hint: '例: 100000',
            icon: Icons.payments,
          ),

          SizedBox(height: 16),

          // 年利
          _buildInputField(
            label: '年利',
            controller: _interestRateController,
            suffix: '%',
            hint: '例: 2.5',
            icon: Icons.percent,
          ),

          SizedBox(height: 16),

          // 返済期間
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: '返済期間（年）',
                  controller: _loanTermYearsController,
                  suffix: '年',
                  hint: '例: 35',
                  icon: Icons.schedule,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildInputField(
                  label: '（月）',
                  controller: _loanTermMonthsController,
                  suffix: 'ヶ月',
                  hint: '0-11',
                  icon: Icons.calendar_month,
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // ボーナス返済設定
          _buildBonusPaymentSection(),
        ],
      ),
    );
  }

  // ボーナス返済設定セクション
  Widget _buildBonusPaymentSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.blue.shade600),
              SizedBox(width: 8),
              Text(
                'ボーナス返済',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
              Spacer(),
              Switch(
                value: _enableBonusPayment,
                onChanged: (value) {
                  setState(() {
                    _enableBonusPayment = value;
                    _calculatedAmount = 0;
                    _repaymentSchedule.clear();
                  });
                },
                activeColor: Colors.blue.shade600,
              ),
            ],
          ),
          
          if (_enableBonusPayment) ...[
            SizedBox(height: 16),
            
            // ボーナス返済額
            _buildInputField(
              label: 'ボーナス返済額（1回あたり）',
              controller: _bonusAmountController,
              suffix: '円',
              hint: '例: 200000',
              icon: Icons.monetization_on,
            ),
            
            SizedBox(height: 16),
            
            // ボーナス返済月選択
            Text(
              'ボーナス返済月',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: Text('6月'),
                  selected: _bonusMonths.contains(6),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        if (!_bonusMonths.contains(6)) _bonusMonths.add(6);
                      } else {
                        _bonusMonths.remove(6);
                      }
                      _calculatedAmount = 0;
                      _repaymentSchedule.clear();
                    });
                  },
                  selectedColor: Colors.blue.shade200,
                ),
                FilterChip(
                  label: Text('12月'),
                  selected: _bonusMonths.contains(12),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        if (!_bonusMonths.contains(12)) _bonusMonths.add(12);
                      } else {
                        _bonusMonths.remove(12);
                      }
                      _calculatedAmount = 0;
                      _repaymentSchedule.clear();
                    });
                  },
                  selectedColor: Colors.blue.shade200,
                ),
              ],
            ),
            
            SizedBox(height: 8),
            Text(
              'ボーナス返済により、より多くの借入が可能になります',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 入力フィールド構築ヘルパー
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String suffix,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            prefixIcon: Icon(icon, color: Colors.indigo.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.indigo, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  // 結果セクション構築
  Widget _buildResultSection() {
    return Column(
      key: _resultKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 計算結果カード
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.account_balance, color: Colors.white, size: 48),
              SizedBox(height: 16),
              Text(
                _enableBonusPayment ? '借入可能額（ボーナス返済込み）' : '借入可能額',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              SizedBox(height: 8),
              Text(
                '${formatter.format(_calculatedAmount.round())} 円',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 20),

        // 返済総額情報
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSummaryRow('総利息額', '${formatter.format(_totalInterest.round())} 円', Colors.orange),
              SizedBox(height: 12),
              _buildSummaryRow('総返済額', '${formatter.format(_totalAmount.round())} 円', Colors.red),
              if (_enableBonusPayment) ...[
                SizedBox(height: 12),
                _buildSummaryRow('年間ボーナス返済', '${formatter.format((double.parse(_bonusAmountController.text.replaceAll(',', '')) * _bonusMonths.length).round())} 円', Colors.blue),
              ],
            ],
          ),
        ),

        SizedBox(height: 24),

        // 返済スケジュール表示ボタン
        if (widget.appState.isPremium && _repaymentSchedule.isNotEmpty)
          Container(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RepaymentSchedulePage(
                      schedule: _repaymentSchedule,
                      title: '借入可能額 ${formatter.format(_calculatedAmount.round())}円の返済スケジュール',
                      isPremium: widget.appState.isPremium,
                    ),
                  ),
                );
              },
              icon: Icon(Icons.table_chart),
              label: Text(_enableBonusPayment ? 'ボーナス返済スケジュールを表示' : '返済スケジュールを表示'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // サマリー行の構築
  Widget _buildSummaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
