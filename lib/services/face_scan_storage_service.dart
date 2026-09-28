import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FaceScanStorageService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseStorage _storage = FirebaseStorage.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ------------------------------------------------------------
  // Upload face image
  // ------------------------------------------------------------

  Future<String> uploadFaceImage({
    required Uint8List imageBytes,
    required String stage,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'No logged-in user found.',
      );
    }

    final String uid = user.uid;

    final String path = 'users/$uid/face_scan/$stage.jpg';

    final Reference ref = _storage.ref().child(path);

    await ref.putData(
      imageBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
      ),
    );

    final String downloadUrl = await ref.getDownloadURL();

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('face_scan')
        .doc(stage)
        .set({
      'stage': stage,
      'imageUrl': downloadUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return downloadUrl;
  }

  // ------------------------------------------------------------
  // Save scan completed status
  // ------------------------------------------------------------

  Future<void> saveScanCompleted() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'No logged-in user found.',
      );
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'faceScanCompleted': true,
        'faceScanCompletedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }
}
