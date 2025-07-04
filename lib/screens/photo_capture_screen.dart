import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhotoCaptureScreen extends StatefulWidget {
  final String location;

  PhotoCaptureScreen({required this.location});

  @override
  _PhotoCaptureScreenState createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  File? _image;
  final picker = ImagePicker();
  bool isLoading = false;
  String? _reportDescription;

  final List<String> reportDescriptions = [
    'Trash Overflow',
    'Broken Furniture',
    'Unclean Area',
    'Water Leakage',
    'Other',
  ];

  Future<void> _getImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String> uploadImageToCloudinary(File imageFile) async {
    String cloudinaryUrl = 'https://api.cloudinary.com/v1_1/YOUR_CLOUD_NAME/image/upload';
    String uploadPreset = 'flutter_unsigned_upload'; // (From your Cloudinary settings)

    final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final respData = await response.stream.bytesToString();
      final jsonResp = json.decode(respData);
      return jsonResp['secure_url']; // Get the uploaded image URL
    } else {
      throw Exception('Failed to upload image to Cloudinary');
    }
  }

  Future<void> _submitReport() async {
    if (_image == null || _reportDescription == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please capture an image and select a report type.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Upload to Cloudinary
      String photoUrl = await uploadImageToCloudinary(_image!);

      // Save report to Firestore
      await FirebaseFirestore.instance.collection('reports').add({
        'location': widget.location,
        'photoUrl': photoUrl,
        'description': _reportDescription,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report submitted successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report.')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showDescriptionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Select Report Description'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: reportDescriptions
                .map((description) => RadioListTile<String>(
              title: Text(description),
              value: description,
              groupValue: _reportDescription,
              onChanged: (value) {
                setState(() {
                  _reportDescription = value;
                });
                Navigator.pop(context);
              },
            ))
                .toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Capture Wastage Photo'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _image == null
                ? GestureDetector(
              onTap: _getImage,
              child: Container(
                height: 200,
                width: 200,
                color: Colors.grey[300],
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.file(
                _image!,
                height: 200,
                width: 200,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _getImage,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Capture Photo',
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showDescriptionDialog,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _reportDescription == null
                    ? 'Select Report Description'
                    : 'Selected: $_reportDescription',
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitReport,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? CircularProgressIndicator()
                  : Text('Submit Report', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
