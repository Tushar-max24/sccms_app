import 'package:flutter/material.dart';
import 'floor_selection_screen.dart';

class BlockSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<String> blocks = ['Block A', 'Block B', 'Block C', 'Block D'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Block'),
        backgroundColor: Colors.green.shade700, // Added color to make the app bar attractive
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Add padding to the body for better spacing
        child: ListView.builder(
          itemCount: blocks.length,
          itemBuilder: (context, index) {
            return Card(
              elevation: 5, // Adds shadow effect to cards
              margin: EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // Rounded corners for a modern look
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                leading: Icon(
                  Icons.location_on, // Icon to visually represent blocks
                  color: Colors.green.shade700,
                ),
                title: Text(
                  blocks[index],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                subtitle: Text(
                  'Tap to select the floor', // Added subtitle to provide more context
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FloorSelectionScreen(selectedBlock: blocks[index]),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
