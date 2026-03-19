import 'package:flutter/material.dart';

class LifeListView extends StatefulWidget {
  final List<String> lifeList;
  final Map<String, int> speciesCounts;

  const LifeListView({
    super.key,
    required this.lifeList,
    required this.speciesCounts,
  });

  @override
  State<LifeListView> createState() => _LifeListViewState();
}

class _LifeListViewState extends State<LifeListView> {
  late List<String> _sortedList;
  String _sortBy = 'alphabetical'; // alphabetical, frequency, recent

  @override
  void initState() {
    super.initState();
    _updateSort();
  }

  void _updateSort() {
    _sortedList = List.from(widget.lifeList);
    
    switch (_sortBy) {
      case 'frequency':
        _sortedList.sort((a, b) => 
          (widget.speciesCounts[b] ?? 0).compareTo(widget.speciesCounts[a] ?? 0)
        );
        break;
      case 'recent':
        // Would need timestamp data - keep alphabetical for now
        _sortedList.sort();
        break;
      case 'alphabetical':
      default:
        _sortedList.sort();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with stats
        Container(
          color: Colors.blue.withValues(alpha: 0.1),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Life List',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.lifeList.length} species observed',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  '${widget.lifeList.length}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Sort dropdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('Sort by: ', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sortBy,
                items: const [
                  DropdownMenuItem(value: 'alphabetical', child: Text('Alphabetical')),
                  DropdownMenuItem(value: 'frequency', child: Text('Frequency')),
                  DropdownMenuItem(value: 'recent', child: Text('Recent')),
                ]
                .map((item) => DropdownMenuItem(
                  value: item.value,
                  child: item.child,
                ))
                .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortBy = value;
                      _updateSort();
                    });
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // List
        Expanded(
          child: widget.lifeList.isEmpty
            ? Center(
              child: Text(
                'No species in your life list yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            )
            : ListView.builder(
              itemCount: _sortedList.length,
              itemBuilder: (context, index) {
                final species = _sortedList[index];
                final count = widget.speciesCounts[species] ?? 0;
                
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(species),
                  trailing: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '$count observation${count > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
        ),
      ],
    );
  }
}
