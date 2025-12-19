import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static AdService? _instance;

  factory AdService() {
    _instance ??= AdService._internal();
    return _instance!;
  }

  AdService._internal();

  BannerAd? _bannerAd;
  Widget? _cachedAdWidget; // 【追加】キャッシュされたウィジェット
  bool _isAdLoaded = false;
  bool _isLoading = false;
  bool _hasFailedToLoad = false;

  // バナー広告ID設定（テスト用IDを使用、本番では実際のIDに変更）
  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3299689382637796/6764277294'; // 本番用Android広告ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3299689382637796/1229694872'; // 本番用iOS広告ID
    }
    return '';
  }

  // 広告サービス初期化（バナー広告のみ）
  Future<void> initialize() async {
    print('📱 広告サービス初期化開始');
    await _loadBannerAd();
  }

  // バナー広告の読み込み
  Future<void> _loadBannerAd() async {
    if (_isLoading) {
      print('⚠️ 既に広告読み込み中のためスキップ');
      return;
    }
    
    _isLoading = true;
    print('🔄 バナー広告読み込み開始');

    try {
      // 既存の広告とキャッシュをクリア
      _disposeBannerAd();
      
      _bannerAd = BannerAd(
        adUnitId: bannerAdUnitId,
        size: AdSize.banner,
        request: AdRequest(
          keywords: ['金融', 'ローン', '住宅ローン', '銀行', '融資', '金利'],
        ),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            print('✅ バナー広告が読み込まれました');
            _isAdLoaded = true;
            _isLoading = false;
            _hasFailedToLoad = false;
            _createCachedWidget(); // 【重要】キャッシュ作成
          },
          onAdFailedToLoad: (ad, error) {
            print('❌ バナー広告の読み込みに失敗しました: $error');
            ad.dispose();
            _bannerAd = null;
            _isAdLoaded = false;
            _isLoading = false;
            _hasFailedToLoad = true;
            _cachedAdWidget = null;
          },
          onAdOpened: (ad) {
            print('📱 広告がタップされました');
          },
        ),
      );

      await _bannerAd?.load();
    } catch (e) {
      print('❌ 広告初期化エラー: $e');
      _isAdLoaded = false;
      _isLoading = false;
      _hasFailedToLoad = true;
      _cachedAdWidget = null;
    }
  }

  // 【新規】キャッシュされたウィジェット作成
  void _createCachedWidget() {
    if (_bannerAd != null && _isAdLoaded) {
      print('🎯 広告ウィジェットをキャッシュ作成');
      _cachedAdWidget = Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
  }

  // 【修正】バナー広告ウィジェットを取得 - 重複防止版
  Widget getBannerAdWidget() {
    // 【重要】キャッシュされたウィジェットがある場合はそれを返す
    if (_cachedAdWidget != null) {
      print('✅ キャッシュされた広告ウィジェットを返却');
      return _cachedAdWidget!;
    }

    // 読み込み中の場合
    if (_isLoading) {
      print('⏳ 広告読み込み中 - 空のコンテナを返却');
      return Container(height: 0);
    }

    // 【TestFlight/開発環境用】読み込み失敗時はフォールバック広告
    if (_hasFailedToLoad) {
      print('🔄 広告読み込み失敗 - フォールバック広告を表示');
      return _buildFinancialAdWidget();
    }

    // デフォルト
    print('📭 広告なし - 空のコンテナを返却');
    return Container(height: 0);
  }

  // 金融機関の広告風ウィジェット（フォールバック用）
  Widget _buildFinancialAdWidget() {
    final List<Map<String, dynamic>> financialAds = [
      {
        'bank': 'みずほ銀行',
        'rate': '0.375%',
        'color': Colors.blue,
        'message': '住宅ローン金利キャンペーン実施中',
      },
      {
        'bank': '三菱UFJ銀行',
        'rate': '0.345%',
        'color': Colors.red,
        'message': '金利優遇プラン新登場',
      },
      {
        'bank': '三井住友銀行',
        'rate': '0.39%',
        'color': Colors.green,
        'message': 'ネット申込で金利優遇',
      },
    ];

    // TestFlightでの一貫性のため固定広告を表示
    final ad = financialAds[0]; // 常にみずほ銀行

    return Container(
      height: 50, // AdMobバナーと同じ高さ
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ad['color'].withOpacity(0.1), Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ad['color'].withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ad['color'],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.account_balance, color: Colors.white, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  ad['bank'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: ad['color'],
                  ),
                ),
                Text(
                  ad['message'],
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: ad['color'],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '年${ad['rate']}〜',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 【新規】バナー広告の破棄
  void _disposeBannerAd() {
    if (_bannerAd != null) {
      print('🗑️ 既存の広告を破棄');
      _bannerAd!.dispose();
      _bannerAd = null;
    }
    _cachedAdWidget = null;
    _isAdLoaded = false;
  }

  // 広告の再読み込み（必要に応じて）
  Future<void> reloadAd() async {
    print('🔄 広告の再読み込み開始');
    _disposeBannerAd();
    _isLoading = false;
    _hasFailedToLoad = false;
    await _loadBannerAd();
  }

  // リソースの解放
  void dispose() {
    print('🧹 AdService リソースを解放');
    _disposeBannerAd();
    _isLoading = false;
    _hasFailedToLoad = false;
  }
}
