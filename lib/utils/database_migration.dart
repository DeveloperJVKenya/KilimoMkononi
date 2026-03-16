// lib/education/utils/database_migration.dart
// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helper.dart';

class DatabaseMigration {
  static final _firestore = FirebaseFirestore.instance;

  /// Parse old school ID format to extract components
  static (String schoolName, String system)? _parseOldSchoolId(String oldSchoolId) {
    // Old format: Kianda_Schooljunior or Lavington_International_School_primary
    final match = RegExp(r'^(.+)(primary|junior|senior|eightfourfour)$')
        .firstMatch(oldSchoolId);
    
    if (match != null) {
      return (match.group(1)!, match.group(2)!);
    }
    return null;
  }

  /// Check if a school ID is in the old format
  static bool _isOldFormat(String schoolId) {
    return schoolId.contains(RegExp(r'(primary|junior|senior|eightfourfour)$')) &&
           !schoolId.contains(RegExp(r'_(primary|junior|senior|eightfourfour)_\d+$'));
  }

  /// Main migration function - call this once to migrate all data
  static Future<void> migrateToNewStructure() async {
    print('Starting database migration...');
    
    try {
      // Step 1: Get all old-format school documents
      final oldSchools = await _firestore.collection('schools').get();
      
      for (final schoolDoc in oldSchools.docs) {
        final oldSchoolId = schoolDoc.id;
        
        // Skip if this is already in the new format
        if (!_isOldFormat(oldSchoolId)) {
          print('Skipping $oldSchoolId - already migrated or new format');
          continue;
        }
        
        print('Migrating: $oldSchoolId');
        
        // Parse the old school ID
        final parsed = _parseOldSchoolId(oldSchoolId);
        if (parsed == null) {
          print('Could not parse: $oldSchoolId');
          continue;
        }
        
        final (schoolName, system) = parsed;
        
        // Step 2: Check if there's a grades subcollection
        final gradesSnapshot = await schoolDoc.reference
            .collection('grades')
            .get();
        
        if (gradesSnapshot.docs.isEmpty) {
          print('No grades found for $oldSchoolId');
          continue;
        }
        
        for (final gradeDoc in gradesSnapshot.docs) {
          final grade = gradeDoc.id;
          
          print('  Migrating grade: $grade');
          
          // Build the new classId
          final newClassId = '${schoolName}_${system}_$grade';
          
          // Step 3: Create the new structure
          await FirestoreHelper.ensureGradeExists(newClassId);
          
          // Step 4: Migrate known collections
          final collectionsToMigrate = [
            'farming_content',
            'market_content',
            'weather_content',
            'field_content',
            'pest_content',
            'disease_content',
            'farm_management_content',
            'manuals_content',
            'field_data',
            'pest_data',
            'disease_data',
            'farm_management_data',
            'submissions',
          ];
          
          for (final collectionName in collectionsToMigrate) {
            try {
              final oldCollection = gradeDoc.reference.collection(collectionName);
              final docs = await oldCollection.get();
              
              if (docs.docs.isEmpty) {
                continue; // Skip empty collections
              }
              
              print('    Migrating collection: $collectionName (${docs.docs.length} docs)');
              
              final newCollection = FirestoreHelper.getContentFromClassId(
                  newClassId, collectionName);
              
              if (newCollection == null) {
                print('    Error: Could not get new collection for $collectionName');
                continue;
              }
              
              // Copy all documents
              for (final doc in docs.docs) {
                await newCollection.doc(doc.id).set(doc.data());
              }
              
              print('    ✓ Migrated ${docs.docs.length} documents from $collectionName');
            } catch (e) {
              print('    Error migrating $collectionName: $e');
            }
          }
        }
        
        // Step 5: Update EducationUsers with the new classId format
        await _updateEducationUsers(oldSchoolId, schoolName, system);
      }
      
      print('');
      print('Migration completed successfully!');
      print('Please verify the data using verifyMigration() before deleting old structure.');
      
    } catch (e) {
      print('Migration error: $e');
      rethrow;
    }
  }

