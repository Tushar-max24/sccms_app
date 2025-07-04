import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QRCodeScanner extends StatefulWidget {
  const QRCodeScanner({super.key});

  @override
  State<QRCodeScanner> createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends State<QRCodeScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String _qrText = '';
  bool _isScanned = false;

  File? _capturedImage;
  String? _selectedReportType;
  String? _reportDescription;
  bool _isFormReady = false;

  final List<String> staffList = [
    'staff1@gmail.com',
    'staff2@gmail.com',
    'staff3@gmail.com',
  ];

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRScanned(String data) {
    setState(() {
      _qrText = data;
      _isScanned = true;
    });
    _showOptionsDialog();
  }

  void _showOptionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Select Option"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Capture Image"),
              onTap: _captureImage,
            ),
            ListTile(
              title: const Text("Select Report Type"),
              onTap: _selectReportType,
            ),
            ListTile(
              title: const Text("Add Description"),
              onTap: _addDescription,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    Navigator.pop(context);

    if (image != null) {
      setState(() {
        _capturedImage = File(image.path);
      });
    }

    _checkNextStep();
  }

  void _selectReportType() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Report Type"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Cleaning"),
              onTap: () => _selectType("Cleaning"),
            ),
            ListTile(
              title: const Text("Maintenance"),
              onTap: () => _selectType("Maintenance"),
            ),
            ListTile(
              title: const Text("Other"),
              onTap: () => _selectType("Other"),
            ),
          ],
        ),
      ),
    );
  }

  void _addDescription() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Description"),
        content: TextField(
          onChanged: (value) {
            setState(() {
              _reportDescription = value;
            });
          },
          decoration: const InputDecoration(
            hintText: "Enter detailed description of the issue",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkNextStep();
            },
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  void _selectType(String type) {
    Navigator.pop(context);
    Navigator.pop(context);

    setState(() {
      _selectedReportType = type;
    });

    _checkNextStep();
  }

  void _checkNextStep() {
    if (_capturedImage == null || _selectedReportType == null || _reportDescription == null) {
      Future.delayed(const Duration(milliseconds: 300), _showOptionsDialog);
    } else {
      setState(() {
        _isFormReady = true;
      });
    }
  }

  Future<String> uploadToCloudinary(File imageFile) async {
    String cloudName = "dmgjcryx6"; // Replace with your Cloudinary cloud name
    String uploadPreset = "flutter_unsigned_upload"; // Your unsigned preset

    final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);
      if (jsonData.containsKey('secure_url')) {
        return jsonData['secure_url'];
      } else {
        throw Exception("Cloudinary upload failed - secure_url missing");
      }
    } else {
      throw Exception("Cloudinary upload failed. Status code: ${response.statusCode}");
    }
  }

  Future<void> _submitReport() async {
    if (_capturedImage != null && _selectedReportType != null && _reportDescription != null) {
      try {
        final imageUrl = await uploadToCloudinary(_capturedImage!);
        final user = FirebaseAuth.instance.currentUser;

        // Randomly assign a staff member
        final assignedTo = staffList[Random().nextInt(staffList.length)];

        // Add to 'reports' collection only
        await FirebaseFirestore.instance.collection('reports').add({
          'userID': user?.uid,
          'assignedTo': assignedTo,
          'location': _qrText,
          'description': _reportDescription,
          'reportType': _selectedReportType,
          'imageURL': imageUrl,
          'status': 'Pending',
          'timestamp': Timestamp.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report submitted and assigned to $assignedTo')),
        );

        // Reset state
        setState(() {
          _qrText = '';
          _isScanned = false;
          _capturedImage = null;
          _selectedReportType = null;
          _reportDescription = null;
          _isFormReady = false;
        });

        controller?.resumeCamera();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SafeArea(
        child: _isFormReady ? _buildFormScreen() : _buildScannerScreen(),
      ),
    );
  }

  Widget _buildScannerScreen() {
    return Column(
      children: [
        if (_isScanned)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Scanned QR Code: $_qrText',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        Expanded(
          child: QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.blue,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 300,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Location:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(_qrText),
          const SizedBox(height: 20),
          if (_capturedImage != null) ...[
            const Text('Captured Image:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Image.file(_capturedImage!, height: 200),
            const SizedBox(height: 20),
          ],
          if (_selectedReportType != null) ...[
            const Text('Report Type:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(_selectedReportType!),
            const SizedBox(height: 20),
          ],
          if (_reportDescription != null) ...[
            const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(_reportDescription!),
            const SizedBox(height: 20),
          ],
          Center(
            child: ElevatedButton(
              onPressed: _submitReport,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('Submit Report'),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!_isScanned) {
        _onQRScanned(scanData.code!);
      }
    });
  }
}
