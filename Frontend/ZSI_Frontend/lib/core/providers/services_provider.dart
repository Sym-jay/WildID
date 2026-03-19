import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';

// Service Providers - expose services as static services via Riverpod

// DatabaseService is used statically, so we just provide a reference
final databaseServiceProvider = Provider((ref) {
  // DatabaseService is a static class, just return the type reference
  return DatabaseService;
});
