import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  static PurchaseService? _instance;

  factory PurchaseService() {
    _instance ??= PurchaseService._internal();
    return _instance!;
  }

  PurchaseService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final StreamController<bool> _premiumStatusController =
      StreamController<bool>.broadcast();

  // プレミアムプランのプロダクトID(230円)
  static const String premiumProductId = 'premium_plan_230yen';

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Stream<bool> get premiumStatusStream => _premiumStatusController.stream;

  // 課金サービス初期化
  Future<void> initialize() async {
    print('📱 課金サービス初期化開始');

    // 1. まずローカルストレージから状態を読み込み
    await _loadLocalPremiumStatus();

    // 2. 購入状態の監視を開始
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _handlePurchaseUpdates,
      onDone: () {
        print('📱 購入ストリーム終了');
      },
      onError: (error) {
        print('❌ 課金エラー: $error');
      },
    );

    // 3. 過去の購入を復元(重要!)
    await _restorePurchases();

    print('✅ 課金サービス初期化完了 - プレミアム状態: $_isPremium');
  }

  // ローカルストレージからプレミアム状態を読み込み
  Future<void> _loadLocalPremiumStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool localPremium = prefs.getBool('is_premium') ?? false;

      if (localPremium) {
        _isPremium = localPremium;
        _premiumStatusController.add(_isPremium);
        print('✅ ローカルストレージからプレミアム状態を復元: $_isPremium');
      } else {
        print('📱 ローカルストレージ: プレミアム状態なし');
      }
    } catch (error) {
      print('❌ ローカル状態読み込みエラー: $error');
    }
  }

  // 購入状態の更新処理
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    print('📱 購入更新を受信: ${purchaseDetailsList.length}件');

    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      print(
          '📱 購入詳細: ${purchaseDetails.productID}, 状態: ${purchaseDetails.status}');
      _handlePurchase(purchaseDetails);
    }
  }

  // 個別の購入処理
  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    print('📱 購入処理開始: ${purchaseDetails.productID}');

    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      print('✅ 購入/復元成功: ${purchaseDetails.productID}');

      if (purchaseDetails.productID == premiumProductId) {
        // プレミアムプランの購入/復元成功
        await _setPremiumStatus(true);
        print('🎊 プレミアムプラン有効化完了');
      }

      // 購入完了処理(重要!)
      if (purchaseDetails.pendingCompletePurchase) {
        print('📱 購入完了処理を実行');
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      print('❌ 購入エラー: ${purchaseDetails.error?.message}');
      print('❌ エラーコード: ${purchaseDetails.error?.code}');
    } else if (purchaseDetails.status == PurchaseStatus.pending) {
      print('⏳ 購入処理中...');
    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      print('🚫 購入キャンセル');
    }
  }

  // プレミアム状態の設定
  Future<void> _setPremiumStatus(bool premium) async {
    print('📱 プレミアム状態を設定: $premium');

    _isPremium = premium;
    _premiumStatusController.add(_isPremium);

    // ローカルストレージに保存(重要!)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', premium);

      // 保存確認
      await Future.delayed(Duration(milliseconds: 100));
      bool saved = prefs.getBool('is_premium') ?? false;
      print('✅ プレミアム状態をローカルに保存完了: $saved');

      if (saved != premium) {
        print('⚠️ 警告: 保存に失敗した可能性があります');
        // 再試行
        await prefs.setBool('is_premium', premium);
        print('🔄 再保存を実行しました');
      }
    } catch (error) {
      print('❌ ローカル保存エラー: $error');
    }

    if (premium) {
      print('🎊🎊🎊 プレミアム機能が有効になりました 🎊🎊🎊');
    }
  }

  // 過去の購入を復元
  Future<void> _restorePurchases() async {
    print('📱 購入履歴の復元を開始');

    try {
      // ストアから購入履歴を復元
      await _inAppPurchase.restorePurchases();
      print('✅ 購入履歴の復元完了');

      // 少し待ってから状態を確認
      await Future.delayed(Duration(seconds: 2));
    } catch (error) {
      print('❌ 購入復元エラー: $error');
    }
  }

  // プレミアムプランの購入
  Future<bool> purchasePremium() async {
    print('📱 プレミアム購入処理開始');

    try {
      // 既に購入済みの場合は購入させない
      if (_isPremium) {
        print('✅ 既にプレミアムプランを購入済みです');
        return true;
      }

      final bool available = await _inAppPurchase.isAvailable();
      print('📱 課金可能: $available');

      if (!available) {
        print('❌ アプリ内課金が利用できません');
        return false;
      }

      // プロダクト情報を取得
      print('📱 プロダクト情報を取得中: $premiumProductId');
      const Set<String> kIds = <String>{premiumProductId};
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(kIds);

      if (response.notFoundIDs.isNotEmpty) {
        print('❌ プロダクトが見つかりません: ${response.notFoundIDs}');
        print('💡 Google Play Consoleでプロダクトが正しく設定されているか確認してください');
        return false;
      }

      if (response.productDetails.isEmpty) {
        print('❌ プロダクト詳細が取得できません');
        return false;
      }

      final ProductDetails productDetails = response.productDetails.first;
      print('✅ プロダクト取得成功: ${productDetails.title} - ${productDetails.price}');

      // 購入リクエスト作成
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      print('📱 購入リクエストを送信中...');

      // 購入開始
      bool result = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      print('📱 購入リクエスト結果: $result');

      // 購入処理が完了するまで待つ
      if (result) {
        print('⏳ 購入処理の完了を待機中...');

        // 最大10秒待機して状態を確認
        for (int i = 0; i < 10; i++) {
          await Future.delayed(Duration(seconds: 1));
          if (_isPremium) {
            print('✅ プレミアム状態が有効になりました!');
            return true;
          }
        }

        print('⚠️⚠️ タイムアウト: プレミアム状態の確認中');
      }

      return result;
    } catch (error) {
      print('❌ 購入エラー: $error');
      return false;
    }
  }

  // 購入復元
  Future<void> restorePurchases() async {
    print('📱 購入復元開始');
    await _restorePurchases();
  }

  // プロダクト詳細を取得
  Future<ProductDetails?> getProductDetails() async {
    try {
      const Set<String> kIds = <String>{premiumProductId};
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(kIds);

      if (response.productDetails.isNotEmpty) {
        print('✅ プロダクト詳細取得成功');
        return response.productDetails.first;
      } else {
        print('⚠️ プロダクト詳細が空です');
      }
    } catch (error) {
      print('❌ プロダクト詳細取得エラー: $error');
    }
    return null;
  }

  // 購入ダイアログを表示
  Future<void> showPurchaseDialog(BuildContext context) async {
    final ProductDetails? productDetails = await getProductDetails();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isPremium ? Colors.green : Colors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isPremium ? Icons.check_circle : Icons.star,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(_isPremium ? 'プレミアム会員' : 'プレミアムプラン'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isPremium) ...[
              // 既に購入済みの場合
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.verified, color: Colors.green.shade600, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'プレミアムプラン購入済み',
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
            ] else ...[
              // 未購入の場合
              Text('プレミアムプランの特典:'),
              SizedBox(height: 12),
            ],
            _buildFeatureItem('✓ 広告完全非表示'),
            _buildFeatureItem('✓ プラン比較機能(最大10件)'),
            _buildFeatureItem('✓ 詳細返済シミュレーション'),
            _buildFeatureItem('✓ ボーナス返済・繰上げ返済'),
            _buildFeatureItem('✓ データ保存・削除機能'),
            if (!_isPremium) ...[
              SizedBox(height: 16),
              if (productDetails != null)
                Center(
                  child: Text(
                    productDetails.price,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
                  ),
                )
              else
                Center(
                  child: Text(
                    '¥230',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
              Center(
                child: Text(
                  '(買い切り)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_isPremium ? '閉じる' : 'キャンセル'),
          ),
          if (!_isPremium)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);

              // ローディング表示
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => Center(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('購入処理中...'),
                      ],
                    ),
                  ),
                ),
              );

              // 購入処理
              bool success = await purchasePremium();

              // ローディング閉じる
              Navigator.pop(context);

              // 結果表示
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.star, color: Colors.white),
                        SizedBox(width: 8),
                        Text('プレミアムプランが有効になりました!'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.white),
                        SizedBox(width: 8),
                        Text('購入に失敗しました'),
                      ],
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            icon: Icon(Icons.shopping_cart),
            label: Text('購入する'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(text, style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // リソースの解放
  void dispose() {
    _subscription.cancel();
    _premiumStatusController.close();
  }
}
