// lib/shared/providers/database_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/database_service.dart';

/// Provides access to the DatabaseService
final databaseProvider = Provider((ref) {
  return DatabaseService;
});
