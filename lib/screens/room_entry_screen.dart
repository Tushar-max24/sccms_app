import 'package:flutter/material.dart';

class RoomEntryScreen extends StatefulWidget {
  final String selectedBlock;
  final String selectedFloor;

  RoomEntryScreen({required this.selectedBlock, required this.selectedFloor});

  @override
  _RoomEntryScreenState createState() => _RoomEntryScreenState();
}

class _RoomEntryScreenState extends State<RoomEntryScreen> {
  final roomController = TextEditingController();
  final descriptionController = TextEditingController();

  String? selectedDescription;
  final List<String> predefinedDescriptions = [
    "Overflowing Dustbin",
    "Dirty Floor",
    "Stained Walls",
    "Unclean Washroom",
    "Broken Fixtures",
    "Foul Odor",
    "Leaking Water",
    "Other (Please Specify)"
  ];

  bool isSubmitting = false;

  void submitData() {
    final room = roomController.text.trim();
    final description = descriptionController.text.trim();

    if (room.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter room number and description")),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    final fullLocation =
        "${widget.selectedBlock}, ${widget.selectedFloor}, Room $room";

    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        isSubmitting = false;
      });

      Navigator.pop(context, {
        'location': fullLocation,
        'description': description,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enter Room & Description'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Room Number Field
            TextField(
              controller: roomController,
              decoration: InputDecoration(
                labelText: 'Room Number',
                prefixIcon: Icon(Icons.room, color: Colors.deepPurple),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.deepPurple),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),

            // Description Dropdown
            DropdownButtonFormField<String>(
              value: selectedDescription,
              hint: Text("Select Predefined Issue"),
              isExpanded: true,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.report, color: Colors.deepPurple),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              items: predefinedDescriptions.map((desc) {
                return DropdownMenuItem(
                  child: Text(desc),
                  value: desc,
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedDescription = val;
                });
                if (val != "Other (Please Specify)") {
                  descriptionController.text = val!;
                } else {
                  descriptionController.clear();
                }
              },
            ),
            SizedBox(height: 10),

            // Custom Description Field
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: "Or write your own description",
                prefixIcon: Icon(Icons.edit, color: Colors.deepPurple),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: isSubmitting ? null : submitData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: isSubmitting
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                "Proceed",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
