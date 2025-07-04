import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'room_entry_screen.dart';
import 'firestore_service.dart';

class ReportIssueScreen extends StatefulWidget {
  final String? prefilledLocation;

  const ReportIssueScreen({super.key, this.prefilledLocation});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();
  File? _image;
  String? _currentLocation;
  final FirestoreService firestoreService = FirestoreService();

  final List<String> staffList = [
    'staff1@gmail.com',
    'staff2@gmail.com',
    'staff3@gmail.com',
  ];
  int _currentStaffIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledLocation != null) {
      locationController.text = widget.prefilledLocation!;
    }
  }

  Future pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future capturePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location services are disabled")),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location permissions are permanently denied")),
      );
      return;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location permissions are denied")),
        );
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLocation = "Lat: ${position.latitude}, Long: ${position.longitude}";
      locationController.text = _currentLocation!;
    });
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

  String getNextStaff() {
    final staff = staffList[_currentStaffIndex];
    _currentStaffIndex = (_currentStaffIndex + 1) % staffList.length;
    return staff;
  }

  Future uploadReport() async {
    if (_image == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please select an image")));
      return;
    }

    if (locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please select a location")));
      return;
    }

    String uid = FirebaseAuth.instance.currentUser!.uid;
    String imageURL = await uploadToCloudinary(_image!);
    String assignedStaff = getNextStaff();

    await FirebaseFirestore.instance.collection("reports").add({
      "userID": uid,
      "location": locationController.text,
      "description": descriptionController.text,
      "imageURL": imageURL,
      "status": "pending",
      "assignedTo": assignedStaff,
      "timestamp": Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Report submitted and assigned to $assignedStaff")),
    );

    locationController.clear();
    descriptionController.clear();
    setState(() => _image = null);
  }

  Future<void> showBlockFloorDialog() async {
    String? selectedBlock;
    String? selectedFloor;

    final blockOptions = ['Block A', 'Block B', 'Block C'];
    final floorOptions = ['Ground Floor', '1st Floor', '2nd Floor', '3rd Floor'];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Select Block & Floor"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Block'),
                items: blockOptions.map((block) {
                  return DropdownMenuItem(value: block, child: Text(block));
                }).toList(),
                onChanged: (val) => selectedBlock = val,
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Floor'),
                items: floorOptions.map((floor) {
                  return DropdownMenuItem(value: floor, child: Text(floor));
                }).toList(),
                onChanged: (val) => selectedFloor = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedBlock != null && selectedFloor != null) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoomEntryScreen(
                        selectedBlock: selectedBlock!,
                        selectedFloor: selectedFloor!,
                      ),
                    ),
                  ).then((result) {
                    if (result != null) {
                      setState(() {
                        locationController.text = result['location'];
                        descriptionController.text = result['description'];
                      });
                    }
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please select both Block & Floor")),
                  );
                }
              },
              child: Text("Proceed"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Report Cleanliness Issue")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: locationController,
                readOnly: true,
                decoration: InputDecoration(labelText: "Location"),
              ),
              TextField(
                controller: descriptionController,
                readOnly: true,
                decoration: InputDecoration(labelText: "Description"),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: showBlockFloorDialog,
                child: Text("Select Block & Floor"),
              ),
              ElevatedButton(
                onPressed: getCurrentLocation,
                child: Text("Use Current Location"),
              ),
              SizedBox(height: 10),
              _image != null
                  ? Image.file(_image!, height: 150)
                  : Text("No image selected"),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(onPressed: pickImage, child: Text("Pick Image")),
                  ElevatedButton(onPressed: capturePhoto, child: Text("Capture Photo")),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(onPressed: uploadReport, child: Text("Submit Report")),
            ],
          ),
        ),
      ),
    );
  }
}
