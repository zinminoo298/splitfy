// lib/providers/expense_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Model for an individual expense item
class ExpenseItem {
  final String name;
  final double price;
  final int quantity;

  ExpenseItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
    );
  }
}

// Model for an Expense
class Expense {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String paidBy;
  final List<String> splitAmong;
  final DateTime createdAt;
  final String? category;
  final List<ExpenseItem>? items;

  Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.splitAmong,
    required this.createdAt,
    this.category,
    this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'splitAmong': splitAmong,
      'createdAt': createdAt,
      'category': category,
      'items': items?.map((item) => item.toMap()).toList(),
    };
  }

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      paidBy: data['paidBy'] ?? '',
      splitAmong: List<String>.from(data['splitAmong'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      category: data['category'],
      items: data['items'] != null 
        ? (data['items'] as List).map((item) => ExpenseItem.fromMap(item)).toList()
        : null,
    );
  }

  double get splitAmount => amount / splitAmong.length;
}

// Provider for group expenses
final groupExpensesProvider = StreamProvider.family<List<Expense>, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('expenses')
      .where('groupId', isEqualTo: groupId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) =>
      snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList())
      .handleError((error) {
        // Handle permission errors for non-existent collections
        print('Error loading expenses: $error');
        return <Expense>[];
      });
});

// Repository for expense operations
class ExpenseRepository {
  final FirebaseFirestore _firestore;

  ExpenseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required List<String> splitAmong,
    String? category,
    List<ExpenseItem>? items,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore.collection('expenses').add({
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'paidBy': user.uid,
      'splitAmong': splitAmong,
      'createdAt': FieldValue.serverTimestamp(),
      'category': category,
      'items': items?.map((item) => item.toMap()).toList(),
    });
  }

  Future<void> deleteExpense(String expenseId) async {
    await _firestore.collection('expenses').doc(expenseId).delete();
  }

  Future<void> updateExpense(String expenseId, Map<String, dynamic> updates) async {
    await _firestore.collection('expenses').doc(expenseId).update(updates);
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});