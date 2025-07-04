import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WasteDetector extends StatefulWidget {
  const WasteDetector({Key? key}) : super(key: key);

  @override
  State<WasteDetector> createState() => _WasteDetectorState();
}

class _WasteDetectorState extends State<WasteDetector> {
  File? _imageFile;
  String? _resultLabel;
  double? _confidence;
  bool _loading = false;
  String? _selectedLocation;
  String? _description;

  final List<String> _blocks = ['Block A', 'Block B', 'Block C', 'Block D'];
  final List<String> _floors = ['Ground Floor', '1st Floor', '2nd Floor', '3rd Floor', '4th Floor'];
  final List<String> _staffList = ['staff1@gmail.com', 'staff2@gmail.com', 'staff3@gmail.com'];
  int _currentStaffIndex = 0;

  final String apiKey = "sgvrAK877jLBCjCEAjep";
  final String modelId = "sccmsapp/8";

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _loading = true;
        _resultLabel = null;
        _confidence = null;
      });

      try {
        final result = await _detectWaste(_imageFile!);
        setState(() {
          _resultLabel = result['label'];
          _confidence = result['confidence'];
          _loading = false;
        });
      } catch (e) {
        setState(() {
          _resultLabel = "Error: ${e.toString()}";
          _confidence = 0.0;
          _loading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _detectWaste(File imageFile) async {
    final url = Uri.parse("https://serverless.roboflow.com/$modelId?api_key=$apiKey");

    var request = http.MultipartRequest('POST', url);
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
      contentType: MediaType('image', 'jpeg'),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse["predictions"] != null && jsonResponse["predictions"].isNotEmpty) {
        final prediction = jsonResponse["predictions"][0];
        return {
          "label": prediction["class"],
          "confidence": prediction["confidence"],
        };
      } else {
        return {
          "label": "No object detected",
          "confidence": 0.0,
        };
      }
    } else {
      throw Exception("Failed to detect waste: ${response.body}");
    }
  }

  String _getNextStaff() {
    final staff = _staffList[_currentStaffIndex];
    _currentStaffIndex = (_currentStaffIndex + 1) % _staffList.length;
    return staff;
  }

  Future<String> uploadToCloudinary(File imageFile) async {
    String cloudName = "dmgjcryx6";
    String uploadPreset = "flutter_unsigned_upload";

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

  Future<void> _showLocationPopup() async {
    String? selectedBlock = _blocks[0];
    String? selectedFloor = _floors[0];
    String? roomNumber;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Location"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Select Block"),
                value: selectedBlock,
                items: _blocks.map((block) {
                  return DropdownMenuItem(value: block, child: Text(block));
                }).toList(),
                onChanged: (value) {
                  selectedBlock = value!;
                },
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Select Floor"),
                value: selectedFloor,
                items: _floors.map((floor) {
                  return DropdownMenuItem(value: floor, child: Text(floor));
                }).toList(),
                onChanged: (value) {
                  selectedFloor = value!;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "Room Number"),
                onChanged: (value) {
                  roomNumber = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (selectedBlock != null &&
                    selectedFloor != null &&
                    roomNumber != null &&
                    roomNumber!.isNotEmpty) {
                  setState(() {
                    _selectedLocation = "$selectedBlock - $selectedFloor - Room $roomNumber";
                  });
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please complete all fields")),
                  );
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitReport() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image")),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select location")),
      );
      return;
    }

    if (_resultLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please detect waste before submitting")),
      );
      return;
    }

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    String imageUrl;
    try {
      imageUrl = await uploadToCloudinary(_imageFile!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image upload failed: ${e.toString()}")),
      );
      return;
    }

    String uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    String assignedStaff = _getNextStaff();

    await FirebaseFirestore.instance.collection('reports').add({
      'userID': uid,
      'waste_type': _resultLabel,
      'confidence': _confidence,
      'location': _selectedLocation,
      'description': _description,
      'image_url': imageUrl,
      'status': 'pending',
      'assignedTo': assignedStaff,
      'timestamp': Timestamp.now(),
      'date_time': formattedDate,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report submitted and assigned to $assignedStaff')),
    );

    setState(() {
      _imageFile = null;
      _resultLabel = null;
      _confidence = null;
      _selectedLocation = null;
      _description = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Waste Detector"),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 👇 Banner at the top
                Image.asset(
                  'assets/images/dust_detector.png',
                  height: 180,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.image),
                  label: const Text("Pick Image"),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Capture Photo"),
                ),
                const SizedBox(height: 20),
                if (_loading) const CircularProgressIndicator(),
                if (_imageFile != null) ...[
                  Image.file(_imageFile!, height: 200),
                  const SizedBox(height: 16),
                  if (_resultLabel != null)
                    Column(
                      children: [
                        Text(
                          "Label: $_resultLabel\nConfidence: ${(_confidence! * 100).toStringAsFixed(2)}%",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showLocationPopup,
                          icon: const Icon(Icons.location_on),
                          label: Text(_selectedLocation ?? "Select Location"),
                        ),
                        TextFormField(
                          decoration: const InputDecoration(labelText: "Description (optional)"),
                          onChanged: (value) {
                            _description = value;
                          },
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _submitReport,
                          icon: const Icon(Icons.send),
                          label: const Text("Submit Report"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
