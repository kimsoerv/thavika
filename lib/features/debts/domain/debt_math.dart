import 'dart:math';

/// What is still open on a debt.
int outstanding(int amountMinor, int paidMinor) =>
    max(0, amountMinor - paidMinor);

/// Share paid back, 0 to 1.
double paidFraction(int amountMinor, int paidMinor) =>
    amountMinor <= 0 ? 0 : (paidMinor / amountMinor).clamp(0.0, 1.0);

class DebtTotals {
  const DebtTotals({required this.owedToMe, required this.iOwe});

  /// Money others still owe me.
  final int owedToMe;

  /// Money I still owe others.
  final int iOwe;
}

class DebtLine {
  const DebtLine({
    required this.direction,
    required this.amountMinor,
    required this.paidMinor,
  });

  final String direction;
  final int amountMinor;
  final int paidMinor;
}

DebtTotals debtTotals(Iterable<DebtLine> lines) {
  var owed = 0;
  var owe = 0;
  for (final l in lines) {
    final open = outstanding(l.amountMinor, l.paidMinor);
    if (l.direction == 'lent') {
      owed += open;
    } else {
      owe += open;
    }
  }
  return DebtTotals(owedToMe: owed, iOwe: owe);
}

/// Everything I own minus everything I owe.
class NetWorth {
  const NetWorth({
    required this.inWallets,
    required this.inGoals,
    required this.owedToMe,
    required this.iOwe,
  });

  /// The balance of all wallets together.
  final int inWallets;

  /// Goal money that already left a wallet (goal money still counted in a
  /// wallet is part of [inWallets]).
  final int inGoals;
  final int owedToMe;
  final int iOwe;

  int get total => inWallets + inGoals + owedToMe - iOwe;
}
