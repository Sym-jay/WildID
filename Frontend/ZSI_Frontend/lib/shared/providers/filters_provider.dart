import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/index.dart';

/// Comments for a specific record
final recordCommentsProvider = Provider.family<List<Comment>, String>((ref, recordId) {
  return [];
});

/// Filter state for observations
final observationFiltersProvider = Provider<ObservationFilters>((ref) {
  return ObservationFilters();
});

/// Filtered observations list
final filteredObservationsProvider = Provider.family<List<UploadRecord>, List<UploadRecord>>((ref, records) {
  final filters = ref.watch(observationFiltersProvider);
  return records.where((record) => filters.matches(record)).toList();
});
