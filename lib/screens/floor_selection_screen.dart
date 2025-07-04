import 'package:flutter/material.dart';
import 'room_entry_screen.dart';

class FloorSelectionScreen extends StatelessWidget {
  final String selectedBlock;

  FloorSelectionScreen({required this.selectedBlock});

  @override
  Widget build(BuildContext context) {
    final List<String> floors = ['Floor 1', 'Floor 2', 'Floor 3', 'Floor 4'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Floor'),
        backgroundColor: Colors.blue, // Make the app bar more visually appealing
      ),
      body: ListView.builder(
        itemCount: floors.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: Icon(Icons.meeting_room), // Add an icon for each floor
            title: Text(
              floors[index],
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), // Improve text style
            ),
            tileColor: index % 2 == 0 ? Colors.blue[50] : Colors.white, // Alternate tile color for better visibility
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RoomEntryScreen(
                    selectedBlock: selectedBlock,
                    selectedFloor: floors[index],
                  ),
                ),
              );
            },
            contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Add padding for better spacing
          );
        },
      ),
    );
  }
}