  /// Update all EducationUsers that reference the old classId format
  static Future<void> _updateEducationUsers(
      String oldSchoolId, String schoolName, String system) async {
    
    print('  Updating EducationUsers...');
    
    // Query users by school name (with spaces)
    final schoolNameWithSpaces = schoolName.replaceAll('_', ' ');
    final usersSnapshot = await _firestore
        .collection('EducationUsers')
        .where('schoolName', isEqualTo: schoolNameWithSpaces)
        .get();
    
    if (usersSnapshot.docs.isEmpty) {
      print('  No users found for school: $schoolNameWithSpaces');
      return;
    }
    
    for (final userDoc in usersSnapshot.docs) {
      final data = userDoc.data();
      final classIds = List<String>.from(data['classIds'] ?? []);
      final currentClassId = data['currentClassId'] as String?;
      
      bool needsUpdate = false;
      final updatedClassIds = <String>[];
      
      // Update classIds list
      for (final classId in classIds) {
        // Check if this classId matches the old format for this school
        if (classId.startsWith(oldSchoolId)) {
          // Extract grade from old format (e.g., "Kianda_Schooljunior_7" -> "7")
          final gradeMatch = RegExp(r'_(\d+)$').firstMatch(classId);
          if (gradeMatch != null) {
            final grade = gradeMatch.group(1)!;
            final newClassId = '${schoolName}_${system}_$grade';
            updatedClassIds.add(newClassId);
            needsUpdate = true;
            print('    Updated classId: $classId -> $newClassId');
          } else {
            updatedClassIds.add(classId);
          }
        } else {
          updatedClassIds.add(classId);
        }
      }
      
      // Update currentClassId if needed
      String? updatedCurrentClassId = currentClassId;
      if (currentClassId != null && currentClassId.startsWith(oldSchoolId)) {
        final gradeMatch = RegExp(r'_(\d+)$').firstMatch(currentClassId);
        if (gradeMatch != null) {
          final grade = gradeMatch.group(1)!;
          updatedCurrentClassId = '${schoolName}_${system}_$grade';
          needsUpdate = true;
          print('    Updated currentClassId: $currentClassId -> $updatedCurrentClassId');
        }
      }
      
      // Apply updates
      if (needsUpdate) {
        final updateData = <String, dynamic>{
          'classIds': updatedClassIds,
        };
        if (updatedCurrentClassId != null) {
          updateData['currentClassId'] = updatedCurrentClassId;
        }
        
        await userDoc.reference.update(updateData);
        print('    ✓ Updated user: ${data['email']}');
      }
    }
  }

  /// Verify migration - compares document counts
  static Future<void> verifyMigration() async {
    print('');
    print('Verifying migration...');
    print('');
    
    final oldSchools = await _firestore.collection('schools').get();
    var allMatch = true;
    
    for (final schoolDoc in oldSchools.docs) {
      final oldSchoolId = schoolDoc.id;
      
      if (!_isOldFormat(oldSchoolId)) {
        continue; // Skip new format
      }
      
      final parsed = _parseOldSchoolId(oldSchoolId);
      if (parsed == null) continue;
      
      final (schoolName, system) = parsed;
      
      final gradesSnapshot = await schoolDoc.reference
          .collection('grades')
          .get();
      
      for (final gradeDoc in gradesSnapshot.docs) {
        final grade = gradeDoc.id;
        final newClassId = '${schoolName}_${system}_$grade';
        
        final collectionsToCheck = [
          'farming_content',
          'market_content',
          'weather_content',
          'field_content',
          'pest_content',
          'disease_content',
          'farm_management_content',
          'manuals_content',
          'field_data',
          'pest_data',
          'disease_data',
          'farm_management_data',
          'submissions',
        ];
        
        for (final collectionName in collectionsToCheck) {
          try {
            final oldCollection = gradeDoc.reference.collection(collectionName);
            final oldDocs = await oldCollection.get();
            
            if (oldDocs.docs.isEmpty) continue; // Skip empty collections
            
            final newCollection = FirestoreHelper.getContentFromClassId(
                newClassId, collectionName);
            
            if (newCollection == null) continue;
            
            final newDocs = await newCollection.get();
            
            if (oldDocs.docs.length == newDocs.docs.length) {
              print('✓ $oldSchoolId/grades/$grade/$collectionName: ${oldDocs.docs.length} docs');
            } else {
              print('✗ MISMATCH $oldSchoolId/grades/$grade/$collectionName: '
                  'old=${oldDocs.docs.length}, new=${newDocs.docs.length}');
              allMatch = false;
            }
          } catch (e) {
            print('Error checking $collectionName: $e');
          }
        }
      }
    }
    
    print('');
    if (allMatch) {
      print('✓ Verification complete - all document counts match!');
      print('You can now safely run deleteOldStructure() if desired.');
    } else {
      print('✗ Verification found mismatches - please review before deleting old data.');
    }
  }

  /// Clean up old data after verifying the migration
  /// WARNING: Only run this after confirming the new structure works!
  static Future<void> deleteOldStructure() async {
    print('');
    print('WARNING: This will delete the old data structure!');
    print('Make sure you have run verifyMigration() first.');
    print('');
    
    final oldSchools = await _firestore.collection('schools').get();
    var deleteCount = 0;
    
    for (final schoolDoc in oldSchools.docs) {
      final oldSchoolId = schoolDoc.id;
      
      // Only delete if this has the old format
      if (_isOldFormat(oldSchoolId)) {
        print('Deleting old structure: $oldSchoolId');
        await _deleteDocumentAndSubcollections(schoolDoc.reference);
        deleteCount++;
      }
    }
    
    print('');
    print('Deleted $deleteCount old school documents.');
  }

  /// Delete a document and all its subcollections (recursive)
  static Future<void> _deleteDocumentAndSubcollections(
      DocumentReference docRef) async {
    // Delete known subcollections
    final knownSubcollections = ['grades', 'systems'];
    
    for (final collectionName in knownSubcollections) {
      try {
        final collection = docRef.collection(collectionName);
        final docs = await collection.get();
        
        for (final doc in docs.docs) {
          await _deleteDocumentAndSubcollections(doc.reference);
        }
      } catch (e) {
        // Collection doesn't exist, continue
      }
    }
    
    // Delete the document itself
    await docRef.delete();
  }
}