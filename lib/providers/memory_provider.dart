import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MemoryProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _memoryDocs = [];
  
  // Get simple list of strings for the AI context
  List<String> get memories => _memoryDocs.map((m) => m['fact'] as String).toList();
  
  // Get full objects for UI (if we build a memory manager screen)
  List<Map<String, dynamic>> get memoryDocs => _memoryDocs;

  Future<void> loadMemories() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
  
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('memories')
        .orderBy('timestamp', descending: true)
        .get();

    _memoryDocs.clear();
    for (var doc in snapshot.docs) {
      _memoryDocs.add({
        'id': doc.id,
        'fact': doc.data()['fact'],
        'timestamp': doc.data()['timestamp'],
      });
    }
    notifyListeners();
  }

  Future<void> addMemory(String fact) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Clean up the fact string (remove "Remember that", etc. if needed, 
    // but the AI might do this better. For now, we store raw or slightly cleaned.)
    // We'll rely on the caller to pass a clean fact or just store what was said.
    
    final ref = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('memories')
        .add({
      'fact': fact,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _memoryDocs.insert(0, {
      'id': ref.id,
      'fact': fact,
      'timestamp': DateTime.now(),
    });
    notifyListeners();
  }

  Future<void> deleteMemory(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('memories')
        .doc(id)
        .delete();

    _memoryDocs.removeWhere((m) => m['id'] == id);
    notifyListeners();
  }
}
