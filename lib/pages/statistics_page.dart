import 'package:flutter/material.dart';
import 'package:open_budget/logic/currencies.dart';
import 'package:open_budget/logic/database/database.dart';
import 'package:open_budget/logic/format_number.dart';
import 'package:open_budget/widgets/custom_header.dart';
import 'package:open_budget/widgets/custom_header_title.dart';
import 'package:open_budget/widgets/custom_icon.dart';
import 'package:open_budget/widgets/custom_icon_button.dart';
import 'package:open_budget/widgets/custom_list_tile.dart';
import 'package:open_budget/widgets/custom_modal_bottom_sheet.dart';
import 'package:open_budget/widgets/date_time_picker.dart';
import 'package:open_budget/widgets/empty_list_placeholder.dart';
import 'package:open_budget/widgets/section_header.dart';

class StatisticsPage extends StatefulWidget {
  final AppDatabase db;
  final Currency currentCurrency;
  final int accountOwnerId;

  const StatisticsPage({
    super.key,
    required this.db,
    required this.currentCurrency,
    required this.accountOwnerId,
  });

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  String _periodButtonLabel = 'This month';
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  // list of categories 
  Widget _buildCategoriesRankingList({
    required int accountOwnerId,
    required bool isIncome,
  }) {
    return StreamBuilder(
      stream: widget.db.categoriesDao.sortCategoriesByTotalAmount(
        accountOwnerId: accountOwnerId,
        isIncome: isIncome,
        startDate: _startDate,
        endDate: _endDate,
      ),
      builder: (context, snapshot) {
        final sortedCategories = snapshot.data ?? [];
        final lastThreeItems = sortedCategories.length < 3 
          ? sortedCategories
          : sortedCategories.take(3).toList();

        return Column(
          children: [
            ListView.builder(
              itemCount: lastThreeItems.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {

                final category = lastThreeItems[index];
                bool isFirst = index == 0
                  ? true 
                  : false;

                return _buildCategory(
                  isFirst: isFirst, 
                  isLast: false,
                  index: index, 
                  title: category.key.name, 
                  value: category.value,
                );
              }
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.surface,
            ),
            sortedCategories.isEmpty
              ? EmptyListPlaceholder(
                color: Theme.of(context).colorScheme.primaryContainer,
                icon: Icons.receipt_long, 
                title: isIncome 
                  ? 'No top incomes'
                  : 'No top expenses', 
                subtitle: isIncome
                ? 'Add incomes and they will appear here'
                : 'Add expenses and they will appear here'
              )
              : CustomListTile(
                tileColor: Theme.of(context).colorScheme.primaryContainer,
                customBorder: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.zero,
                    bottom: Radius.circular(15),
                  )
                ),
                title: 'See All',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAllCategoriesRanking(
                  context: context, 
                  isIncome: isIncome,
                  categories: sortedCategories
                ),
              ),
          ],
        );
      }
    );
  }

  // category custom list tile
  Widget _buildCategory({
    required bool isFirst,
    required bool isLast,
    required int index,
    required String title,
    required double value,
  }) {
    return CustomListTile(
      tileColor: Theme.of(context).colorScheme.primaryContainer,
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          // top border 
          top: isFirst 
            // first in list so rounded corners
            ? const Radius.circular(15)
            // not first
            : Radius.zero,
          // bottom border
          bottom: isLast 
            // last in list so rounded corners
            ? const Radius.circular(15)
            // not last
            : Radius.zero
        )
      ),
      // category ranking number 
      leading: Text(
        '${index+1}.',
        style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onPrimary),
      ),
      // category name
      title: title,
      // amount of spent money in this category
      trailing: Text(
        '${formatNumber(value)} ${widget.currentCurrency.symbol}',
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  // all categories ranking modal bottom sheet
  void _showAllCategoriesRanking({
    required BuildContext context,
    required bool isIncome,
    required List<MapEntry<Category, double>> categories,
    }) {
    showCustomModalBottomSheet(
      context: context, 
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          CustomHeader(
            children: [
              CustomIconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)
              ),
              CustomHeaderTitle(                
                title: isIncome
                  ? 'Top Income Categories'
                  : 'Top Expense Categories'
              ),
              const SizedBox(width: 48),
            ],
          ),
          Expanded(
            child: ListView.separated(
              itemCount: categories.length,
              padding:const EdgeInsets.symmetric(horizontal: 15),
              separatorBuilder: (context, index) => const SizedBox(height: 1),
              itemBuilder: (context, index) {
                final category = categories[index];
                
                bool isFirst = index == 0
                  ? true 
                  : false;
                bool isLast = index == categories.length - 1
                  ? true
                  : false;

                return _buildCategory(
                  isFirst: isFirst, 
                  isLast: isLast,
                  index: index, 
                  title: category.key.name, 
                  value: category.value
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  // periods for statistics
  void _showPeriodsSheet() {
    showCustomModalBottomSheet(
      context: context, 
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Wrap(
        children: [
          CustomHeader(
            children: [
              CustomIconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)
              ),
              const CustomHeaderTitle(
                title: 'Period'
              ),
              const SizedBox(width: 48),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              spacing: 5,
              children: [
                // this month
                CustomListTile(
                  leading: const CustomIcon(icon: Icons.calendar_today),
                  tileColor: Theme.of(context).colorScheme.primaryContainer, 
                  title: 'This month',
                  onTap: () {
                    final now = DateTime.now();
                    Navigator.pop(context);
                    setState(() {
                      _periodButtonLabel = 'This month';
                      _startDate = DateTime(now.year, now.month, 1);
                      _endDate = DateTime(now.year, now.month + 1, 0);
                    });
                  },
                ),
                // previous month
                CustomListTile(
                  leading: const CustomIcon(icon: Icons.calendar_month),
                  tileColor: Theme.of(context).colorScheme.primaryContainer, 
                  title: 'Previous month',
                  onTap: () {
                    final now = DateTime.now();
                    Navigator.pop(context);
                    setState(() {
                      _periodButtonLabel = 'Previous month';
                      _startDate = DateTime(now.year, now.month - 1, 1);
                      _endDate = DateTime(now.year, now.month, 0);
                    });
                  },
                ),
                // all time
                CustomListTile(
                  leading: const CustomIcon(icon: Icons.calendar_view_week_outlined),
                  tileColor: Theme.of(context).colorScheme.primaryContainer, 
                  title: 'All time',
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {   
                      _periodButtonLabel = 'All time';
                      _startDate = DateTime(2000);
                      _endDate = DateTime.now();
                    });
                  },
                ),
                // custom period
                CustomListTile(
                  leading: const CustomIcon(icon: Icons.edit),
                  tileColor: Theme.of(context).colorScheme.primaryContainer, 
                  title: 'Custom period',
                  trailing: const CustomIcon(icon: Icons.chevron_right),
                  onTap: () async {
                    Navigator.pop(context);
                    final dateRange = await pickDateRange(context: context);

                    if(dateRange != null) {
                      setState(() {
                        // label in period button
                        // format dd.mm.yyyy - dd.mm.yyyy
                        _periodButtonLabel = 
                          '${dateRange.start.day.toString().padLeft(2, '0')}.'
                          '${dateRange.start.month.toString().padLeft(2, '0')}.'
                          '${dateRange.start.year} - '
                          '${dateRange.end.day.toString().padLeft(2, '0')}.'
                          '${dateRange.end.month.toString().padLeft(2, '0')}.'
                          '${dateRange.end.year}';
                        
                        _startDate = dateRange.start;
                        _endDate = DateTime(
                          dateRange.end.year,
                          dateRange.end.month,
                          dateRange.end.day,
                          23,
                          59,
                          59,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // header
            CustomHeader(
              children: [
                CustomIconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)
                ), 
                FilledButton(
                  onPressed: () => _showPeriodsSheet(),
                  child: Row(
                    spacing: 5,
                    children: [
                      Text(
                        _periodButtonLabel, 
                        style: const TextStyle(color: Colors.white)
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  children: [
                    const SectionHeader(
                      title: 'Top Income Categories'
                    ),
                    const SizedBox(height: 5),
                    _buildCategoriesRankingList(
                      accountOwnerId: widget.accountOwnerId, 
                      isIncome: true,
                    ),
                    const SectionHeader(
                      title: 'Top Expense Categories'
                    ),
                    const SizedBox(height: 5),
                    _buildCategoriesRankingList(
                      accountOwnerId: widget.accountOwnerId, 
                      isIncome: false,
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      )
    );
  }
}