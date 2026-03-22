
import 'dart:io';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
// New feature imports
import '../shared/widgets/user_profile_card.dart' as profile_widgets;
import '../core/services/archive_service.dart';


// ============================================================================
// MAIN APP & THEME (Legacy - to be refactored)
// ============================================================================


class MetadataFormScreen extends StatefulWidget {
  final File imageFile;
  final String? identifiedSpecies;
  final double? confidence;

  const MetadataFormScreen({
    super.key,
    required this.imageFile,
    this.identifiedSpecies,
    this.confidence,
  });

  @override
  State<MetadataFormScreen> createState() => _MetadataFormScreenState();
}

class _MetadataFormScreenState extends State<MetadataFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form fields
  String? _habitatType;
  double? _waterTemperature;
  double? _waterDepth;
  String? _waterTurbidity;
  String? _behaviors;
  DateTime? _observationDateTime;
  bool _isSaving = false;

  // Habitat options
  static const List<String> habitatOptions = [
    'River',
    'Lake',
    'Estuary',
    'Coastal',
    'Reservoir',
    'Pond',
    'Stream',
    'Other',
  ];

  static const List<String> turbidityOptions = [
    'Clear',
    'Slightly turbid',
    'Turbid',
    'Very turbid',
    'Unknown',
  ];

  @override
  void initState() {
    super.initState();
    _observationDateTime = DateTime.now();
  }

  Future<void> _selectDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _observationDateTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      if (mounted) {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_observationDateTime ?? DateTime.now()),
        );

        if (pickedTime != null) {
          setState(() {
            _observationDateTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
          });
        }
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    setState(() => _isSaving = true);

    try {
      // Archive the upload with metadata
      await ArchiveService.archiveUpload(
        imageFile: widget.imageFile,
        identifiedSpecies: widget.identifiedSpecies,
        confidence: widget.confidence,
        habitatType: _habitatType,
        waterTemperature: _waterTemperature,
        waterDepth: _waterDepth,
        waterTurbidity: _waterTurbidity,
        behaviors: _behaviors,
        observationDateTime: _observationDateTime,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Sighting recorded with scientific details'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving metadata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scientific Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions card
              Card(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Enhance data quality with scientific metadata',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Core information (habitat type) helps ZSI researchers understand species distribution. Additional details improve ecosystem analysis.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Required: Habitat Type
              Text(
                'Habitat Type *',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _habitatType,
                decoration: InputDecoration(
                  hintText: 'Select habitat',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: habitatOptions.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                onChanged: (value) => setState(() => _habitatType = value),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select habitat type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Optional: Water Temperature
              Text(
                'Water Temperature (°C)',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'e.g., 24.5',
                  prefixIcon: const Icon(Icons.thermostat),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onSaved: (value) {
                  if (value != null && value.isNotEmpty) {
                    _waterTemperature = double.tryParse(value);
                  }
                },
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final temp = double.tryParse(value);
                    if (temp == null || temp < -2 || temp > 50) {
                      return 'Enter temperature between -2°C and 50°C';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Optional: Water Depth
              Text(
                'Water Depth (meters)',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'e.g., 3.5',
                  prefixIcon: const Icon(Icons.water_drop),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onSaved: (value) {
                  if (value != null && value.isNotEmpty) {
                    _waterDepth = double.tryParse(value);
                  }
                },
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final depth = double.tryParse(value);
                    if (depth == null || depth < 0 || depth > 500) {
                      return 'Enter depth between 0 and 500 meters';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Optional: Water Turbidity
              Text(
                'Water Turbidity',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _waterTurbidity,
                decoration: InputDecoration(
                  hintText: 'Water clarity',
                  prefixIcon: const Icon(Icons.opacity),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: turbidityOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (value) => setState(() => _waterTurbidity = value),
              ),
              const SizedBox(height: 20),

              // Optional: Behaviors
              Text(
                'Observable Behaviors',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g., feeding, nesting, schooling',
                  prefixIcon: const Icon(Icons.comment),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onSaved: (value) => _behaviors = value?.trim(),
              ),
              const SizedBox(height: 20),

              // Optional: Observation DateTime
              Text(
                'When was this sighting?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDateTime,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _observationDateTime != null
                                ? '${_observationDateTime!.day}/${_observationDateTime!.month}/${_observationDateTime!.year} ${_observationDateTime!.hour}:${_observationDateTime!.minute.toString().padLeft(2, '0')}'
                                : 'Tap to select date & time',
                            style: TextStyle(
                              fontSize: 16,
                              color: _observationDateTime != null
                                  ? AppTheme.textPrimaryColor
                                  : AppTheme.textSecondaryColor,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppTheme.textSecondaryColor),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submitForm,
                  icon: _isSaving ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  ) : const Icon(Icons.check_circle),
                  label: Text(_isSaving ? 'Saving...' : 'Save & Confirm'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Skip for Now'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PHASE 2: EXPERT VERIFICATION QUEUE SCREEN
// ============================================================================

