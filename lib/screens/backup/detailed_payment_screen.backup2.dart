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
  bool get wantKeepAlive => true;  // Ã§"Â»Ã©Â¢Ã£Â®Ã§Å Â¶Ã¦â€¦â€¹Ã£â€š'Ã¤Â¿Ã¦Å’Ã£â„¢Ã£â€šâ€¹
  
  // åŸºæœ¬æƒ…å ±
  final _loanAmountController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _loanTermYearsController = TextEditingController();
  final _loanTermMonthsController = TextEditingController(text: '0');
  String _repaymentMethod = 'å…ƒåˆ©å‡ç­‰';

  // ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆè¨­å®š
  bool _enableBonusPayment = false;
  final _bonusAmountController = TextEditingController();
  List<int> _bonusMonths = [6, 12];

  // ç¹°ä¸Šè¿”æ¸ˆè¨­å®š
  bool _enableEarlyPayment = false;
  List<Map<String, TextEditingController>> _earlyPayments = [];

  // è¨ˆç®—çµæžœ
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

  // ãƒãƒªãƒ‡ãƒ¼ã‚·ãƒ§ãƒ³ãƒ¡ã‚½ãƒƒãƒ‰ã‚’è¿½åŠ 
  String? _validateInputs() {
    // ãƒ­ãƒ¼ãƒ³é‡‘é¡ã®ãƒãƒªãƒ‡ãƒ¼ã‚·ãƒ§ãƒ³
    String loanAmountText = _loanAmountController.text.replaceAll(',', '').trim();
    if (loanAmountText.isEmpty || double.tryParse(loanAmountText) == null) {
      return 'ã€Œå€Ÿå…¥é‡‘é¡ã€ã«æ•°å­—ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';
    }
    double loanAmount = double.parse(loanAmountText);
    if (loanAmount <= 0) {
      return 'ã€Œå€Ÿå…¥é‡‘é¡ã€ã«0ã‚ˆã‚Šå¤§ãã„æ•°å­—ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';
    }

    // å¹´åˆ©ã®ãƒãƒªãƒ‡ãƒ¼ã‚·ãƒ§ãƒ³
    String interestRateText = _interestRateController.text.trim();
    if (interestRateText.isEmpty || double.tryParse(interestRateText) == null) {
      return 'ã€Œå¹´åˆ©ã€ã«æ•°å­—ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';
    }
    double interestRate = double.parse(interestRateText);
    if (interestRate < 0) {
      return 'ã€Œå¹´åˆ©ã€ã«0ä»¥ä¸Šã®æ•°å­—ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';
    }

    // å¹´æ•°ã®ãƒãƒªãƒ‡ãƒ¼ã‚·ãƒ§ãƒ³
    String yearsText = _loanTermYearsController.text.trim();
    if (yearsText.isEmpty || int.tryParse(yearsText) == null) {
      return 'ã€Œå¹´æ•°ã€ã«æ•°å­—ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';
    }
    int years = int.parse(yearsText);
    if (years < 0) {
      return 'ã€Œå¹´æ•°ã€ã«0ä»¥ä¸Šã®æ•°å­—ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';
    }

    // ãƒ¶æœˆã®ãƒãƒªãƒ‡ãƒ¼ã‚·ãƒ§ãƒ³
    String monthsText = _loanTermMonthsController.text.trim();
    if (monthsText.isEmpty || int.tryParse(monthsText) == null) {
      return 'ã€Œãƒ¶æœˆã€ã«æ•°å­—ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';
    }
    int months = int.parse(monthsText);
    if (months < 0 || months >= 12) {
      return 'ã€Œãƒ¶æœˆã€ã«0ï½ž11ã®æ•°å­—ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';
    }

    // åˆè¨ˆæœŸé–“ã®ãƒã‚§ãƒƒã‚¯
    int totalMonths = years * 12 + months;
    if (totalMonths <= 0) {
      return 'å€Ÿå…¥æœŸé–“ã‚’1ãƒ¶æœˆä»¥ä¸Šã«è¨­å®šã—ã¦ãã ã•ã„';
    }

    // ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆé¡ã®ãƒãƒªãƒ‡ãƒ¼ã‚·ãƒ§ãƒ³ï¼ˆæœ‰åŠ¹ãªå ´åˆã®ã¿ï¼‰
    if (_enableBonusPayment) {
      String bonusAmountText = _bonusAmountController.text.replaceAll(',', '').trim();
      if (bonusAmountText.isNotEmpty && double.tryParse(bonusAmountText) == null) {
        return 'ã€Œãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆé¡ã€ã«æ•°å­—ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';
      }
    }

    // ç¹°ä¸Šè¿”æ¸ˆã®ãƒãƒªãƒ‡ãƒ¼ã‚·ãƒ§ãƒ³ï¼ˆæœ‰åŠ¹ãªå ´åˆã®ã¿ï¼‰
    if (_enableEarlyPayment) {
      for (int i = 0; i < _earlyPayments.length; i++) {
        String monthText = _earlyPayments[i]['month']!.text.trim();
        String amountText = _earlyPayments[i]['amount']!.text.replaceAll(',', '').trim();
        
        if (monthText.isNotEmpty && int.tryParse(monthText) == null) {
          return 'ç¹°ä¸Šè¿”æ¸ˆã®ã€Œè¿”æ¸ˆæœˆã€ã«æ•°å­—ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';
        }
        if (amountText.isNotEmpty && double.tryParse(amountText) == null) {
          return 'ç¹°ä¸Šè¿”æ¸ˆã®ã€Œç¹°ä¸Šé‡‘é¡ã€ã«æ•°å­—ã‚’å…¥åŠ›ã—ã¦ãã ã•ã„';
        }
      }
    }

    return null; // ã‚¨ãƒ©ãƒ¼ãªã—
  }

  // è©³ç´°è¨ˆç®—ãƒ¡ã‚¤ãƒ³
  void _calculateDetailed() async {
    // ã‚­ãƒ¼ãƒœãƒ¼ãƒ‰ã‚’é–‰ã˜ã‚‹
    FocusScope.of(context).unfocus();

    // ãƒãƒªãƒ‡ãƒ¼ã‚·ãƒ§ãƒ³ãƒã‚§ãƒƒã‚¯
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

    // åŸºæœ¬è¨ˆç®—
    _calculateBasic(loanAmount, monthlyInterest, totalMonths);

    // ã‚ªãƒ—ã‚·ãƒ§ãƒ³è¾¼ã¿è¨ˆç®—
    _calculateWithOptions(loanAmount, monthlyInterest, totalMonths);

    // è¨ˆç®—çµæžœãŒè¡¨ç¤ºã•ã‚Œã¦ã„ã‚‹éƒ¨åˆ†ã¾ã§è‡ªå‹•ã‚¹ã‚¯ãƒ­ãƒ¼ãƒ«
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
    if (_repaymentMethod == 'å…ƒåˆ©å‡ç­‰') {
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

  // ãƒœãƒ¼ãƒŠã‚¹æœˆåˆ¤å®šãƒ¡ã‚½ãƒƒãƒ‰
  bool _isBonusMonth(int monthNumber) {
    int monthInYear = monthNumber % 12;
    if (monthInYear == 0) monthInYear = 12;
    return _bonusMonths.contains(monthInYear);
  }

  void _calculateWithOptions(double loanAmount, double monthlyInterest, int totalMonths) {
    // ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆæƒ…å ±ã®æº–å‚™
    double bonusAmount = 0;
    if (_enableBonusPayment) {
      bonusAmount = double.tryParse(_bonusAmountController.text.replaceAll(',', '')) ?? 0;
    }

    // ç¹°ä¸Šè¿”æ¸ˆæƒ…å ±ã®æº–å‚™
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

    // ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆã‚’è€ƒæ…®ã—ãŸæœˆã€…è¿”æ¸ˆé¡ã®è¨ˆç®—
    double monthlyPayment = _basicMonthlyPayment;
    
    if (_enableBonusPayment && bonusAmount > 0) {
      // ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆã®ç¾åœ¨ä¾¡å€¤ã‚’è¨ˆç®—
      double bonusPresentValue = 0;
      for (int i = 1; i <= totalMonths; i++) {
        if (_isBonusMonth(i)) {
          bonusPresentValue += bonusAmount / pow(1 + monthlyInterest, i);
        }
      }
      
      // ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆã‚’å·®ã—å¼•ã„ãŸå®Ÿè³ªå€Ÿå…¥é¡
      double adjustedLoanAmount = loanAmount - bonusPresentValue;
      
      // æœˆã€…è¿”æ¸ˆé¡ã‚’è¨ˆç®—
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

      // ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆã®å‡¦ç†
      bool isBonusMonth = _enableBonusPayment && _isBonusMonth(i);
      if (isBonusMonth && bonusAmount > 0) {
        currentPayment += bonusAmount;
        principal += bonusAmount;
        specialNote = 'ãƒœãƒ¼ãƒŠã‚¹';
      }

      // ç¹°ä¸Šè¿”æ¸ˆã®å‡¦ç†
      bool hasEarlyPayment = _enableEarlyPayment && earlyPaymentMap.containsKey(i);
      if (hasEarlyPayment) {
        double earlyPaymentAmount = earlyPaymentMap[i]!;
        currentPayment += earlyPaymentAmount;
        principal += earlyPaymentAmount;
        specialNote = specialNote.isEmpty ? 'ç¹°ä¸Šè¿”æ¸ˆ' : '$specialNoteãƒ»ç¹°ä¸Šè¿”æ¸ˆ';
      }

      // å…ƒé‡‘ãŒæ®‹é«˜ã‚’è¶…ãˆã‚‹å ´åˆã®èª¿æ•´
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
            Text('ã‚¨ãƒ©ãƒ¼'),
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
    super.build(context);  // AutomaticKeepAliveClientMixinã§å¿…è¦
    
    return Scaffold(
      appBar: AppBar(
        title: Text('è©³ç´°è¿”æ¸ˆè¨ˆç®—'),
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
            // åŸºæœ¬æƒ…å ±å…¥åŠ›
            _buildStyledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  TextField(
                    controller: _loanAmountController,
                    decoration: InputDecoration(
                      labelText: 'å€Ÿå…¥é‡‘é¡(å††)',
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
                      labelText: 'å¹´åˆ©(%)',
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
                            labelText: 'å¹´æ•°',
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
                            labelText: 'ãƒ¶æœˆ',
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

            // ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆè¨­å®š
            _buildStyledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆè¨­å®š', Icons.card_giftcard_outlined),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆã‚’åˆ©ç”¨ã™ã‚‹'),
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
                              'ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆã¯æ¯Žå¹´6æœˆã¨12æœˆã«å®Ÿæ–½ã•ã‚Œã¾ã™',
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
                        labelText: 'ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆé¡(å††)',
                        hintText: 'ä¾‹: 100,000',
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

            // ç¹°ä¸Šè¿”æ¸ˆè¨­å®š
            _buildStyledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('ç¹°ä¸Šè¿”æ¸ˆè¨­å®š', Icons.add_circle_outline),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('ç¹°ä¸Šè¿”æ¸ˆã‚’åˆ©ç”¨ã™ã‚‹'),
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
                                labelText: 'è¿”æ¸ˆæœˆ',
                                hintText: 'ä¾‹: 12',
                                prefixIcon: Icon(Icons.calendar_month,
                                    color: Colors.indigo.shade600),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: payment['amount']!,
                              decoration: InputDecoration(
                                labelText: 'ç¹°ä¸Šé‡‘é¡(å††)',
                                hintText: 'ä¾‹: 1,000,000',
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
                        label: Text('ç¹°ä¸Šè¿”æ¸ˆã‚’è¿½åŠ '),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade400,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // è¨ˆç®—ãƒœã‚¿ãƒ³
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
                  label: Text('è©³ç´°è¨ˆç®—',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  ),
                ),
              ),
            ),

            // è¨ˆç®—çµæžœè¡¨ç¤º
            if (_detailedMonthlyPayment > 0) ...[
              _buildStyledCard(
                key: _resultKey,
                color: Colors.indigo.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('è©³ç´°è¨ˆç®—çµæžœ', Icons.assessment),
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
                              Text('æ¯Žæœˆæ”¯æ‰•é¡:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${formatter.format(_detailedMonthlyPayment.round())} å††',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('æ”¯æ‰•å›žæ•°:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('$_detailedTotalPayments å›ž',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('ç·åˆ©æ¯:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${formatter.format(_detailedTotalInterest.round())} å††',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('æ”¯æ‰•ç·é¡:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${formatter.format(_detailedTotalAmount.round())} å††',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToSchedulePage(_detailedSchedule, 'è©³ç´°è¿”æ¸ˆè¨ˆç”»è¡¨'),
                        icon: Icon(Icons.table_chart),
                        label: Text('è¿”æ¸ˆè¨ˆç”»è¡¨ã‚’è¦‹ã‚‹'),
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
