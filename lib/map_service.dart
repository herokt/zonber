import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapService {
  FirebaseFirestore? _db;

  MapService() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _db = FirebaseFirestore.instance;
      } catch (e) {
        print("Firestore init failed (or not available): $e");
      }
    }
  }

  // Save a custom map
  Future<bool> saveCustomMap({
    required String name,
    required String author,
    required List<List<int>> gridData,
    bool verified = false,
  }) async {
    if (_db == null) return false;
    try {
      // Flatten grid data to a simple list or string for storage efficiency if needed,
      // but List<List> is supported as array of arrays (though Firestore prefers 1D).
      // Let's store as a flat list 'cells' and 'width', 'height'.

      int height = gridData.length;
      int width = gridData[0].length;

      List<int> flatGrid = [];
      for (var row in gridData) {
        flatGrid.addAll(row);
      }

      await _db!.collection('custom_maps').add({
        'name': name,
        'author': author,
        'width': width,
        'height': height,
        'grid': flatGrid,
        'verified': verified,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print("Error saving map: $e");
      return false;
    }
  }

  // Fetch all custom maps (Metadata only ideally, but we fetch all for now)
  Future<List<Map<String, dynamic>>> getCustomMaps() async {
    if (_db == null) return [];
    try {
      QuerySnapshot snapshot = await _db!
          .collection('custom_maps')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = 'custom_${doc.id}'; // Prefix to distinguish
        return data;
      }).toList();
    } catch (e) {
      print("Error fetching maps: $e");
      return [];
    }
  }

  // Fetch specific map details (if we separated list vs details, but currently we get all)
  Future<Map<String, dynamic>?> getMap(String mapId) async {
    if (_db == null) return null;
    try {
      String docId = mapId.replaceAll('custom_', '');
      DocumentSnapshot doc = await _db!
          .collection('custom_maps')
          .doc(docId)
          .get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error fetching map details: $e");
      return null;
    }
  }

  // Delete a map (Author check should be done on UI side or Security Rules)
  Future<bool> deleteCustomMap(String mapId) async {
    if (_db == null) return false;
    try {
      String docId = mapId.replaceAll('custom_', '');
      await _db!.collection('custom_maps').doc(docId).delete();
      return true;
    } catch (e) {
      print("Error deleting map: $e");
      return false;
    }
  }
}
