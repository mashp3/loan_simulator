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
          centerTitle: true,
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

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final app_models.AppState _appState = app_models.AppState();
  final AdService _adService = AdService();
  final PurchaseService _purchaseService = PurchaseService();

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeServices();
  }

  void _initializeServices() async {
    print('🚀 アプリ初期化開始');

    // 1. まずローカルストレージからプレミアム状態を読み込み
    await _appState.loadPremiumStatus();
    print('📱 ローカルストレージのプレミアム状態: ${_appState.isPremium}');

    // デバッグモード
    if (DebugConfig.SCREENSHOT_MODE && DebugConfig.FORCE_PREMIUM) {
      _appState.isPremium = true;
      await _appState.savePremiumStatus(true);
      print('🔓 デバッグモード: プレミアム強制有効化');
    }

    // 2. 広告初期化
    if (!DebugConfig.HIDE_ADS) {
      await _adService.initialize();
    }

    // 3. 課金サービス初期化（購入履歴を自動復元）
    await _purchaseService.initialize();

    // 4. 課金サービスから現在のプレミアム状態を取得
    if (_purchaseService.isPremium && !_appState.isPremium) {
      print('✅ 課金サービスからプレミアム状態を復元');
      setState(() {
        _appState.isPremium = true;
      });
      await _appState.savePremiumStatus(true);
    }

    // 5. プレミアム状態の変更を監視
    _purchaseService.premiumStatusStream.listen((isPremium) {
      print('💫 プレミアム状態更新通知: $isPremium');

      if (mounted) {
        setState(() {
          if (!DebugConfig.FORCE_PREMIUM) {
            _appState.isPremium = isPremium;
          }
        });

        // ローカルストレージに保存
        _appState.savePremiumStatus(isPremium);

        if (isPremium) {
          print('🌟 UIを更新: プレミアム機能が有効になりました');

          // 成功メッセージを表示
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.star, color: Colors.white),
                    SizedBox(width: 8),
                    Text('プレミアム機能が有効になりました！'),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    });

    setState(() {
      _isInitialized = true;
    });

    print('✅ アプリ初期化完了 - プレミアム状態: ${_appState.isPremium}');
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (!DebugConfig.HIDE_ADS) {
      _adService.dispose();
    }
    super.dispose();
  }

  Widget _buildTabWithLock(IconData icon, String text, int tabIndex) {
    bool isLocked = !_appState.isPremium;
    return Tab(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              Text(text, style: TextStyle(fontSize: 12)),
            ],
          ),
          if (isLocked)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBannerAd() {
    if (DebugConfig.SCREENSHOT_MODE && DebugConfig.HIDE_ADS) {
      return SizedBox.shrink();
    }

    return Container(
      height: 60,
      color: Colors.grey.shade100,
      child: _adService.getBannerAdWidget(),
    );
  }

  void _showPremiumDialog() {
    _purchaseService.showPurchaseDialog(context);
  }

  void _showPremiumPurchasedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green,
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
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '✅ ご利用ありがとうございます！',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'すべてのプレミアム機能をご利用いただけます',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text('ご利用中の機能:'),
            SizedBox(height: 8),
            _buildFeatureItem('✓ 広告完全非表示'),
            _buildFeatureItem('✓ プラン比較機能(最大10件)'),
            _buildFeatureItem('✓ 詳細返済シミュレーション'),
            _buildFeatureItem('✓ ボーナス返済・繰上返済'),
            _buildFeatureItem('✓ 借入診断機能'),
            _buildFeatureItem('✓ データ保存・削除機能'),
          ],
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

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade600,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.privacy_tip, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'プライバシーポリシー',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // コンテンツ
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPrivacyPolicyContent(),
                      ],
                    ),
                  ),
                ),
                // フッター
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('閉じる'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.indigo.shade600,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // プライバシーポリシーの内容
  Widget _buildPrivacyPolicyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '開発者 mashp（以下「当方」）は、「ローンシミュレータ」（以下「本アプリ」）における利用者情報の取り扱いについて、以下のとおりプライバシーポリシー（以下「本ポリシー」）を定めます。',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        SizedBox(height: 20),
        _buildSection('1. 収集する情報', [
          '本アプリは、ローンの返済計画をシミュレーションする機能を提供するアプリです。',
        ]),
        _buildSubSection('1.1 当方が収集・保存する情報', [
          '本アプリでは、以下の情報をデバイス内にのみ保存します：',
          '• ローン計算の結果（借入金額、金利、返済期間、計算結果など）',
          '• ユーザーの設定情報',
          '• アプリ内課金の購入状態',
          '',
          'これらの情報は、お使いのデバイス内でのみ保存・処理され、外部サーバーやクラウドへ送信されることは一切ありません。',
        ]),
        _buildSection('2. 情報の使用目的', []),
        _buildSubSection('2.1 アプリ機能の提供', [
          '保存されたローン計算結果は、ユーザーが過去の計算を確認したり、計算を再利用したりするために使用されます。',
        ]),
        _buildSubSection('2.2 広告配信（無料版のみ）', [
          '広告サービスが収集した情報は、ユーザーに関連性の高い広告を表示するために使用されます。',
        ]),
        _buildSubSection('2.3 アプリの改善', [
          '匿名の統計情報を利用して、アプリの品質向上やバグ修正に役立てる場合があります。',
        ]),
        _buildSection('3. 第三者サービスについて', [
          '本アプリは、以下の第三者サービスを使用しています：',
        ]),
        _buildSubSection('3.1 広告配信サービス（無料版のみ）', [
          'Google AdMob: 広告の表示と関連する情報収集',
          '詳細: https://policies.google.com/privacy',
        ]),
        _buildSubSection('3.2 アプリ内課金サービス', [
          'Google Play Billing: プレミアムプランの購入処理',
          '詳細: https://policies.google.com/privacy',
        ]),
        _buildSection('4. 情報の開示', [
          '当方は、法令に基づく場合を除き、収集した情報を第三者に開示することはありません。',
        ]),
        _buildSection('5. データの保持', [
          'ローカルストレージに保存されたデータは、アプリをアンインストールするまで保持されます。',
        ]),
        _buildSection('6. お問い合わせ', [
          '本ポリシーに関するご質問やご意見がございましたら、Google Playストアのレビュー機能をご利用ください。',
        ]),
        _buildSection('7. ポリシーの変更', [
          '当方は、必要に応じて本ポリシーを変更する場合があります。変更時は、アプリ内で通知いたします。',
        ]),
        SizedBox(height: 16),
        Text(
          '最終更新: 2024年11月',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<String> content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade700,
          ),
        ),
        SizedBox(height: 8),
        ...content.map((text) => Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                text,
                style: TextStyle(fontSize: 14, height: 1.6),
              ),
            )),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSubSection(String title, List<String> content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.indigo.shade600,
          ),
        ),
        SizedBox(height: 6),
        ...content.map((text) => Padding(
              padding: EdgeInsets.only(
                  bottom: 4, left: text.startsWith('•') ? 0 : 0),
              child: Text(
                text,
                style: TextStyle(fontSize: 14, height: 1.6),
              ),
            )),
        SizedBox(height: 12),
      ],
    );
  }

  void _onTabTapped(int index) {
    if (!_appState.isPremium && index > 0) {
      _showPremiumDialog();
      return;
    }
    _tabController.animateTo(index);
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
            Icon(Icons.calculate, size: 28),
            SizedBox(width: 8),
            Text('ローンシミュレータ'),
          ],
        ),
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
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Icon(Icons.star, color: Colors.amber, size: 28),
                onPressed: _showPremiumPurchasedDialog,
                tooltip: 'プレミアムプラン購入済',
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: _onTabTapped,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(
              icon: Icon(Icons.calculate_rounded, size: 24),
              text: '基本計算',
            ),
            _buildTabWithLock(Icons.compare_arrows_rounded, 'プラン比較', 1),
            _buildTabWithLock(Icons.tune, '詳細返済', 2),
            _buildTabWithLock(Icons.psychology, '借入診断', 3),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade50, Colors.white, Colors.grey.shade50],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            if (!_appState.isPremium) _buildBannerAd(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  LoanCalculatorScreen(
                      appState: _appState, adService: _adService),
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
      ),
    );
  }

  Widget _buildLockedScreen(String featureName) {
    return Container(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock,
              size: 64,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 24),
          Text(
            '$featureName機能',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'この機能はプレミアムプラン限定です',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showPremiumDialog,
            icon: Icon(Icons.star),
            label: Text('プレミアムにアップグレード'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
