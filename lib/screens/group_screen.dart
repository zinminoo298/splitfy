// lib/screens/group_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/group_provider.dart';
import '../providers/expense_provider.dart';
import 'create_expense_screen.dart';

class GroupScreen extends ConsumerWidget {
  final String groupId;

  const GroupScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: groupsAsync.when(
          data: (groups) {
            final group = groups.firstWhere((g) => g.id == groupId, 
                orElse: () => Group(id: '', name: 'Group', memberIds: [], createdBy: '', createdAt: DateTime.now()));
            return Text(group.name);
          },
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Group'),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'members') {
                _showMembersBottomSheet(context, ref, groupId);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'members',
                child: Row(
                  children: [
                    Icon(Icons.people),
                    SizedBox(width: 8),
                    Text('View Members'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Group summary card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: expensesAsync.when(
              data: (expenses) {
                final totalExpenses = expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
                final userExpenses = expenses.where((e) => e.paidBy == FirebaseAuth.instance.currentUser?.uid).fold<double>(0, (sum, expense) => sum + expense.amount);
                final userOwed = expenses.fold<double>(0, (sum, expense) {
                  if (expense.splitAmong.contains(FirebaseAuth.instance.currentUser?.uid)) {
                    return sum + expense.splitAmount;
                  }
                  return sum;
                });
                final balance = userExpenses - userOwed;

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSummaryItem('Total Expenses', '\$${totalExpenses.toStringAsFixed(2)}'),
                        _buildSummaryItem('Your Balance', '\$${balance.toStringAsFixed(2)}', 
                            color: balance >= 0 ? Colors.green : Colors.red),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading summary'),
            ),
          ),

          // Expenses list
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No expenses yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        Text('Tap + to add your first expense'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                    final isPaidByUser = expense.paidBy == currentUserId;
                    final isUserInvolved = expense.splitAmong.contains(currentUserId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPaidByUser ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                          child: Icon(
                            expense.category == 'food' ? Icons.restaurant :
                            expense.category == 'transport' ? Icons.directions_car :
                            expense.category == 'entertainment' ? Icons.movie :
                            Icons.shopping_cart,
                            color: isPaidByUser ? Colors.green : Colors.blue,
                          ),
                        ),
                        title: Text(expense.description),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Paid by ${isPaidByUser ? 'You' : 'Member'}'),
                            Text('Split among ${expense.splitAmong.length} people'),
                            Text('${expense.createdAt.day}/${expense.createdAt.month}/${expense.createdAt.year}'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${expense.amount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (isUserInvolved)
                              Text(
                                'You owe: \$${expense.splitAmount.toStringAsFixed(2)}',
                                style: TextStyle(color: Colors.red[600], fontSize: 12),
                              ),
                          ],
                        ),
                        onTap: () {
                          _showExpenseDetails(context, expense);
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateExpenseScreen(groupId: groupId),
            ),
          );
        },
        label: const Text('Add Expense'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showExpenseDetails(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              expense.description,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount:'),
                Text('\$${expense.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Split Amount:'),
                Text('\$${expense.splitAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Split Among:'),
                Text('${expense.splitAmong.length} people'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Date:'),
                Text('${expense.createdAt.day}/${expense.createdAt.month}/${expense.createdAt.year}'),
              ],
            ),
            if (expense.category != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Category:'),
                  Text(expense.category!),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMembersBottomSheet(BuildContext context, WidgetRef ref, String groupId) {
    final groupsAsync = ref.watch(userGroupsProvider);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Group Members',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            groupsAsync.when(
              data: (groups) {
                final group = groups.firstWhere((g) => g.id == groupId, 
                    orElse: () => Group(id: '', name: 'Group', memberIds: [], createdBy: '', createdAt: DateTime.now()));
                
                return Column(
                  children: group.memberIds.map((memberId) {
                    final isCurrentUser = memberId == FirebaseAuth.instance.currentUser?.uid;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(isCurrentUser ? 'You' : 'Member'),
                      subtitle: Text(memberId),
                      trailing: group.createdBy == memberId ? const Icon(Icons.admin_panel_settings) : null,
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error loading members'),
            ),
          ],
        ),
      ),
    );
  }
}