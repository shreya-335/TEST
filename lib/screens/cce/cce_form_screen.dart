// lib/screens/cce/cce_form_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CceFormScreen extends StatefulWidget {
  final String taskId;
  const CceFormScreen({super.key, required this.taskId});

  @override
  State<CceFormScreen> createState() => _CceFormScreenState();
}

class _CceFormScreenState extends State<CceFormScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // --- Stage A Data ---
  final _surveyNoController = TextEditingController(text: 'Khasra 124/A');
  final _aadhaarController = TextEditingController();
  final _cropVarietyController = TextEditingController(text: 'Wheat - HD2967');
  String _irrigationType = 'Irrigated - Tube Well';
  String? _gpsCoordinates;
  String? _imgFieldOverview;

  // --- Stage B Data ---
  String _plotDimensions = '5x5';
  String _plotShape = 'Square';
  final _coordXController = TextEditingController();
  final _coordYController = TextEditingController();
  String? _imgPlotMarked;

  // --- Stage C Data ---
  final _biomassController = TextEditingController();
  final _grainWeightController = TextEditingController();
  String _threshingMethod = 'Machine Threshing';
  String? _imgHarvestPile;
  String? _imgWeighingScale;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CCE Task: ${widget.taskId}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep += 1);
            } else {
              // Submit
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CCE Data Submitted Successfully!')),
              );
              context.go('/cce-tasks');
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(_currentStep == 2 ? 'SUBMIT' : 'NEXT'),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: details.onStepCancel,
                        child: const Text('BACK'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            _buildStageA(),
            _buildStageB(),
            _buildStageC(),
          ],
        ),
      ),
    );
  }

  // --- STAGE A: Site Verification ---
  Step _buildStageA() {
    return Step(
      title: const Text('Stage A'),
      subtitle: const Text('Site Selection'),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Verification & Selection'),
          _buildTextField('Survey Number', _surveyNoController, readOnly: true),
          _buildTextField('Farmer Aadhaar Hash', _aadhaarController, hint: 'SHA-256 Hash'),
          _buildTextField('Crop Variety', _cropVarietyController),
          _buildDropdown('Irrigation Type', _irrigationType, 
            ['Rainfed', 'Irrigated - Tube Well', 'Irrigated - Canal'], 
            (val) => setState(() => _irrigationType = val!)
          ),
          const SizedBox(height: 16),
          _buildMockButton(
            label: _gpsCoordinates ?? 'Capture GPS Coordinates',
            icon: Icons.gps_fixed,
            color: _gpsCoordinates != null ? Colors.green : Colors.blue,
            onTap: () {
              setState(() => _gpsCoordinates = 'Lat: 28.45, Lng: 77.28 (Acc: 4m)');
            },
          ),
          const SizedBox(height: 12),
          _buildMockButton(
            label: _imgFieldOverview ?? 'Take Field Overview Photo',
            icon: Icons.camera_alt,
            color: _imgFieldOverview != null ? Colors.green : Colors.blue,
            onTap: () {
              setState(() => _imgFieldOverview = 'IMG_FIELD_001.jpg');
            },
          ),
        ],
      ),
    );
  }

  // --- STAGE B: Plot Marking ---
  Step _buildStageB() {
    return Step(
      title: const Text('Stage B'),
      subtitle: const Text('Plot Marking'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Randomization & Marking'),
          _buildDropdown('Plot Dimensions', _plotDimensions, 
            ['5x5', '10x5', '10x10'], 
            (val) => setState(() => _plotDimensions = val!)
          ),
          _buildDropdown('Plot Shape', _plotShape, 
            ['Square', 'Rectangle', 'Circle', 'Triangle'], 
            (val) => setState(() => _plotShape = val!)
          ),
          Row(
            children: [
              Expanded(child: _buildTextField('Random X (Steps)', _coordXController, isNumber: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('Random Y (Steps)', _coordYController, isNumber: true)),
            ],
          ),
          const SizedBox(height: 16),
          _buildMockButton(
            label: _imgPlotMarked ?? 'Capture Marked Plot',
            icon: Icons.camera_alt,
            color: _imgPlotMarked != null ? Colors.green : Colors.blue,
            onTap: () {
              setState(() => _imgPlotMarked = 'IMG_PLOT_001.jpg');
            },
          ),
        ],
      ),
    );
  }

  // --- STAGE C: Harvest ---
  Step _buildStageC() {
    return Step(
      title: const Text('Stage C'),
      subtitle: const Text('Harvesting'),
      isActive: _currentStep >= 2,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Yield Measurement'),
          _buildTextField('Biomass Weight (kg)', _biomassController, isNumber: true),
          _buildTextField('Wet Grain Weight (kg)', _grainWeightController, isNumber: true),
          _buildDropdown('Threshing Method', _threshingMethod, 
            ['Manual Beating', 'Machine Threshing'], 
            (val) => setState(() => _threshingMethod = val!)
          ),
          const SizedBox(height: 16),
          _buildMockButton(
            label: _imgHarvestPile ?? 'Photo of Cut Crop Pile',
            icon: Icons.camera_alt,
            color: _imgHarvestPile != null ? Colors.green : Colors.blue,
            onTap: () {
              setState(() => _imgHarvestPile = 'IMG_PILE_001.jpg');
            },
          ),
          const SizedBox(height: 12),
          _buildMockButton(
            label: _imgWeighingScale ?? 'Photo of Weighing Scale',
            icon: Icons.scale,
            color: _imgWeighingScale != null ? Colors.green : Colors.blue,
            onTap: () {
              setState(() => _imgWeighingScale = 'IMG_SCALE_001.jpg');
            },
          ),
        ],
      ),
    );
  }

  // --- Helpers ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, bool readOnly = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildMockButton({required String label, required IconData icon, required VoidCallback onTap, required Color color}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}