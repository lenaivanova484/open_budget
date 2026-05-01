import 'package:drift/drift.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:open_budget/logic/format_number.dart';
import '../database.dart';
import '../tables/transactions.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions])
class TransactionsDao extends DatabaseAccessor<AppDatabase> with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  // add (insert) transaction
  Future<int> addTransaction({
    required double amount,
    required String description,
    required int accountOwnerId,
    int? categoryId,
    required DateTime date, 
    required TimeOfDay time,
  }) {
    final dateAndTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute
    );

    // 0 - income, 1 - expense
    final transactionType = amount > 0 ? 0 : 1;

    return into(transactions).insert(
      TransactionsCompanion.insert(
        amount: amount, 
        description: description, 
        accountOwnerId: accountOwnerId,
        categoryId: Value(categoryId),
        dateAndTime: dateAndTime,
        transactionType: transactionType,
      )
    );
  }

  // add transfer
  Future<void> addTransfer({
    required double amount,
    required int fromAccount, 
    required int toAccount,
    required DateTime date,
    required TimeOfDay time,
    required String description
  }) async {
    final dateAndTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final transferId = DateTime.now().millisecondsSinceEpoch;

    // add expense to 'from account'
    await batch((batch) {
      batch.insert(
        transactions, 
        TransactionsCompanion.insert(
          amount: -amount, 
          description: description, 
          accountOwnerId: fromAccount, 
          dateAndTime: dateAndTime,
          transferId: Value(transferId),
          transactionType: 2, // transfer type
        )
      );

      // add income to 'to account'
      batch.insert(
        transactions, 
        TransactionsCompanion.insert(
          amount: amount, 
          description: description, 
          accountOwnerId: toAccount, 
          dateAndTime: dateAndTime,
          transferId: Value(transferId),
          transactionType: 2, // transfer type
        ),
      );
    });
  }

  // update transfer description
  Future<int> updateTransferDescription(int transferId, String newDescription) {
    return (update(transactions)
      ..where(((transfer) => transfer.transferId.equals(transferId))))
        .write(TransactionsCompanion(description: Value(newDescription)
      )
    );
  }

  // update transfer date and time
  Future<int> updateTransferDateAndTime(int transferId, DateTime newDate) {
    return (update(transactions)
      ..where(((transfer) => transfer.transferId.equals(transferId))))
        .write(TransactionsCompanion(dateAndTime: Value(newDate)
      )
    );
  }

  // delete transfer
  Future<int> deleteTransfer(int transferId) {
    return (delete(transactions)..where((transfer) => transfer.transferId.equals(transferId))).go();
  }

  // delete transaction
  Future<int> deleteTransaction(int id) {
    return (delete(transactions)..where((transaction) => transaction.id.equals(id))).go();
  }

  // update amount
  Future<int> updateAmount(int id, double newAmount) {
    return (update(transactions)
      ..where(((transaction) => transaction.id.equals(id))))
        .write(TransactionsCompanion(amount: Value(newAmount)
      )
    );
  }

  // update transaction date 
  Future<int> updateDateAndTime(int id, DateTime newDate) {
    return (update(transactions)
      ..where(((transaction) => transaction.id.equals(id))))
        .write(TransactionsCompanion(dateAndTime: Value(newDate)
      )
    );
  }

  // update transaction category id 
  Future<int> updateTransactionCategoryId(int id, int newCategoryId) {
    return (update(transactions)
      ..where(((transaction) => transaction.id.equals(id))))
        .write(TransactionsCompanion(categoryId: Value(newCategoryId)
      )
    );
  }

  // update (edit) transaction description
  Future<int> updateDescription(int id, String newDescription) async {
    return (update(transactions)
      ..where(((transaction) => transaction.id.equals(id))))
        .write(TransactionsCompanion(description: Value(newDescription)
      )
    );
  }

  // get all transactions
  Stream<List<Transaction>> watchAllTransactionItems(int accountOwnerId) {
    return (select(transactions)
      ..where((t) => t.accountOwnerId.equals(accountOwnerId))
      ..orderBy([
        (transaction) => OrderingTerm(
          expression: transaction.dateAndTime,
          mode: OrderingMode.desc // highest items first (so user gets recent transactions first)
        )
      ])
    ).watch();
  }

  // calculate total balance 
  Stream<String> watchTotalBalance(
    Account accountOwner,
  ) {
    final totalExpression = transactions.amount.sum();
    final initialBalance = accountOwner.initialBalance;

    final query = selectOnly(transactions)
      ..addColumns([totalExpression])
      ..where(transactions.accountOwnerId.equals(accountOwner.id));

    return query.watchSingleOrNull().map((row) {
      final totalBalance = row?.read(transactions.amount.sum()) ?? 0;
      // sum total balance with initial balance
      return formatNumber(totalBalance + initialBalance);
    });
  }

  // watch total income
  Stream<double> watchTotalIncome({
    required int accountOwnerId,
  }) {
    final DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final DateTime endDate = DateTime.now();

    return (select(transactions)
      ..where((t) => t.transactionType.equals(2).not()) // do not include transfers
      ..where((t) => t.amount.isBiggerThanValue(0))
      ..where((t) => t.accountOwnerId.equals(accountOwnerId))
      ..where((t) => t.dateAndTime.isBiggerOrEqualValue(startDate)) // start date
      ..where((t) => t.dateAndTime.isSmallerOrEqualValue(endDate)) // end date
    ).watch()
      .map((rows) => rows.fold(0, (sum, t) => sum + t.amount)
    );
  }

  // watch total expense
  Stream<double> watchTotalExpense({
    required int accountOwnerId,
  }) {
    final DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final DateTime endDate = DateTime.now();

    return (select(transactions)
      ..where((t) => t.transactionType.equals(2).not()) // do not include transfers
      ..where((t) => t.amount.isSmallerThanValue(0))
      ..where((t) => t.accountOwnerId.equals(accountOwnerId))
      ..where((t) => t.dateAndTime.isBiggerOrEqualValue(startDate)) // start date
      ..where((t) => t.dateAndTime.isSmallerOrEqualValue(endDate)) // end date
    ).watch()
      .map((rows) => rows.fold(0, (sum, t) => sum + t.amount)
    );
  }

  // delete all transactions that associated with account 
  Future<int> deleteAllTransactionsByAccountOwnerId(int accountOwnerId) {
    return (delete(transactions)..where((transaction) => transaction.accountOwnerId.equals(accountOwnerId))).go();
  }

  // search transactions
  Stream<List<Transaction>> searchTransactions({
    required String query, 
    required int accountOwnerId}) {
    // if query is empty return all transactions
    if(query.isEmpty) {
      return watchAllTransactionItems(accountOwnerId);
    }
    final String formattedQuery = '%${query.toLowerCase()}%';
    // search through descriptions and amounts 
    return (
      select(transactions)..orderBy([
        (t) => OrderingTerm(
          expression: t.dateAndTime,
          mode: OrderingMode.desc,
        )
      ])..where((t) => 
        t.description.lower().like(formattedQuery) |
        t.amount.cast<String>().like(formattedQuery)
      )
    ).watch();
  }
}