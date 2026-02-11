// lib/screens/create_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import '../providers/group_provider.dart';
import '../providers/expense_provider.dart';

class CreateExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;

  const CreateExpenseScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  ConsumerState<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends ConsumerState<CreateExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  String? _selectedCategory;
  List<String> _selectedMembers = [];
  bool _isLoading = false;
  bool _splitEqually = true;
  bool _useItemizedExpense = false;
  
  List<ExpenseItem> _items = [ExpenseItem(name: '', price: 0.0)];
  final List<TextEditingController> _itemNameControllers = [TextEditingController()];
  final List<TextEditingController> _itemPriceControllers = [TextEditingController()];
  final List<TextEditingController> _itemQuantityControllers = [TextEditingController(text: '1')];

  final List<String> _categories = [
    'food',
    'transport',
    'entertainment',
    'shopping',
    'utilities',
    'other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    for (var controller in _itemNameControllers) controller.dispose();
    for (var controller in _itemPriceControllers) controller.dispose();
    for (var controller in _itemQuantityControllers) controller.dispose();
    super.dispose();
  }

  void _addItemRow() {
    setState(() {
      _items.add(ExpenseItem(name: '', price: 0.0));
      _itemNameControllers.add(TextEditingController());
      _itemPriceControllers.add(TextEditingController());
      _itemQuantityControllers.add(TextEditingController(text: '1'));
    });
  }

  void _removeItemRow(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
        _itemNameControllers[index].dispose();
        _itemPriceControllers[index].dispose();
        _itemQuantityControllers[index].dispose();
        _itemNameControllers.removeAt(index);
        _itemPriceControllers.removeAt(index);
        _itemQuantityControllers.removeAt(index);
      });
    }
  }

  double get _totalAmount {
    if (_useItemizedExpense) {
      return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
    }
    return 0.0;
  }

  Future<void> _scanReceipt() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      
      if (image != null) {
        setState(() => _isLoading = true);
        
        final inputImage = InputImage.fromFilePath(image.path);
        final textRecognizer = TextRecognizer();
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        
        await textRecognizer.close();
        
        final items = _parseReceiptText(recognizedText.text);
        
        setState(() {
          _items.clear();
          _itemNameControllers.forEach((controller) => controller.dispose());
          _itemPriceControllers.forEach((controller) => controller.dispose());
          _itemQuantityControllers.forEach((controller) => controller.dispose());
          _itemNameControllers.clear();
          _itemPriceControllers.clear();
          _itemQuantityControllers.clear();
          
          for (var item in items) {
            _items.add(item);
            _itemNameControllers.add(TextEditingController(text: item.name));
            _itemPriceControllers.add(TextEditingController(text: item.price.toString()));
            _itemQuantityControllers.add(TextEditingController(text: item.quantity.toString()));
          }
          
          if (_items.isEmpty) {
            _addItemRow();
          }
          
          _useItemizedExpense = true;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${items.length} items in receipt')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning receipt: $e')),
      );
    }
  }

  List<ExpenseItem> _parseReceiptText(String text) {
    final items = <ExpenseItem>[];
    final lines = text.split('\n');
    
    final priceRegex = RegExp(r'\$?(\d+\.?\d*)');
    final itemRegex = RegExp(r'^([a-zA-Z\s]+)\s+\$?(\d+\.?\d*)');
    
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      final match = itemRegex.firstMatch(line);
      if (match != null) {
        final name = match.group(1)?.trim() ?? '';
        final priceStr = match.group(2) ?? '0';
        final price = double.tryParse(priceStr) ?? 0.0;
        
        if (name.isNotEmpty && price > 0) {
          items.add(ExpenseItem(name: name, price: price));
        }
      } else {
        final priceMatch = priceRegex.firstMatch(line);
        if (priceMatch != null && line.contains(RegExp(r'[a-zA-Z]'))) {
          final price = double.tryParse(priceMatch.group(1) ?? '0') ?? 0.0;
          final name = line.replaceAll(priceRegex, '').trim();
          
          if (name.isNotEmpty && price > 0) {
            items.add(ExpenseItem(name: name, price: price));
          }
        }
      }
    }
    
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
      ),
      body: groupsAsync.when(
        data: (groups) {
          final group = groups.firstWhere((g) => g.id == widget.groupId, 
              orElse: () => Group(id: '', name: 'Group', memberIds: [], createdBy: '', createdAt: DateTime.now()));
          
          // Initialize selected members with current user if not already done
          if (_selectedMembers.isEmpty) {
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            if (currentUserId != null && group.memberIds.contains(currentUserId)) {
              _selectedMembers = [currentUserId];
            }
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Description field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Dinner at restaurant',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Receipt scanning and expense type toggle
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            title: const Text('Itemized Expense'),
                            subtitle: const Text('Add individual items'),
                            value: _useItemizedExpense,
                            onChanged: (value) {
                              setState(() {
                                _useItemizedExpense = value;
                              });
                            },
                          ),
                        ),
                        if (_useItemizedExpense)
                          IconButton(
                            onPressed: _scanReceipt,
                            icon: const Icon(Icons.camera_alt),
                            tooltip: 'Scan Receipt',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Itemized expense section
                    if (_useItemizedExpense) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Items',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: _addItemRow,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Items list
                      Expanded(
                        child: ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) => _buildItemRow(index),
                        ),
                      ),
                      
                      // Total amount display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Total: \$${_totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // Simple amount field for non-itemized
                      TextFormField(
                        onChanged: (value) {
                          final amount = double.tryParse(value) ?? 0.0;
                          setState(() {
                            _items = [ExpenseItem(name: _descriptionController.text, price: amount)];
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          border: OutlineInputBorder(),
                          prefixText: '\$',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(_getCategoryIcon(category)),
                              const SizedBox(width: 8),
                              Text(category.toUpperCase()),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Split options
                    CheckboxListTile(
                      title: const Text('Split equally among selected members'),
                      value: _splitEqually,
                      onChanged: (value) {
                        setState(() {
                          _splitEqually = value ?? true;
                        });
                      },
                    ),
                    const SizedBox(height: 8),

                    // Members selection
                    const Text(
                      'Split Among',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: group.memberIds.map<Widget>((memberId) {
                          final isCurrentUser = memberId == FirebaseAuth.instance.currentUser?.uid;
                          final isSelected = _selectedMembers.contains(memberId);
                          
                          return CheckboxListTile(
                            title: Text(isCurrentUser ? 'You' : 'Member'),
                            subtitle: Text(memberId),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedMembers.add(memberId);
                                } else {
                                  _selectedMembers.remove(memberId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Create button
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton(
                        onPressed: _selectedMembers.isNotEmpty ? _createExpense : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Create Expense'),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _itemNameControllers[index],
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _items[index] = ExpenseItem(
                      name: value,
                      price: _items[index].price,
                      quantity: _items[index].quantity,
                    );
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _itemPriceControllers[index],
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  final price = double.tryParse(value) ?? 0.0;
                  setState(() {
                    _items[index] = ExpenseItem(
                      name: _items[index].name,
                      price: price,
                      quantity: _items[index].quantity,
                    );
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _itemQuantityControllers[index],
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final quantity = int.tryParse(value) ?? 1;
                  setState(() {
                    _items[index] = ExpenseItem(
                      name: _items[index].name,
                      price: _items[index].price,
                      quantity: quantity,
                    );
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _removeItemRow(index),
              icon: const Icon(Icons.delete, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'entertainment':
        return Icons.movie;
      case 'shopping':
        return Icons.shopping_cart;
      case 'utilities':
        return Icons.electrical_services;
      default:
        return Icons.receipt;
    }
  }

  Future<void> _createExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member to split with')),
      );
      return;
    }

    // Validate items for itemized expenses
    if (_useItemizedExpense) {
      if (_items.isEmpty || _items.every((item) => item.name.isEmpty || item.price <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one valid item')),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final expenseRepository = ref.read(expenseRepositoryProvider);
      
      if (_useItemizedExpense) {
        // Update items from controllers
        for (int i = 0; i < _items.length; i++) {
          _items[i] = ExpenseItem(
            name: _itemNameControllers[i].text,
            price: double.tryParse(_itemPriceControllers[i].text) ?? 0.0,
            quantity: int.tryParse(_itemQuantityControllers[i].text) ?? 1,
          );
        }
        
        // Filter out invalid items
        final validItems = _items.where((item) => item.name.isNotEmpty && item.price > 0).toList();
        
        await expenseRepository.createExpense(
          groupId: widget.groupId,
          description: _descriptionController.text,
          amount: _totalAmount,
          splitAmong: _selectedMembers,
          category: _selectedCategory,
          items: validItems,
        );
      } else {
        // Simple expense
        final amount = _items.isNotEmpty ? _items[0].price : 0.0;
        if (amount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid amount')),
          );
          return;
        }
        
        await expenseRepository.createExpense(
          groupId: widget.groupId,
          description: _descriptionController.text,
          amount: amount,
          splitAmong: _selectedMembers,
          category: _selectedCategory,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating expense: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}