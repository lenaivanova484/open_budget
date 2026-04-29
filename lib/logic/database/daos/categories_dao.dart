import 'package:drift/drift.dart';
import '../database.dart';

import '../tables/categories.dart';
import '../tables/transactions.dart';

part 'categories_dao.g.dart';


@DriftAccessor(tables: [Categories, Transactions])
class CategoriesDao extends DatabaseAccessor<AppDatabase> with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  // sort categories from highest to lowest expenses or incomes
  Stream<List<MapEntry<Category, double>>> sortCategoriesByTotalAmount({
    required int accountOwnerId,
    required bool isIncome,
    required DateTime startDate,
    required DateTime endDate,
    }) {
    final totalAmount = transactions.amount.sum();
    final absTotalAmount = totalAmount.abs();

    final query = select(categories).join([
      leftOuterJoin(
        transactions, 
        // filter all transactions with category id and account id 
        transactions.accountOwnerId.equals(accountOwnerId) &
        transactions.categoryId.equalsExp(categories.id) &
        // date range (from start to end date)
        transactions.dateAndTime.isBiggerOrEqualValue(startDate) &
        transactions.dateAndTime.isSmallerOrEqualValue(endDate),
      )
    ])
      ..where(categories.isIncome.equals(isIncome)) // true = income, false = expense
      ..addColumns([totalAmount])
      ..groupBy([categories.id])
      ..orderBy([OrderingTerm(expression: absTotalAmount, mode: OrderingMode.desc)]);


    return query.watch().map((rows) {
      return rows.map((row) {
        final category = row.readTable(categories);
        final total = row.read(totalAmount) ?? 0;

        return MapEntry(category, total);
      }).toList();
    });
  }

  // categories daos

  // watch all categories
  Stream<List<Category>> watchCategories() {
    return (select(categories)).watch();
  }

  // watch income/expense categories
  Stream<List<Category>> watchIncomeOrExpenseCategories(bool isIncome) {
    return (select(categories)..where((c) => c.isIncome.equals(isIncome))).watch();
  }

  // add category
  Future<int> addCategory({
    required String name,
    required bool isIncome,
    required String iconName,
  }) {
    return into(categories).insert(
      CategoriesCompanion.insert(
        name: name, 
        isIncome: isIncome, 
        iconName: iconName,
      )
    );
  } 

  // delete category
  Future<int> deleteCategory(int categoryId) {
    return (delete(categories)..where((c) => c.id.equals(categoryId))).go();
  }

  // find category
  Future<Category?> getCategoryById(int id) {
    return (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  // update category name
  Future<int> updateCategoryName(int id, String newName) async {
    return (update(categories)
      ..where(((c) => c.id.equals(id))))
        .write(CategoriesCompanion(name: Value(newName)
      )
    );
  }

  // update category icon
  Future<int> updateCategoryIcon(int id, String newIcon) async {
    return (update(categories)
      ..where(((c) => c.id.equals(id))))
        .write(CategoriesCompanion(iconName: Value(newIcon)
      )
    );
  }
}