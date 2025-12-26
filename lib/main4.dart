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
                await _handlePremiumPurchase();
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

  Future<void> _handleRestorePurchases() async {
    // ローディングダイアログを表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('購入履歴を確認中...'),
          ],
        ),
      ),
    );

    try {
      // 購入履歴を復元
      bool restored = await _purchaseService.restorePurchases();
      
      // ローディングダイアログを閉じる
      Navigator.of(context).pop();
      
      // 結果に応じてメッセージを表示
      if (restored) {
        setState(() {
          // プレミアム状態を更新
          _appState.isPremium = true;
        });
        await _appState.savePremiumStatus(true);
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('復元可能な購入履歴が見つかりませんでした'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      // ローディングダイアログを閉じる
      Navigator.of(context).pop();
      
      // エラーメッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('復元中にエラーが発生しました: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _handlePremiumPurchase() async {
    // ローディングダイアログを表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('購入処理中...'),
          ],
        ),
      ),
    );

    try {
      // プレミアム購入を実行
      bool purchaseSuccess = await _purchaseService.purchasePremium();
      
      // ローディングダイアログを閉じる
      Navigator.of(context).pop();
      
      if (purchaseSuccess) {
        // 購入成功
        setState(() {
          _appState.isPremium = true;
        });
        await _appState.savePremiumStatus(true);
        
        _showSuccessDialog();
      } else {
        // 購入失敗
        _showErrorDialog('購入処理に失敗しました。\n\n考えられる原因：\n• ネットワーク接続の問題\n• Google Playの一時的な問題\n• プロダクト設定の問題\n\n時間をおいて再度お試しください。');
      }
    } catch (e) {
      // ローディングダイアログを閉じる
      Navigator.of(context).pop();
      
      // エラー処理
      _showErrorDialog('購入処理中にエラーが発生しました：\n\n$e\n\n開発者にお問い合わせください。');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_circle, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
            Text('購入完了！'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'プレミアム版をご購入いただき、ありがとうございます！',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade600, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '利用可能になった機能',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('• プラン比較機能'),
                  Text('• 詳細返済シミュレーション'),
                  Text('• 借入診断機能'),
                  Text('• 返済スケジュール表示'),
                  Text('• 広告非表示'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.star, size: 20),
            label: Text('プレミアム機能を使う'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.error, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
            Text('購入エラー'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('閉じる'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _handlePremiumPurchase(); // 再試行
            },
            icon: Icon(Icons.refresh, size: 18),
            label: Text('再試行'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
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

  // 【重要】広告表示 - main.dartでのみ一元管理
  Widget _buildBannerAd() {
    // プレミアムユーザーまたは広告非表示設定の場合
    if (DebugConfig.HIDE_ADS || _appState.isPremium) {
      return Container();
    }

    // 広告サービスから単一のキャッシュされたウィジェットを取得
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
        // タイトルを完全表示できるよう最適化
        title: Text(
          'ローンシミュレータ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: MediaQuery.of(context).size.width < 375 ? 16 : 18,
          ),
        ),
        // 左側の計算アイコン
        leading: Container(
          margin: EdgeInsets.all(8),
          child: Icon(
            Icons.calculate, 
            color: Colors.white, 
            size: MediaQuery.of(context).size.width < 375 ? 20 : 24,
          ),
        ),
        backgroundColor: Colors.indigo.shade600,
        elevation: 0,
        centerTitle: false,
        // 必要最小限のボタンのみ
        actions: [
          // 情報アイコン（プライバシーポリシー）
          IconButton(
            icon: Icon(Icons.info_outline, size: 22),
            onPressed: _showPrivacyPolicy,
            tooltip: 'プライバシーポリシー',
          ),
          // 復元ボタン（プレミアム未購入時のみ表示）
          if (!_appState.isPremium)
            IconButton(
              icon: Icon(Icons.restore, size: 22),
              onPressed: _handleRestorePurchases,
              tooltip: '購入履歴を復元',
            ),
          // 【修正】プレミアム状態表示 - スターのみの円形ボタン
          if (_appState.isPremium)
            Container(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.amber.shade600,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.star, 
                color: Colors.white, 
                size: 20,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 【重要】広告は main.dart で一箇所のみ表示
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
                // 【重要】LoanCalculatorScreenにはadServiceを渡さない（重複防止）
                LoanCalculatorScreen(appState: _appState),
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
            fontSize: MediaQuery.of(context).size.width < 375 ? 10 : 12,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: MediaQuery.of(context).size.width < 375 ? 9 : 11,
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
              '${featureName}機能',
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
