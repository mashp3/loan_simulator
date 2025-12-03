import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ローンデータモデル
class LoanData {
  String title;
  DateTime savedDate;
  double loanAmount;
  double interestRate;
  int years;
  int months;
  String repaymentMethod;
  double monthlyPayment;
  int totalPayments;
  double totalInterest;
  double totalAmount;
  List<List<String>> schedule;

  // ボーナス返済関連フィールド
  bool enableBonusPayment;
  double bonusAmount;
  List<int> bonusMonths;

  LoanData({
    required this.title,
    required this.savedDate,
    required this.loanAmount,
    required this.interestRate,
    required this.years,
    required this.months,
    required this.repaymentMethod,
    required this.monthlyPayment,
    required this.totalPayments,
    required this.totalInterest,
    required this.totalAmount,
    required this.schedule,
    this.enableBonusPayment = false,
    this.bonusAmount = 0,
    this.bonusMonths = const [6, 12],
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'savedDate': savedDate.toIso8601String(),
      'loanAmount': loanAmount,
      'interestRate': interestRate,
      'years': years,
      'months': months,
      'repaymentMethod': repaymentMethod,
      'monthlyPayment': monthlyPayment,
      'totalPayments': totalPayments,
      'totalInterest': totalInterest,
      'totalAmount': totalAmount,
      'schedule': schedule,
      'enableBonusPayment': enableBonusPayment,
      'bonusAmount': bonusAmount,
      'bonusMonths': bonusMonths,
    };
  }

  factory LoanData.fromJson(Map<String, dynamic> json) {
    return LoanData(
      title: json['title'],
      savedDate: DateTime.parse(json['savedDate']),
      loanAmount: json['loanAmount'],
      interestRate: json['interestRate'],
      years: json['years'],
      months: json['months'],
      repaymentMethod: json['repaymentMethod'],
      monthlyPayment: json['monthlyPayment'],
      totalPayments: json['totalPayments'],
      totalInterest: json['totalInterest'],
      totalAmount: json['totalAmount'],
      schedule: List<List<String>>.from(
          json['schedule'].map((x) => List<String>.from(x))),
      enableBonusPayment: json['enableBonusPayment'] ?? false,
      bonusAmount: json['bonusAmount'] ?? 0,
      bonusMonths: json['bonusMonths'] != null
          ? List<int>.from(json['bonusMonths'])
          : [6, 12],
    );
  }
}

// アプリケーション状態管理クラス
class AppState {
  bool isPremium = false;
  List<LoanData> savedLoanData = [];

  // プレミアム状態の読み込み
  Future<void> loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    isPremium = prefs.getBool('is_premium') ?? false;
  }

  // プレミアム状態の保存
  Future<void> savePremiumStatus(bool premium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', premium);
    isPremium = premium;
  }

  // 保存されたローンデータの読み込み
  Future<void> loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDataJson = prefs.getStringList('loan_data') ?? [];

    savedLoanData = savedDataJson
        .map((json) => LoanData.fromJson(jsonDecode(json)))
        .toList();
  }

  // ローンデータの保存
  Future<void> saveLoanData(LoanData loanData) async {
    savedLoanData.add(loanData);

    // 最大5件まで保存（プレミアムは制限なし、無料版は3件）
    int maxSaves = isPremium ? 10 : 3;
    if (savedLoanData.length > maxSaves) {
      savedLoanData.removeAt(0);
    }

    final prefs = await SharedPreferences.getInstance();
    final savedDataJson =
        savedLoanData.map((data) => jsonEncode(data.toJson())).toList();
    await prefs.setStringList('loan_data', savedDataJson);
  }

  // ローンデータの削除
  Future<void> deleteLoanData(int index) async {
    if (index >= 0 && index < savedLoanData.length) {
      savedLoanData.removeAt(index);

      final prefs = await SharedPreferences.getInstance();
      final savedDataJson =
          savedLoanData.map((data) => jsonEncode(data.toJson())).toList();
      await prefs.setStringList('loan_data', savedDataJson);
    }
  }

  // 全ローンデータの削除
  Future<void> clearAllLoanData() async {
    savedLoanData.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loan_data');
  }

  // 最安利息のインデックスを取得
  int getBestInterestIndex() {
    if (savedLoanData.isEmpty) return -1;
    double minInterest = savedLoanData[0].totalInterest;
    int bestIndex = 0;
    for (int i = 1; i < savedLoanData.length; i++) {
      if (savedLoanData[i].totalInterest < minInterest) {
        minInterest = savedLoanData[i].totalInterest;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  // 最安月額のインデックスを取得
  int getBestMonthlyPaymentIndex() {
    if (savedLoanData.isEmpty) return -1;
    double minAmount = savedLoanData[0].monthlyPayment;
    int bestIndex = 0;
    for (int i = 1; i < savedLoanData.length; i++) {
      if (savedLoanData[i].monthlyPayment < minAmount) {
        minAmount = savedLoanData[i].monthlyPayment;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}
