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

  // バナー広告ID設定（テスト用IDを使用、本番では実際のIDに変更）
  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3299689382637796/6764277294'; // テスト用ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3299689382637796/1229694872'; // 本番用iOS広告ID
    }
    return '';
  }

  // 広告サービス初期化（バナー広告のみ）
  Future<void> initialize() async {
    await _loadBannerAd();
  }

  // バナー広告の読み込み
  Future<void> _loadBannerAd() async {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: AdRequest(
        keywords: ['金融', 'ローン', '住宅ローン', '銀行', '融資', '金利'],
      ),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('バナー広告が読み込まれました');
        },
        onAdFailedToLoad: (ad, error) {
          print('バナー広告の読み込みに失敗しました: $error');
          ad.dispose();
          _bannerAd = null;
        },
      ),
    );

    await _bannerAd?.load();
  }

  // バナー広告ウィジェットを取得
  Widget getBannerAdWidget() {
    if (_bannerAd == null) {
      return _buildFinancialAdWidget();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
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

    final ad = financialAds[DateTime.now().millisecond % financialAds.length];

    return Container(
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
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ad['color'],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.account_balance, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ad['bank'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: ad['color'],
                  ),
                ),
                Text(
                  ad['message'],
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ad['color'],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '年${ad['rate']}〜',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // リソースの解放
  void dispose() {
    _bannerAd?.dispose();
  }
}
