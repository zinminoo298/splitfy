// lib/providers/group_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Model for a Group
class Group {
  final String id;
  final String name;
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'memberIds': memberIds,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }

  factory Group.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: data['name'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

// Provider for user's groups
final userGroupsProvider = StreamProvider((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('groups')
      .where('memberIds', arrayContains: user.uid)
      .snapshots()
      .map((snapshot) =>
      snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList());
});

// lib/providers/group_provider.dart (updated)
class GroupRepository {
  final FirebaseFirestore _firestore;

  GroupRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Updated to return the group ID
  Future<String> createGroup(String name, List<String> invitedUserIds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Create a new group with the current user + invited users
    List<String> memberIds = [user.uid];

    final docRef = await _firestore.collection('groups').add({
      'name': name,
      'memberIds': memberIds,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // Method to join a group
  Future<void> joinGroup(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get the group
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw Exception('Group not found');
    }

    final data = groupDoc.data();
    if (data == null) throw Exception('Group data is null');

    // Check if the user is already a member
    final List<String> memberIds = List<String>.from(data['memberIds'] ?? []);
    if (memberIds.contains(user.uid)) {
      // User is already a member, no need to add
      return;
    }

    // Add user to the group
    memberIds.add(user.uid);
    await _firestore.collection('groups').doc(groupId).update({
      'memberIds': memberIds,
    });
  }
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});