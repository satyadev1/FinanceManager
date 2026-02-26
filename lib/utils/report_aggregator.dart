import '../models/transaction.dart';
import '../models/account.dart';

/// Result row for reports: label (account or period) and amount.
class ReportRow {
  final String label;
  final double amount;
  final double? percentOfTotal;
  final String? accountId;

  const ReportRow({required this.label, required this.amount, this.percentOfTotal, this.accountId});
}

/// Totals for a period.
class ReportTotals {
  final double totalDebits;
  final double totalCredits;
  final List<ReportRow> byAccount;

  const ReportTotals({
    required this.totalDebits,
    required this.totalCredits,
    required this.byAccount,
  });
}

/// Filter params for reports.
class ReportFilter {
  final DateTime start;
  final DateTime end;
  final Set<String?> accountIds; // empty = all
  final String typeFilter; // 'debit', 'credit', 'both'

  const ReportFilter({
    required this.start,
    required this.end,
    this.accountIds = const {},
    this.typeFilter = 'both',
  });
}

/// Aggregates transactions into report rows and totals.
ReportTotals aggregateReport({
  required List<Transaction> transactions,
  required List<Account> accounts,
  required ReportFilter filter,
}) {
  final inRange = transactions.where((t) {
    final d = t.date;
    if (d.isBefore(filter.start) || d.isAfter(filter.end)) return false;
    if (filter.accountIds.isNotEmpty && !filter.accountIds.contains(t.accountId)) return false;
    if (filter.typeFilter == 'debit' && t.type != 'debit') return false;
    if (filter.typeFilter == 'credit' && t.type != 'credit') return false;
    return true;
  }).toList();

  double totalDebits = 0;
  double totalCredits = 0;
  final byAccount = <String, double>{};

  for (final t in inRange) {
    final amt = t.amount;
    if (t.type == 'debit') {
      totalDebits += amt;
      final key = t.accountId ?? '—';
      byAccount[key] = (byAccount[key] ?? 0) + amt;
    } else {
      totalCredits += amt;
    }
  }

  String accountLabel(String? id) {
    if (id == null || id == '—') return 'No account';
    final a = accounts.where((a) => a.id == id);
    return a.isEmpty ? id : a.first.name;
  }

  final total = totalDebits + totalCredits;
  final rows = byAccount.entries.map((e) {
    final pct = total > 0 ? (e.value / total) * 100 : null;
    return ReportRow(
      label: accountLabel(e.key == '—' ? null : e.key),
      amount: e.value,
      percentOfTotal: pct,
      accountId: e.key == '—' ? null : e.key,
    );
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  return ReportTotals(
    totalDebits: totalDebits,
    totalCredits: totalCredits,
    byAccount: rows,
  );
}

/// Result of spend analysis: total debits and breakdowns by category, account, and time.
class SpendAnalysis {
  final double totalSpend;
  final List<ReportRow> byCategory;
  final List<ReportRow> byAccount;
  final List<ReportRow> byMonth; // trend: label e.g. "Jan", amount

  const SpendAnalysis({
    required this.totalSpend,
    required this.byCategory,
    required this.byAccount,
    required this.byMonth,
  });
}

/// Aggregates debit transactions for spend analysis: by category, account, and month.
SpendAnalysis aggregateSpendAnalysis({
  required List<Transaction> transactions,
  required List<Account> accounts,
  required ReportFilter filter,
}) {
  final debits = transactions.where((t) {
    if (t.type != 'debit') return false;
    final d = t.date;
    if (d.isBefore(filter.start) || d.isAfter(filter.end)) return false;
    if (filter.accountIds.isNotEmpty && !filter.accountIds.contains(t.accountId)) return false;
    return true;
  }).toList();

  double totalSpend = 0;
  final byCategoryMap = <String, double>{};
  final byAccountMap = <String, double>{};
  final byMonthMap = <String, double>{};

  for (final t in debits) {
    final amt = t.amount;
    totalSpend += amt;

    final cat = (t.category ?? '').trim().isEmpty ? 'Uncategorized' : (t.category!);
    byCategoryMap[cat] = (byCategoryMap[cat] ?? 0) + amt;

    final accKey = t.accountId ?? '—';
    byAccountMap[accKey] = (byAccountMap[accKey] ?? 0) + amt;

    final monthKey = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
    byMonthMap[monthKey] = (byMonthMap[monthKey] ?? 0) + amt;
  }

  String accountLabel(String? id) {
    if (id == null || id == '—') return 'No account';
    final a = accounts.where((a) => a.id == id);
    return a.isEmpty ? id : a.first.name;
  }

  String monthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final m = int.tryParse(parts[1]);
    if (m == null) return key;
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${names[m]} ${parts[0]}';
  }

  final byCategory = byCategoryMap.entries.map((e) {
    final pct = totalSpend > 0 ? (e.value / totalSpend) * 100 : null;
    return ReportRow(label: e.key, amount: e.value, percentOfTotal: pct);
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  final byAccount = byAccountMap.entries.map((e) {
    final pct = totalSpend > 0 ? (e.value / totalSpend) * 100 : null;
    return ReportRow(
      label: accountLabel(e.key == '—' ? null : e.key),
      amount: e.value,
      percentOfTotal: pct,
    );
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  final byMonth = byMonthMap.entries.map((e) {
    return ReportRow(label: monthLabel(e.key), amount: e.value, percentOfTotal: null);
  }).toList()
    ..sort((a, b) => a.label.compareTo(b.label));

  return SpendAnalysis(
    totalSpend: totalSpend,
    byCategory: byCategory,
    byAccount: byAccount,
    byMonth: byMonth,
  );
}

/// Preset period: (start, end).
(DateTime, DateTime) periodRange(String preset) {
  final now = DateTime.now();
  switch (preset) {
    case 'this_week':
      final start = now.subtract(Duration(days: now.weekday - 1));
      return (DateTime(start.year, start.month, start.day), now);
    case 'this_month':
      return (DateTime(now.year, now.month, 1), now);
    case 'last_month':
      final first = DateTime(now.year, now.month - 1, 1);
      final last = DateTime(now.year, now.month, 0);
      return (first, last);
    case 'last_3_months':
      return (DateTime(now.year, now.month - 3, now.day), now);
    default:
      return (DateTime(now.year, now.month, 1), now);
  }
}
