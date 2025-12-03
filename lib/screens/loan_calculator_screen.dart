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

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;  // 画面の状態を保持する
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

  void _calculate() {
    // キーボードを閉じる
    FocusScope.of(context).unfocus();

    // バリデーションチェック
    String? validationError = _validateInputs();
    if (validationError != null) {
      _showErrorDialog(validationError);
      return;
    }

    double loanAmount = double.parse(_loanAmountController.text.replaceAll(',', ''));
    double annualInterest = double.parse(_interestRateController.text);
    int years = int.parse(_loanTermYearsController.text);
    int months = int.parse(_loanTermMonthsController.text);
    
    int totalMonths = years * 12 + months;
    double monthlyInterest = annualInterest / 100 / 12;
    
    if (_repaymentMethod == '元利均等') {
      double monthlyPayment = loanAmount * monthlyInterest / 
        (1 - (1 / pow(1 + monthlyInterest, totalMonths)));
      
      setState(() {
        _monthlyPayment = monthlyPayment;
        _totalPayments = totalMonths;
        _totalInterest = (monthlyPayment * totalMonths) - loanAmount;
        _totalAmount = loanAmount + _totalInterest;
        
        // 返済スケジュール計算
        _repaymentSchedule = _calculateRepaymentSchedule(
          loanAmount, monthlyInterest, totalMonths, monthlyPayment);
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
    }
  }

  List<List<String>> _calculateRepaymentSchedule(double loanAmount, double monthlyInterest, 
      int totalMonths, double monthlyPayment) {
    List<List<String>> schedule = [];
    double balance = loanAmount;
    
    for (int i = 1; i <= totalMonths; i++) {
      double interest = balance * monthlyInterest;
      double principal = monthlyPayment - interest;
      balance -= principal;
      
      // 最後の回で残高が0を下回らないよう調整
      if (balance < 0) {
        principal += balance;
        balance = 0;
      }
      
      schedule.add([
        i.toString(),
        formatter.format(monthlyPayment.round()),
        formatter.format(principal.round()),
        formatter.format(interest.round()),
        formatter.format(balance.round()),
        '通常'
      ]);
      
      if (balance <= 0) break;
    }
    
    return schedule;
  }

  String? _validateInputs() {
    if (_loanAmountController.text.trim().isEmpty) {
      return '借入金額を入力してください';
    }
    if (double.tryParse(_loanAmountController.text.replaceAll(',', '')) == null) {
      return '借入金額には数字を入力してください';
    }
    if (_interestRateController.text.trim().isEmpty) {
      return '金利を入力してください';
    }
    if (double.tryParse(_interestRateController.text) == null) {
      return '金利には数字を入力してください';
    }
    if (_loanTermYearsController.text.trim().isEmpty) {
      return 'ローン期間（年）を入力してください';
    }
    if (int.tryParse(_loanTermYearsController.text) == null) {
      return 'ローン期間（年）には数字を入力してください';
    }
    
    int years = int.parse(_loanTermYearsController.text);
    int months = int.tryParse(_loanTermMonthsController.text) ?? 0;
    
    if (years <= 0 && months <= 0) {
      return 'ローン期間は1ヶ月以上である必要があります';
    }
    
    return null;
  }

  void _saveData(String title) {
    if (_monthlyPayment > 0) {
      final loanData = LoanData(
        title: title,
        savedDate: DateTime.now(),
        loanAmount: double.parse(_loanAmountController.text.replaceAll(',', '')),
        interestRate: double.parse(_interestRateController.text),
        years: int.parse(_loanTermYearsController.text),
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
      
      widget.appState.saveLoanData(loanData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.save, color: Colors.white),
              SizedBox(width: 8),
              Text('ローンデータを保存しました'),
            ],
          ),
          backgroundColor: Colors.green.shade500,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showSaveDialog() {
    if (!widget.appState.isPremium) {
      _showPremiumDialog();
      return;
    }

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
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: 'タイトル',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
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

  void _showPremiumDialog() {
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
              'データ保存機能はプレミアムプラン限定です',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
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
                  Text('• ローン計算結果の保存\n• データ比較機能\n• ボーナス返済計算\n• 早期返済計算\n• 広告非表示'),
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
              backgroundColor: Colors.indigo.shade600,
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin用
    return GestureDetector(
      onTap: () {
        // 余白をタップした時にキーボードを閉じる
        FocusScope.of(context).unfocus();
      },
      child: Container(
        color: Colors.grey.shade50,
        child: SingleChildScrollView(
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
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _repaymentMethod,
                            isExpanded: true,
                            underline: SizedBox(),
                            items: ['元利均等'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _repaymentMethod = newValue!;
                              });
                            },
                          ),
                        ),
                        SizedBox(height: 24),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _calculate,
                            icon: Icon(Icons.calculate),
                            label: Text('計算する',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade600,
                              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 計算結果表示
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
                                    Text('${formatter.format(_monthlyPayment.round())} 円',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('支払回数:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text('$_totalPayments 回',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('総利息:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text('${formatter.format(_totalInterest.round())} 円',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('支払総額:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text('${formatter.format(_totalAmount.round())} 円',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _navigateToSchedulePage(_repaymentSchedule, '返済計画表'),
                                  icon: Icon(Icons.table_chart),
                                  label: Text('返済計画表を見る'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo.shade600,
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _showSaveDialog,
                                  icon: Icon(Icons.save),
                                  label: Text('計算結果を保存'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  ),
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
        ), // SingleChildScrollView
      ), // GestureDetector
    ); // Container
  }
}
