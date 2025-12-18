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
  bool _isAdLoaded = false;

  // 【修正】バナー広告ID設定 - 本番用IDに変更
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
    print('📱 広告サービスを初期化中...');
    await _loadBannerAd();
  }

  // バナー広告の読み込み
  Future<void> _loadBannerAd() async {
    try {
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
          },
          onAdFailedToLoad: (ad, error) {
            print('❌ バナー広告の読み込みに失敗しました: $error');
            ad.dispose();
            _bannerAd = null;
            _isAdLoaded = false;
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
    }
  }

  // 【修正】バナー広告ウィジェットを取得 - 重複表示を防止
  Widget getBannerAdWidget() {
    // 実際の広告が読み込まれている場合のみ表示
    if (_bannerAd != null && _isAdLoaded) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // フォールバック：広告が読み込めない場合は何も表示しない
    // または最低限のプレースホルダー
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Text(
          '広告読み込み中...',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // 【削除】デモ用金融広告を削除して重複を防止
  // _buildFinancialAdWidget() メソッドを完全に削除

  // 広告の再読み込み（必要に応じて）
  Future<void> reloadAd() async {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
    await _loadBannerAd();
  }

  // リソースの解放
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
  }
}
