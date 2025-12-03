import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'screens/loan_calculator_screen.dart';
import 'screens/comparison_screen.dart';
import 'screens/detailed_payment_screen.dart';
import 'screens/reverse_calculation_screen.dart';
import 'services/ad_service.dart';
import 'services/purchase_service.dart';
import 'models/app_state.dart' as app_models;

// ==========================================
// 📸 ストア掲載用デバッグモード設定
// ==========================================
class DebugConfig {
  static const bool SCREENSHOT_MODE = false;
  static const bool FORCE_PREMIUM = false;
  static const bool HIDE_ADS = false;
}
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!DebugConfig.HIDE_ADS) {
    await MobileAds.instance.initialize();
  }

  InAppPurchase.instance.isAvailable();

  runApp(LoanSimulatorApp());
}

class LoanSimulatorApp extends StatelessWidget {
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
          centerTitle: false, // ボトムナビ版では左寄せ
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
  final PurchaseService _purchaseService = PurchaseService();

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
    _adService.dispose();
    _purchaseService.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // アプリ状態の初期化
      await _appState.loadPremiumStatus();
      await _appState.loadSavedData();
      
      // デバッグモード設定
      if (DebugConfig.FORCE_PREMIUM) {
        _appState.isPremium = true;
      }

      // 広告とプレミアム機能の初期化
      if (!DebugConfig.HIDE_ADS && !_appState.isPremium) {
        await _adService.initialize();
      }

      await _purchaseService.initialize();
      
      // プレミアム状態の監視
      _purchaseService.premiumStatusStream.listen((isPremium) {
        setState(() {
          _appState.isPremium = isPremium;
        });
      });

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _onTabTapped(int index) {
    if (!_appState.isPremium && index > 0) {
      _showPremiumDialog();
      return;
    }
    
    setState(() {
      _currentIndex = index;
    });
    
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showPremiumDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.star, color: Colors.white, size: 24),
              ),
              SizedBox(width: 12),
              Text('プレミアム機能'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'この機能をご利用いただくには、プレミアム版（¥230）の購入が必要です。',
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
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _buildFeatureText('✓ プラン比較機能'),
                    _buildFeatureText('✓ 詳細返済シミュレーション'),
                    _buildFeatureText('✓ 借入診断機能'),
                    _buildFeatureText('✓ 返済スケジュール表示・CSV出力'),
                    _buildFeatureText('✓ 広告非表示'),
                    _buildFeatureText('✓ データ保存機能（最大10件）'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('後で'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await _purchaseService.purchasePremium();
              },
              icon: Icon(Icons.star, size: 20),
              label: Text('¥230で購入'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeatureText(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildBannerAd() {
    if (DebugConfig.HIDE_ADS || _appState.isPremium) {
      return Container();
    }

    return _adService.getBannerAdWidget();
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('プライバシーポリシー'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPrivacyText('個人情報の取り扱いについて'),
              _buildPrivacyText('当アプリは、ユーザーの個人情報を適切に保護し、以下のポリシーに従って取り扱います。'),
              _buildPrivacyText('収集する情報'),
              _buildPrivacyText('• アプリの使用状況に関する匿名データ'),
              _buildPrivacyText('• 広告配信のための匿名識別子'),
              _buildPrivacyText('• アプリ内購入の取引情報'),
              _buildPrivacyText('情報の使用目的'),
              _buildPrivacyText('• アプリの機能向上'),
              _buildPrivacyText('• 広告の最適化'),
              _buildPrivacyText('• サポート対応'),
              _buildPrivacyText('第三者への提供'),
              _buildPrivacyText('法令に基づく場合を除き、ユーザーの同意なく第三者に個人情報を提供することはありません。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyText(String text) {
    return Column(
      children: [
        Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.only(
                left: text.startsWith('•') ? 16 : 0,
                top: text.endsWith('について') || text.endsWith('目的') || text.endsWith('提供') ? 16 : 0),
            child: Text(
              text,
              style: TextStyle(fontSize: 14, height: 1.6),
            )),
        SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 初期化中はローディング表示
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
          // 情報アイコン（プライバシーポリシー）
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showPrivacyPolicy,
            tooltip: 'プライバシーポリシー',
          ),
          if (!DebugConfig.SCREENSHOT_MODE) ...[
            if (!_appState.isPremium)
              Container(
                margin: EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: _showPremiumDialog,
                  icon: Icon(Icons.star, size: 20),
                  label: Text('Premium'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
          ],
          if (_appState.isPremium)
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
      body: Column(
        children: [
          if (!_appState.isPremium) _buildBannerAd(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              children: [
                LoanCalculatorScreen(appState: _appState, adService: _adService),
                _appState.isPremium
                    ? ComparisonScreen(appState: _appState)
                    : _buildLockedScreen('プラン比較'),
                _appState.isPremium
                    ? DetailedPaymentScreen(appState: _appState)
                    : _buildLockedScreen('詳細返済'),
                _appState.isPremium
                    ? ReverseCalculationScreen(appState: _appState)
                    : _buildLockedScreen('借入診断'),
              ],
            ),
          ),
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
              icon: _buildTabIconWithLock(Icons.compare, 1),
              activeIcon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildTabIconWithLock(Icons.compare, 1, isActive: true),
              ),
              label: 'プラン比較',
            ),
            BottomNavigationBarItem(
              icon: _buildTabIconWithLock(Icons.timeline, 2),
              activeIcon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildTabIconWithLock(Icons.timeline, 2, isActive: true),
              ),
              label: '詳細返済',
            ),
            BottomNavigationBarItem(
              icon: _buildTabIconWithLock(Icons.search, 3),
              activeIcon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildTabIconWithLock(Icons.search, 3, isActive: true),
              ),
              label: '借入診断',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabIconWithLock(IconData iconData, int tabIndex, {bool isActive = false}) {
    if (_appState.isPremium) {
      return Icon(
        iconData, 
        color: isActive ? Colors.indigo.shade600 : null,
      );
    } else {
      return Stack(
        children: [
          Icon(
            iconData,
            color: Colors.grey.shade400,
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.amber.shade600,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.lock,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildLockedScreen(String featureName) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.indigo.shade50, Colors.white, Colors.grey.shade50],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.lock,
                size: 64,
                color: Colors.amber.shade600,
              ),
            ),
            SizedBox(height: 24),
            Text(
              '$featureName機能',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade700,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'この機能はプレミアム版でご利用いただけます',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showPremiumDialog,
              icon: Icon(Icons.star, size: 24),
              label: Text(
                '¥230でプレミアム版を購入',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
