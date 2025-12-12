import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
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
    // 基本情報のバリデーション
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

    // ボーナス返済のバリデーション（有効な場合のみ）
    if (_enableBonusPayment) {
      String bonusAmountText = _bonusAmountController.text.replaceAll(',', '').trim();
      if (bonusAmountText.isEmpty || double.tryParse(bonusAmountText) == null) {
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
        specialNote = specialNote.isEmpty ? '繰上' : '${specialNote}+繰上';
      }

      // 最後の回で残高調整
      if (principal > balance) {
        currentPayment = currentPayment - (principal - balance);
        principal = balance;
      }

      balance -= principal;
      totalInterest += interest;
      actualMonths = i;

      // スケジュールに追加
      schedule.add([
        i.toString(),
        formatter.format(currentPayment.round()),
        formatter.format(principal.round()),
        formatter.format(interest.round()),
        formatter.format(balance.round()),
        specialNote.isEmpty ? '通常' : specialNote
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

  Future<void> _shareDetailedCSV(BuildContext context) async {
    if (!widget.appState.isPremium) {
      _showPremiumRequiredDialog(context);
      return;
    }

    if (_detailedSchedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('まず計算を実行してください'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    try {
      // CSVデータ作成（日本語ヘッダー）
      List<List<String>> csvData = [
        ['支払回数', '毎月の支払額', '元金', '利息', '残高', '返済種別']
      ];
      csvData.addAll(_detailedSchedule);

      String csv = const ListToCsvConverter().convert(csvData);
      
      // ファイル名を生成
      final timestamp = DateTime.now();
      final filename = 'detailed_repayment_schedule_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}.csv';
      
      // CSVデータを共有
      final result = await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(csv.codeUnits),
          name: filename,
          mimeType: 'text/csv',
        ),
      ], 
      text: '詳細返済計画表のCSVファイルです。',
      subject: '詳細返済計画表',
      );

      // 実際に共有された場合のみ成功メッセージを表示
      if (result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.share, color: Colors.white),
                SizedBox(width: 8),
                Text('CSVファイルを共有しました'),
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
    super.build(context);
    return Container(
      color: Colors.grey.shade50,
      child: GestureDetector(
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
                    keyboardType: TextInputType.number,
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
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          SizedBox(width: 8),
          Text(
            'ボーナス返済月を選択してください',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      SizedBox(height: 12),
      
      // ボーナス返済月選択
      Wrap(
        spacing: 12,
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
              });
            },
            selectedColor: Colors.blue.shade200,
            checkmarkColor: Colors.blue.shade700,
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
              });
            },
            selectedColor: Colors.blue.shade200,
            checkmarkColor: Colors.blue.shade700,
          ),
        ],
      ),
      SizedBox(height: 8),
      Text(
        '選択した月にボーナス返済が実行されます',
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue.shade600,
          fontStyle: FontStyle.italic,
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
                        prefixIcon: Icon(Icons.card_giftcard,
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
                  _buildSectionTitle('繰上返済設定', Icons.trending_up),
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
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '繰上返済により総利息を削減できます',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    ...List.generate(_earlyPayments.length, (index) {
                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('繰上返済 ${index + 1}', 
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                Spacer(),
                                if (_earlyPayments.length > 1)
                                  IconButton(
                                    icon: Icon(Icons.remove_circle, 
                                        color: Colors.red.shade600),
                                    onPressed: () => _removeEarlyPaymentField(index),
                                  ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Column(
                              children: [
                                TextField(
                                  controller: _earlyPayments[index]['month']!,
                                  decoration: InputDecoration(
                                    labelText: '返済月',
                                    hintText: '例: 12 (12ヶ月目)',
                                    prefixIcon: Icon(Icons.event,
                                        color: Colors.indigo.shade600),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                SizedBox(height: 16),
                                TextField(
                                  controller: _earlyPayments[index]['amount']!,
                                  decoration: InputDecoration(
                                    labelText: '繰上金額(円)',
                                    prefixIcon: Icon(Icons.trending_up,
                                        color: Colors.indigo.shade600),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    String cleaned = value.replaceAll(',', '');
                                    double? parsed = double.tryParse(cleaned);
                                    if (parsed != null) {
                                      _earlyPayments[index]['amount']!.value = TextEditingValue(
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
                    }),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _addEarlyPaymentField,
                        icon: Icon(Icons.add),
                        label: Text('繰上返済を追加'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
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
                margin: EdgeInsets.symmetric(vertical: 24),
                child: ElevatedButton.icon(
                  onPressed: _calculateDetailed,
                  icon: Icon(Icons.calculate),
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
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateToSchedulePage(_detailedSchedule, '詳細返済計画表'),
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
                            onPressed: () => _shareDetailedCSV(context),
                            icon: Icon(Icons.share),
                            label: Text('CSVを共有'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlue.shade600,
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
        ), // SingleChildScrollView
      ), // GestureDetector
    ); // Container
  }
}
