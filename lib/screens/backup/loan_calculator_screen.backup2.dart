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
  String _repaymentMethod = 'å…ƒåˆ©å‡ç­‰';

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

  // ãƒ­ãƒ¼ãƒ³è¨ˆç®—ãƒ¡ã‚½ãƒƒãƒ‰ï¼ˆã‚¤ãƒ³ã‚¿ãƒ¼ã‚¹ãƒ†ã‚£ã‚·ãƒ£ãƒ«åºƒå‘Šå‰Šé™¤ï¼‰
  void _calculateLoan() async {
    // ã‚­ãƒ¼ãƒœãƒ¼ãƒ‰ã‚’é–‰ã˜ã‚‹
    FocusScope.of(context).unfocus();

    double loanAmount =
        double.tryParse(_loanAmountController.text.replaceAll(',', '')) ?? 0;
    double annualInterest = double.tryParse(_interestRateController.text) ?? 0;
    int years = int.tryParse(_loanTermYearsController.text) ?? 0;
    int months = int.tryParse(_loanTermMonthsController.text) ?? 0;
    int totalMonths = years * 12 + months;
    double monthlyInterest = annualInterest / 100 / 12;

    if (loanAmount <= 0 || totalMonths <= 0) {
      _showErrorDialog('å…¥åŠ›å€¤ã‚’ç¢ºèªã—ã¦ãã ã•ã„');
      return;
    }

    double monthlyPayment = 0;
    List<List<String>> schedule = [];
    double balance = loanAmount;
    double totalInterest = 0;

    if (_repaymentMethod == 'å…ƒåˆ©å‡ç­‰') {
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
      // å…ƒé‡‘å‡ç­‰ã®å ´åˆ
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

    // ã‚¤ãƒ³ã‚¿ãƒ¼ã‚¹ãƒ†ã‚£ã‚·ãƒ£ãƒ«åºƒå‘Šã®å‘¼ã³å‡ºã—ã‚’å‰Šé™¤
    // è¨ˆç®—å®Œäº†ã®ã¿ï¼ˆåºƒå‘Šè¡¨ç¤ºãªã—ï¼‰
  }

  // ãƒ‡ãƒ¼ã‚¿ã®ä¿å­˜
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
        content: Text('ã€Œ$titleã€ã¨ã—ã¦ä¿å­˜ã—ã¾ã—ãŸ'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ãƒ—ãƒ¬ãƒŸã‚¢ãƒ ãƒ—ãƒ©ãƒ³æ¡ˆå†…ãƒ€ã‚¤ã‚¢ãƒ­ã‚°ï¼ˆç„¡æ–™ãƒ¦ãƒ¼ã‚¶ãƒ¼å‘ã‘ï¼‰
  void _showPremiumPromptDialog() {
    // æ—¢ã«è³¼å…¥æ¸ˆã¿ã®å ´åˆã¯å‡¦ç†ã—ãªã„
    if (widget.appState.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('æ—¢ã«ãƒ—ãƒ¬ãƒŸã‚¢ãƒ ãƒ—ãƒ©ãƒ³ã‚’ã”åˆ©ç”¨ä¸­ã§ã™'),
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
            Text('ãƒ—ãƒ¬ãƒŸã‚¢ãƒ ãƒ—ãƒ©ãƒ³'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ãƒ­ãƒ¼ãƒ³è¨ˆç®—çµæžœã®ä¿å­˜ãƒ»å‰Šé™¤æ©Ÿèƒ½ã¯\nãƒ—ãƒ¬ãƒŸã‚¢ãƒ ãƒ—ãƒ©ãƒ³é™å®šã§ã™',
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
                        'ãƒ—ãƒ¬ãƒŸã‚¢ãƒ æ©Ÿèƒ½',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                      'â€¢ ãƒ­ãƒ¼ãƒ³è¨ˆç®—çµæžœã®ä¿å­˜\nâ€¢ ãƒ‡ãƒ¼ã‚¿æ¯”è¼ƒæ©Ÿèƒ½\nâ€¢ ãƒœãƒ¼ãƒŠã‚¹è¿”æ¸ˆè¨ˆç®—\nâ€¢ æ—©æœŸè¿”æ¸ˆè¨ˆç®—\nâ€¢ åºƒå‘Šéžè¡¨ç¤º'),
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
                      'ä¸€åº¦ã®è³¼å…¥ã§æ°¸ç¶šåˆ©ç”¨å¯èƒ½',
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
            child: Text('ã‚­ãƒ£ãƒ³ã‚»ãƒ«'),
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
                          Text('ãƒ—ãƒ¬ãƒŸã‚¢ãƒ ãƒ—ãƒ©ãƒ³ã¸ã‚¢ãƒƒãƒ—ã‚°ãƒ¬ãƒ¼ãƒ‰ã—ã¾ã—ãŸï¼'),
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
                    content: Text('è³¼å…¥ã«å¤±æ•—ã—ã¾ã—ãŸã€‚ã‚‚ã†ä¸€åº¦ãŠè©¦ã—ãã ã•ã„ã€‚'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: Icon(Icons.shopping_cart),
            label: Text('Â¥230ã§è³¼å…¥'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ã‚¨ãƒ©ãƒ¼ãƒ€ã‚¤ã‚¢ãƒ­ã‚°è¡¨ç¤º
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600, size: 28),
            SizedBox(width: 8),
            Text('å…¥åŠ›ã‚¨ãƒ©ãƒ¼'),
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

  // ä¿å­˜ãƒ€ã‚¤ã‚¢ãƒ­ã‚°è¡¨ç¤º
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
            Text('è¨ˆç®—çµæžœã‚’ä¿å­˜'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ä¿å­˜åã‚’å…¥åŠ›ã—ã¦ãã ã•ã„'),
            SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'ä¿å­˜å',
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
            child: Text('ã‚­ãƒ£ãƒ³ã‚»ãƒ«'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                _saveData(titleController.text.trim());
              }
            },
            child: Text('ä¿å­˜'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // è¿”æ¸ˆã‚¹ã‚±ã‚¸ãƒ¥ãƒ¼ãƒ«ç”»é¢ã¸ã®é·ç§»
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

  // ã‚¹ã‚¿ã‚¤ãƒ«ä»˜ãã‚«ãƒ¼ãƒ‰ä½œæˆ
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

  // ã‚»ã‚¯ã‚·ãƒ§ãƒ³ã‚¿ã‚¤ãƒˆãƒ«ä½œæˆ
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

  // ãƒ†ãƒ¼ãƒ–ãƒ«ãƒ˜ãƒƒãƒ€ãƒ¼ä½œæˆ
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

  // ãƒ†ãƒ¼ãƒ–ãƒ«ã‚»ãƒ«ä½œæˆ
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
        // ä½™ç™½ã‚’ã‚¿ãƒƒãƒ—ã—ãŸæ™‚ã«ã‚­ãƒ¼ãƒœãƒ¼ãƒ‰ã‚’é–‰ã˜ã‚‹
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
                'åŸºæœ¬è¨ˆç®—',
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
              // åºƒå‘Šè¡¨ç¤ºã‚¨ãƒªã‚¢
              if (!widget.appState.isPremium) widget.adService.getBannerAdWidget(),

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // å…¥åŠ›ãƒ•ã‚©ãƒ¼ãƒ 
                  _buildStyledCard(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20),
                        TextField(
                          controller: _loanAmountController,
                          decoration: InputDecoration(
                            labelText: 'å€Ÿå…¥é‡‘é¡ï¼ˆå…ƒæœ¬ï¼‰',
                            prefixIcon: Icon(Icons.monetization_on_rounded,
                                color: Colors.indigo.shade600),
                            suffixText: 'å††',
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
                            labelText: 'é‡‘åˆ©ï¼ˆå¹´åˆ© %ï¼‰',
                            prefixIcon: Icon(Icons.percent_rounded,
                                color: Colors.indigo.shade600),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: _loanTermYearsController,
                          decoration: InputDecoration(
                            labelText: 'ãƒ­ãƒ¼ãƒ³æœŸé–“ï¼ˆå¹´ï¼‰',
                            prefixIcon: Icon(Icons.calendar_today_rounded,
                                color: Colors.indigo.shade600),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: _loanTermMonthsController,
                          decoration: InputDecoration(
                            labelText: 'ãƒ­ãƒ¼ãƒ³æœŸé–“ï¼ˆæœˆï¼‰',
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
                              items: ['å…ƒåˆ©å‡ç­‰', 'å…ƒé‡‘å‡ç­‰']
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
                        onPressed: _calculateLoan,
                        icon: Icon(Icons.calculate_rounded, size: 24),
                        label: Text('è¨ˆç®—ã™ã‚‹',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding:
                              EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        ),
                      ),
                    ),
                  ),

                  // è¨ˆç®—çµæžœè¡¨ç¤ºã‚»ã‚¯ã‚·ãƒ§ãƒ³
                  if (_monthlyPayment > 0) ...[
                    _buildStyledCard(
                      key: _resultKey,
                      color: Colors.indigo.shade50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('è¨ˆç®—çµæžœ', Icons.assessment),
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
                                    _buildTableHeader('æ¯Žæœˆã®æ”¯æ‰•é¡'),
                                    _buildTableHeader('æ”¯æ‰•å›žæ•°'),
                                    _buildTableHeader('ç·åˆ©æ¯'),
                                    _buildTableHeader('æ”¯æ‰•ç·é¡'),
                                  ],
                                ),
                                TableRow(children: [
                                  _buildTableCell(
                                      '${formatter.format(_monthlyPayment.round())} å††'),
                                  _buildTableCell('$_totalPayments å›ž'),
                                  _buildTableCell(
                                      '${formatter.format(_totalInterest.round())} å††'),
                                  _buildTableCell(
                                      '${formatter.format(_totalAmount.round())} å††'),
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
                                    _repaymentSchedule, 'è¿”æ¸ˆè¨ˆç”»è¡¨'),
                                icon: Icon(Icons.table_chart),
                                label: Text('è¿”æ¸ˆè¨ˆç”»è¡¨'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo.shade600,
                                ),
                              ),
                              // ç„¡æ–™ãƒ¦ãƒ¼ã‚¶ãƒ¼ã«ã¯ä¿å­˜ãƒœã‚¿ãƒ³ã§ã¯ãªãèª²é‡‘èª˜å°Žãƒœã‚¿ãƒ³ã‚’è¡¨ç¤º
                              widget.appState.isPremium
                                  ? ElevatedButton.icon(
                                      onPressed: _showSaveDialog,
                                      icon: Icon(Icons.save),
                                      label: Text('ãƒ—ãƒ©ãƒ³ä¿å­˜'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade400,
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: _showPremiumPromptDialog,
                                      icon: Icon(Icons.star),
                                      label: Text('ãƒ—ãƒ¬ãƒŸã‚¢ãƒ ã¸'),
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
