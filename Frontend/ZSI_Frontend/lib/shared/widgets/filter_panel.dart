import 'package:flutter/material.dart';
import '../models/index.dart';

class FilterPanel extends StatefulWidget {
  final ObservationFilters filters;
  final Function(ObservationFilters) onFiltersChanged;

  const FilterPanel({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late DateTime? _selectedStartDate;
  late DateTime? _selectedEndDate;
  late List<String> _selectedStatuses;
  late double _minConfidence;
  late List<String> _selectedHabitats;
  late bool _onlyVerified;

  @override
  void initState() {
    super.initState();
    _selectedStartDate = widget.filters.startDate;
    _selectedEndDate = widget.filters.endDate;
    _selectedStatuses = List.from(widget.filters.statusFilters);
    _minConfidence = widget.filters.minConfidence ?? 0;
    _selectedHabitats = List.from(widget.filters.habitatFilters ?? []);
    _onlyVerified = widget.filters.onlyVerified ?? false;
  }

  void _applyFilters() {
    final newFilters = ObservationFilters(
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
      statusFilters: _selectedStatuses,
      minConfidence: _minConfidence > 0 ? _minConfidence : null,
      habitatFilters: _selectedHabitats.isNotEmpty ? _selectedHabitats : null,
      onlyVerified: _onlyVerified,
    );
    widget.onFiltersChanged(newFilters);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            // Date Range Filter
            Text('Date Range', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedStartDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _selectedStartDate = date);
                      }
                    },
                    child: Text(_selectedStartDate != null
                      ? '${_selectedStartDate!.month}/${_selectedStartDate!.day}/${_selectedStartDate!.year}'
                      : 'From'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedEndDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _selectedEndDate = date);
                      }
                    },
                    child: Text(_selectedEndDate != null
                      ? '${_selectedEndDate!.month}/${_selectedEndDate!.day}/${_selectedEndDate!.year}'
                      : 'To'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Status Filter
            Text('Status', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._buildStatusCheckboxes(),
            const SizedBox(height: 16),
            // Confidence Filter
            Text('Minimum Confidence: ${_minConfidence.toStringAsFixed(2)}', 
              style: Theme.of(context).textTheme.titleSmall),
            Slider(
              value: _minConfidence,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: (value) => setState(() => _minConfidence = value),
            ),
            const SizedBox(height: 16),
            // Habitat Filter
            Text('Habitat Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._buildHabitatCheckboxes(),
            const SizedBox(height: 16),
            // Verified Only Filter
            CheckboxListTile(
              title: const Text('Only Verified'),
              value: _onlyVerified,
              onChanged: (value) => setState(() => _onlyVerified = value ?? false),
            ),
            const SizedBox(height: 16),
            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _applyFilters();
                  Navigator.pop(context);
                },
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatusCheckboxes() {
    const statuses = ['pending', 'verified', 'rejected'];
    return statuses.map((status) {
      return CheckboxListTile(
        title: Text(status.toUpperCase()),
        value: _selectedStatuses.contains(status),
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedStatuses.add(status);
            } else {
              _selectedStatuses.remove(status);
            }
          });
        },
      );
    }).toList();
  }

  List<Widget> _buildHabitatCheckboxes() {
    const habitats = ['river', 'lake', 'pond', 'ocean', 'forest', 'grassland'];
    return habitats.map((habitat) {
      return CheckboxListTile(
        title: Text(habitat.toUpperCase()),
        value: _selectedHabitats.contains(habitat),
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedHabitats.add(habitat);
            } else {
              _selectedHabitats.remove(habitat);
            }
          });
        },
      );
    }).toList();
  }
}
