import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/loan_calculator_screen.dart';
import 'screens/comparison_screen.dart';
import 'screens/detailed_payment_screen.dart';
import 'screens/reverse_calculation_screen.dart';
import 'models/app_state.dart' as app_models;
import 'services/ad_service.dart';

// ==========================================
// 📸 スクリーンショット撮影用デモ版
// ==========================================
// このバージョンでは:
// - プレミアム機能が常時有効
// - 広告非表示
// - サンプルデータ付き
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(LoanSimulatorDemoApp());
}

class LoanSimulatorDemoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ローンシミュレータ',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        primaryColor: Colors.indigo.shade600,
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            elevation: 8,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            shadowColor: Colors.indigo.withOpacity(0.3),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 12,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: false,
      checkerboardRasterCacheImages: false,
      checkerboardOffscreenLayers: false,
      showSemanticsDebugger: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final app_models.AppState _appState = app_models.AppState();
  final AdService _adService = AdService();

  bool _isInitialized = false;
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeApp();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      await _appState.loadPremiumStatus();
      await _appState.loadSavedData();
      
      // デモ版ではプレミアム機能を常時有効化
      _appState.isPremium = true;

      // サンプルデータの生成
      _generateSampleData();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _generateSampleData() {
    final now = DateTime.now();
    
    final sampleSchedule = [
      ['回数', '残高', '元金', '利息', '返済額'],
      ['1', '34,900,000', '100,000', '37,917', '137,917'],
      ['2', '34,799,892', '100,108', '37,809', '137,917'],
      ['3', '34,699,676', '100,216', '37,701', '137,917'],
    ];

    final sampleData = [
      app_models.LoanData(
        title: 'マイホームローン（フラット35）',
        savedDate: now.subtract(Duration(days: 1)),
        loanAmount: 35000000,
        interestRate: 1.3,
        years: 35,
        months: 0,
        repaymentMethod: '元利均等',
        monthlyPayment: 137917,
        totalPayments: 420,
        totalInterest: 7924140,
        totalAmount: 42924140,
        schedule: sampleSchedule,
        enableBonusPayment: true,
        bonusAmount: 200000,
        bonusMonths: [6, 12],
      ),
      app_models.LoanData(
        title: 'マンション購入ローン',
        savedDate: now.subtract(Duration(days: 2)),
        loanAmount: 28000000,
        interestRate: 0.8,
        years: 30,
        months: 0,
        repaymentMethod: '元金均等',
        monthlyPayment: 111853,
        totalPayments: 360,
        totalInterest: 3366800,
        totalAmount: 31366800,
        schedule: sampleSchedule,
        enableBonusPayment: false,
        bonusAmount: 0,
        bonusMonths: [6, 12],
      ),
      app_models.LoanData(
        title: '借り換えローン',
        savedDate: now.subtract(Duration(days: 3)),
        loanAmount: 22000000,
        interestRate: 0.6,
        years: 25,
        months: 6,
        repaymentMethod: '元利均等',
        monthlyPayment: 72845,
        totalPayments: 306,
        totalInterest: 2290770,
        totalAmount: 24290770,
        schedule: sampleSchedule,
        enableBonusPayment: true,
        bonusAmount: 150000,
        bonusMonths: [6, 12],
      ),
    ];

    _appState.savedLoanData.addAll(sampleData);
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('初期化中...'),
              ],
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
        showPerformanceOverlay: false,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.calculate, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text(
              'ローンシミュレータ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.indigo.shade600,
        elevation: 0,
        centerTitle: false,
        actions: [
          // プレミアムバッジ（常に表示）
          Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade600,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  'プレミアム',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          LoanCalculatorScreen(
            appState: _appState,
            adService: _adService,
          ),
          ComparisonScreen(appState: _appState),
          DetailedPaymentScreen(appState: _appState),
          ReverseCalculationScreen(appState: _appState),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          selectedItemColor: Colors.indigo.shade600,
          unselectedItemColor: Colors.grey.shade600,
          backgroundColor: Colors.white,
          elevation: 8,
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 11,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.calculate),
              activeIcon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.calculate, color: Colors.indigo.shade600),
              ),
              label: 'ローン計算',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.compare),
              activeIcon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.compare, color: Colors.indigo.shade600),
              ),
              label: 'プラン比較',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timeline),
              activeIcon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timeline, color: Colors.indigo.shade600),
              ),
              label: '詳細返済',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              activeIcon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.search, color: Colors.indigo.shade600),
              ),
              label: '借入診断',
            ),
          ],
        ),
      ),
    );
  }
}
