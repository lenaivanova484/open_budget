// contains all the content of home page
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_budget/logic/app_settings.dart';
import 'package:open_budget/logic/currencies.dart';
import 'package:open_budget/logic/database/database.dart';
import 'package:open_budget/logic/format_number.dart';
import 'package:open_budget/logic/icons_manager.dart';
import 'package:open_budget/pages/settings_page.dart';
import 'package:open_budget/pages/statistics_page.dart';
import 'package:open_budget/ui/accounts/account_choose_bottom_sheet.dart';
import 'package:open_budget/ui/accounts/account_create_bottom_sheet.dart';
import 'package:open_budget/ui/accounts/account_edit_bottom_sheet.dart';
import 'package:open_budget/ui/accounts/accounts_archive_sheet.dart';
import 'package:open_budget/ui/accounts/accounts_bottom_sheet.dart';
import 'package:open_budget/ui/categories/categories_bottom_sheet.dart';
import 'package:open_budget/ui/categories/categories_manager_bottom_sheet.dart';
import 'package:open_budget/ui/categories/category_create_bottom_sheet.dart';
import 'package:open_budget/ui/categories/category_edit_bottom_sheet.dart';
import 'package:open_budget/ui/settings/about_bottom_sheet.dart';
import 'package:open_budget/ui/transactions/all_transactions_bottom_sheet.dart';
import 'package:open_budget/ui/transactions/amount_edit_bottom_sheet.dart';
import 'package:open_budget/ui/transactions/transaction_details_bottom_sheet.dart';
import 'package:open_budget/widgets/build_transactions_list.dart';
import 'package:open_budget/widgets/custom_alert_dialog.dart';
import 'package:open_budget/widgets/custom_icon.dart';
import 'package:open_budget/widgets/custom_list_tile.dart';
import 'package:open_budget/widgets/custom_modal_bottom_sheet.dart';
import 'package:open_budget/widgets/date_time_picker.dart';
import 'package:open_budget/widgets/empty_list_placeholder.dart';
import 'package:open_budget/widgets/section_header.dart';
import 'package:open_budget/widgets/show_snack_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePageContent extends StatefulWidget {
  final AppDatabase db;
  final Function(ThemeMode) setTheme;

  const HomePageContent({
    super.key,
    required this.db,
    required this.setTheme,
  });
  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final PageController _pageViewController = PageController();
  int currentPageIndex = 0;

  bool _isShowingDescription = false;
  int _homeTransactionsCount = 3;
  PackageInfo _appInfo = PackageInfo(
    appName: 'Unknown', 
    packageName: 'Unknown', 
    version: 'Unknown', 
    buildNumber: 'Unknown',
  );

  // store categories locally 
  // sort them by id 
  // category is the value
  Map<int, Category> _categoriesById = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadDescriptionState();
    _loadTransactionsCount();
    _initAppInfo();
  }

  // get app info
  Future<void> _initAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appInfo = info;
    });
  }

  // load description preview state from shared_preferences
  Future<void> _loadDescriptionState() async {
    _isShowingDescription = await AppSettings.getTransactionDescriptionState() ?? false;
  }

  // load and keep categories locally
  // e.g. to get category name 
  Future<void> _loadCategories() async {
    widget.db.categoriesDao.watchCategories().listen((categories) {
      setState(() {
        _categoriesById= {for (var c in categories) c.id : c};
      });
    });
  }

  Future<void> _loadTransactionsCount() async {
    _homeTransactionsCount = await AppSettings.getTransactionsCountOnHomePage() ?? 3;
  }

  // open url in browser
  Future<void> _openWebsite(Uri url) async {
    if(!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      if(!mounted) return;
      showSnackBar(
        context: context, 
        content: const Text('Could not launch url')
      );
    }
  }

  // all transactions modalBottomSheet
  void _showAllTransactions({
    required int selectedAccountId,
    required Currency accountCurrency,
  }) {
    showCustomModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      borderRadius: 0,
      padding: 0,
      child: AllTransactionsBottomSheet(
        db: widget.db, 
        selectedAccountId: selectedAccountId, 
        categoriesById: _categoriesById, 
        currentCurrency: accountCurrency, 
        isShowingDescription: _isShowingDescription, 
        showTransactionDetails: _showTransactionDetails,
      ),
    );
  }

  // change transaction category modalBottomSheet
  void _showCategories({
    required bool isIncome,
    required Transaction item,
    }) {
    showCustomModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: CategoriesBottomSheet(
        db: widget.db,
        isIncome: isIncome,
        item: item,
      ),
    );
  }

  // amount editing modalBottomSheet
  void _showAmountEditingSheet({
    required bool isIncome,
    required Transaction item
  }) {
    showCustomModalBottomSheet(
      context: context, 
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: AmountEditBottomSheet(
        db: widget.db,
        isIncome: isIncome,
        item: item,
      ),
    );
  }

  // edit date picker 
  void _showEditDatePicker(Transaction item) async {
    final oldDate = item.dateAndTime;

    // show date picker 
    DateTime? newDate = await pickDate(
      context: context,
      currentDate: oldDate,
    );

    if(newDate != null) {
      newDate = DateTime(
        newDate.year,
        newDate.month,
        newDate.day,
        oldDate.hour,
        oldDate.minute,
      );
      // update in db
      if(item.transactionType == 2) {
        // update transfer date and time
        widget.db.transactionsDao.updateTransferDateAndTime(item.transferId!, newDate);
      } else {
        // update transaction date and time
        widget.db.transactionsDao.updateDateAndTime(item.id, newDate);
      }
      if(!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // edit time picker
  void _showEditTimePicker(Transaction item) async {
    final oldDate = item.dateAndTime;

    // show time picker
    final newTime = await pickTime(
      context: context,
      initialTime: TimeOfDay(hour: oldDate.hour, minute: oldDate.minute),
    );

    if(newTime != null) {
      final newDate = DateTime(
        oldDate.year,
        oldDate.month,
        oldDate.day,
        newTime.hour,
        newTime.minute,
      );
      // update in db
      if(item.transactionType == 2) {
        // update transfer date and time
        widget.db.transactionsDao.updateTransferDateAndTime(item.transferId!, newDate);
      } else {
        // update transaction date and time
        widget.db.transactionsDao.updateDateAndTime(item.id, newDate);
      }
      if(!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // transaction details modalBottomSheet
  void _showTransactionDetails(Transaction item, Currency accountCurrency) {
    final category = _categoriesById[item.categoryId];
    final iconNameKey = category?.iconName;
    bool isIncome = item.amount > 0
      ? true
      : false;

    showCustomModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      borderRadius: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: TransactionDetailsBottomSheet(
        db: widget.db, 
        item: item, 
        currentCurrency: accountCurrency, 
        categoriesById: _categoriesById, 
        isIncome: isIncome, 
        iconNameKey: iconNameKey, 
        showDeleteConfirmation: _showDeleteConfirmation, 
        showTransferDeleteConfirmation: _showTransferDeleteConfirmation,
        showAmountEditingSheet: _showAmountEditingSheet, 
        showCategories: _showCategories, 
        showEditDatePicker: _showEditDatePicker, 
        showEditTimePicker: _showEditTimePicker
      ),
    );
  }

  // delete transaction confirmation AlertDialog
  void _showDeleteConfirmation(Transaction transaction) {
    showDialog(
      context: context, 
      builder: (context) => CustomAlertDialog(
        title: 'Delete transaction?', 
        content: 'Are you sure you want to delete this transaction?', 
        leftButtonLabel: 'Cancel', 
        rightButtonLabel: 'Delete', 
        leftButtonAction: () => Navigator.pop(context), 
        rightButtonAction: () {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).popUntil((route) => route.isFirst);

          final deletedTransaction = transaction;
          widget.db.transactionsDao.deleteTransaction(deletedTransaction.id);

          showSnackBar(
            context: context, 
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction deleted',
                  style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                  onPressed: () {
                    // date and time
                    final DateTime dateAndTime = deletedTransaction.dateAndTime;

                    // date
                    final DateTime date = DateTime(
                      dateAndTime.year,
                      dateAndTime.month,
                      dateAndTime.day,
                    );

                    // time
                    final TimeOfDay time = TimeOfDay.fromDateTime(dateAndTime);

                    widget.db.transactionsDao.addTransaction(
                      amount: deletedTransaction.amount, 
                      description: deletedTransaction.description, 
                      accountOwnerId: deletedTransaction.accountOwnerId,
                      categoryId: deletedTransaction.categoryId, 
                      date: date, 
                      time: time
                    );

                    messenger.hideCurrentSnackBar();
                  },
                  child: Text('Undo', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showTransferDeleteConfirmation(Transaction transaction) {
    showDialog(
      context: context, 
      builder: (context) => CustomAlertDialog(
        title: 'Delete transfer?', 
        content: 'Are you sure you want to delete this transfer?', 
        leftButtonLabel: 'Cancel', 
        rightButtonLabel: 'Delete', 
        leftButtonAction: () => Navigator.pop(context), 
        rightButtonAction: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          widget.db.transactionsDao.deleteTransfer(transaction.transferId!);
        }
      ),
    );
  }

  // switch description state for transaction (show on home page or not)
  void _switchDescriptionState(bool state) {
    setState(() {
      _isShowingDescription = state;
    });
  }

  // handle transaction count increase or decrease on home page
  // return number of transactions for settings_bottom_sheet updating value
  int? _handleTransactionCount(int digit) {
    final newValue = _homeTransactionsCount + digit;

    if(newValue < 3 || newValue > 10) {
      HapticFeedback.selectionClick();
      return null;
    }
    setState(() {
      _homeTransactionsCount = newValue;
    });
    AppSettings.setTransactionsCountOnHomePage(_homeTransactionsCount);
    return _homeTransactionsCount;
  }

  void _showAccountsSheet() {
    showCustomModalBottomSheet(
      context: context, 
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      borderRadius: 0,
      child: AccountsBottomSheet(
        context: context,
        db: widget.db,
        showAccountCreateSheet: _showAccountCreateSheet,
        showAccountEditSheet: _showAccountEditSheet,
        showAccountsArchiveSheet: _showAccountsArchiveSheet,
      ),
    );
  }

  void _showAccountCreateSheet() {
    showCustomModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      borderRadius: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: AccountCreateBottomSheet(db: widget.db,)
    );
  }

  // about app modal bottom sheet
  void _showAboutSheet() {
    showCustomModalBottomSheet(
      context: context, 
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: AboutBottomSheet(
        appInfo: _appInfo,
        openWebsite: _openWebsite,
      ),
    );
  }

  // categories manager modal bottom sheet
  void _showCategoriesManager() {
    showCustomModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      borderRadius: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: CategoriesManagerBottomSheet(
        db: widget.db, 
        showCategoryDeletetionPrompt: _showCategoryDeletetionPrompt, 
        showCategoryEditingSheet: _showCategoryEditingSheet, 
        showCategoryCreationSheet: _showCategoryCreationSheet,
      ),
    );
  }

  // category deletion AlertDialog
  void _showCategoryDeletetionPrompt(int categoryId) {
    showDialog(
      context: context, 
      builder: (context) => CustomAlertDialog(
        title: 'Delete category?', 
        content: 'Transactions will stay, but without a category.', 
        leftButtonLabel: 'Cancel', 
        rightButtonLabel: 'Delete', 
        leftButtonAction: () => Navigator.pop(context), 
        rightButtonAction: () {
          HapticFeedback.heavyImpact();
          widget.db.categoriesDao.deleteCategory(categoryId);
          Navigator.pop(context);
        }
      ),
    );
  }

  // category creation modalBottomSheet
  void _showCategoryCreationSheet({
    required bool isIncome,
  }) {
    showCustomModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      borderRadius: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: CategoryCreateBottomSheet(
        db: widget.db,
        isIncome: isIncome,
      ),
    );
  }

  // edit category name and icon modal bottom sheet
  void _showCategoryEditingSheet(Category category) {
    showCustomModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      borderRadius: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: CategoryEditBottomSheet(
        db: widget.db,
        category: category,
      )
    );
  }

  void _showAccountEditSheet(Account account) {
    showCustomModalBottomSheet(
      context: context, 
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      borderRadius: 0,
      child: AccountEditBottomSheet(db: widget.db, account: account,)
    );
  }

  void _showAccountChooseSheet({required List<Account> allAccounts}) {
    showCustomModalBottomSheet(
      context: context, 
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: AccountChooseBottomSheet(
        db: widget.db,
        pageViewController: _pageViewController,
        allAccounts: allAccounts,
      ),
    );
  }

  void _showAccountsArchiveSheet() {
    showCustomModalBottomSheet(
      context: context, 
      backgroundColor: Theme.of(context).colorScheme.surface,
      borderRadius: 0,
      isScrollControlled: true,
      child: AccountsArchiveSheet(
        context: context,
        db: widget.db,
      )
    );
  }

  void _handlePageViewChanged({
    required int pageIndex,
    required List<Account> items,
  }) {
    HapticFeedback.selectionClick();
    currentPageIndex = pageIndex; // selected account based on page view index
  }

  // header
  Widget _header({
    required Account account,
    required List<Account> allAccounts,
    required Currency accountCurrency,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 15, 0, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // statistics icon button
          IconButton(
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => StatisticsPage(
                  db: widget.db, 
                  currentCurrency: accountCurrency, 
                  accountOwnerId: account.id
                )
              )
            ),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
            icon: const Icon(Icons.data_usage_outlined)
          ),
          // account filled button
          // on tap account choose modal botom sheet
          FilledButton(
            onPressed: () => _showAccountChooseSheet(allAccounts: allAccounts), 
            child: Row(
              spacing: 5,
              children: [
                Text(
                  account.name,
                  style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ],
            )
          ),
          // settings icon button
          IconButton(
            onPressed: () async {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => SettingsPage(
                  homeTransactionsCount: _homeTransactionsCount,
                  isShowingDescription: _isShowingDescription,
                  setTheme: (newTheme) => widget.setTheme(newTheme),
                  switchDescriptionState: (bool state) => _switchDescriptionState(state),
                  handleTransactionCount: (digit) => _handleTransactionCount(digit),
                  showAccountsSheet: _showAccountsSheet,
                  showCategoriesManager: _showCategoriesManager,
                  showAboutSheet: _showAboutSheet,
                  )
                )
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
            icon: const Icon(Icons.settings_outlined)
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: widget.db.accountsDao.watchAccounts(false), 
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];

                // if there is no accounts
                // show placeholder
                return items.isEmpty 
                  ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      EmptyListPlaceholder(
                        color: Theme.of(context).colorScheme.surface, 
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No accounts yet',
                        subtitle: 'Please, create account first'
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary
                        ),
                        child: Text(
                          'Create Account',
                          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                        ),
                        onPressed: () => _showAccountCreateSheet(),
                      ),
                    ],
                  )
                  // otherwise show body
                  : PageView.builder(
                    controller: _pageViewController,
                    onPageChanged: (index) => _handlePageViewChanged(
                      pageIndex: index,
                      items: items
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final account = items[index];
                      final Currency accountCurrency = Currency.currencies.firstWhere((c) => c.code == account.currency);

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
                        child: Column(
                          children: [
                            _header(
                              account: account, 
                              allAccounts: items,
                              accountCurrency: accountCurrency
                            ),
                            const SizedBox(height: 10),
                            // total balance
                            StreamBuilder(
                              stream: widget.db.transactionsDao.watchTotalBalance(account),
                              builder: (context, snapshot) {
                                final totalBalance = snapshot.data ?? 0;
                                return Container(
                                  alignment: Alignment.center,
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(15)
                                  ),
                                  child: Column(
                                    children: [
                                      CustomIcon(icon: IconsManager.getAccountIconByName(account.icon)),
                                      Text(account.name),
                                      Text(
                                        '${totalBalance.toString()} ${accountCurrency.symbol}', 
                                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  )
                                );
                              }
                            ),
                            const SizedBox(height: 10),
                            // tab indicator
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color: Theme.of(context).colorScheme.primaryContainer,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 10,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      _pageViewController.animateToPage(
                                        currentPageIndex - 1, 
                                        duration: const Duration(milliseconds: 300), 
                                        curve: Curves.easeOutCubic
                                      );
                                    }, 
                                    icon: const Icon(Icons.chevron_left)
                                  ),
                                  ...List.generate(
                                    items.length, 
                                    (int index) {
                                      bool isSelected = items[index].id == account.id;
                                      return Icon(
                                        color: Theme.of(context).colorScheme.tertiary,
                                        size: 10,
                                        isSelected
                                          ? Icons.circle
                                          : Icons.circle_outlined
                                      );
                                    }
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _pageViewController.animateToPage(
                                        currentPageIndex + 1, 
                                        duration: const Duration(milliseconds: 300), 
                                        curve: Curves.easeOutCubic
                                      );
                                    }, 
                                    icon: const Icon(Icons.chevron_right)
                                  ),
                                ] 
                              ),
                            ),
                            // last transactions (3 to 10)
                            const SectionHeader(
                              title: 'Transactions'
                            ),
                            const SizedBox(height: 10),
                            Material(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(15),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  StreamBuilder(
                                    stream: widget.db.transactionsDao.watchAllTransactionItems(account.id),
                                    builder: (context, snapshot) {
                                      final items = snapshot.data ?? [];
                                      final lastThreeItems = items.take(_homeTransactionsCount).toList();
                                      return items.isNotEmpty
                                      ? buildTransactionList(
                                        context: context, 
                                        tileColor: Theme.of(context).colorScheme.primaryContainer,
                                        shrinkWrap: true,
                                        items: lastThreeItems, 
                                        categoriesById: _categoriesById,
                                        currentCurrency: accountCurrency, 
                                        showTransactionDetails: _showTransactionDetails,
                                        shouldInsertDate: false,
                                        showDescription: _isShowingDescription,
                                        scrollPhysics: const NeverScrollableScrollPhysics()
                                      )
                                      : Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: EmptyListPlaceholder(
                                          color: Theme.of(context).colorScheme.primaryContainer,
                                          icon: Icons.close_rounded, 
                                          title: 'No transactions yet', 
                                          subtitle: 'Add transactions and they will appear here'
                                        )
                                      );
                                    }
                                  ),
                                  Divider(
                                    height: 1,
                                    color: Theme.of(context).colorScheme.surface,
                                  ),
                                  // all transactions listtile
                                  CustomListTile(
                                    tileColor: Theme.of(context).colorScheme.primaryContainer,
                                    title: 'All Transactions',
                                    trailing: const CustomIcon(icon: Icons.chevron_right),
                                    customBorder: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.zero,
                                        bottom: Radius.circular(15)
                                      )
                                    ),
                                    onTap: () => _showAllTransactions(
                                      selectedAccountId: account.id, 
                                      accountCurrency: accountCurrency
                                    ),
                                  ),
                                ],
                              )
                            ),
                            // summary 
                            const SectionHeader(
                              title: 'This month'
                            ),
                            const SizedBox(height: 10),
                            Material(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(15),
                              child: Column(
                                children: [
                                  // net 
                                  StreamBuilder(
                                    stream: widget.db.transactionsDao.watchTotalIncome(accountOwnerId: account.id), 
                                    builder: (context, incomeSnapshot) {
                                      final income = incomeSnapshot.data ?? 0;

                                      return StreamBuilder(
                                        stream: widget.db.transactionsDao.watchTotalExpense(accountOwnerId: account.id), 
                                        builder: (context, expenseSnapshot) {
                                          final expense = (expenseSnapshot.data ?? 0).abs();

                                          final net = income - expense;
                                          final formattedNet = formatNumber(net);
                                          final isPositive = net > 0 ? true : false;
                                          
                                          return CustomListTile(
                                            tileColor: Theme.of(context).colorScheme.primaryContainer, 
                                            leading: const CustomIcon(icon: Icons.bar_chart),
                                            title: 'Net',
                                            trailing: Text(
                                              '$formattedNet ${accountCurrency.symbol}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: isPositive ? Colors.green : Theme.of(context).colorScheme.onPrimary
                                              ),
                                            ),
                                          );
                                        }
                                      );
                                    }
                                  ),
                                  Divider(
                                    height: 1,
                                    color: Theme.of(context).colorScheme.surface,
                                  ),
                                  // total incomes
                                  StreamBuilder(
                                    stream: widget.db.transactionsDao.watchTotalIncome(
                                      accountOwnerId: account.id,
                                    ), 
                                    builder: (context, snapshot) {
                                      final income = snapshot.data ?? 0;
                                      final formattedIncome = formatNumber(income);

                                      return CustomListTile(
                                        tileColor: Theme.of(context).colorScheme.primaryContainer,
                                        leading: const CustomIcon(icon: Icons.download_outlined),
                                        title: 'Income',
                                        trailing: Text(
                                          '+$formattedIncome ${accountCurrency.symbol}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: income > 0 ? Colors.green : Theme.of(context).colorScheme.onPrimary
                                          ),
                                        ),
                                      );
                                    }
                                  ),
                                  // total expenses
                                  StreamBuilder(
                                    stream: widget.db.transactionsDao.watchTotalExpense(
                                      accountOwnerId: account.id,
                                    ), 
                                    builder: (context, snapshot) {
                                      final expense = snapshot.data ?? 0;
                                      final formattedExpense = formatNumber(expense);

                                      return CustomListTile(
                                        tileColor: Theme.of(context).colorScheme.primaryContainer,
                                        leading: const CustomIcon(icon: Icons.upload_outlined),
                                        title: 'Expense',
                                        trailing: Text(
                                          '$formattedExpense ${accountCurrency.symbol}',
                                          style: const TextStyle(
                                            fontSize: 15
                                          ),
                                        ),
                                      );
                                    }
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
              }
            ),
          ),
        ],
      ),
    );
  }
}