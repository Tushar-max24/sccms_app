import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final List<String> statusOptions = ['Pending', 'In Progress', 'Resolved'];

  // Get color based on status
  Color getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'In Progress':
        return Colors.blue;
      case 'Resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Update status in Firestore
  void updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(docId)
        .update({'status': newStatus});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status updated to "$newStatus"')),
    );
  }

  // Handle back button
  Future<bool> _onWillPop() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen(role: 'admin')),
    );
    return false;
  }

  // Build the comments section for each report
  Widget _buildCommentsSection(String reportId) {
    final TextEditingController commentController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Text("Comments:", style: TextStyle(fontWeight: FontWeight.bold)),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .doc(reportId)
              .collection('comments')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text("Loading comments...");

            final comments = snapshot.data!.docs;

            return Column(
              children: comments.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final text = data['text'] ?? '';
                final addedBy = data['addedBy'] ?? 'Admin';
                final timestamp = data['timestamp'] != null
                    ? (data['timestamp'] as Timestamp).toDate()
                    : DateTime.now();

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                  child: ListTile(
                    title: Text(text),
                    subtitle: Text("By $addedBy • ${timestamp.toLocal()}"),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: "Add a comment...",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              onPressed: () async {
                final comment = commentController.text.trim();
                if (comment.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('reports')
                      .doc(reportId)
                      .collection('comments')
                      .add({
                    'text': comment,
                    'addedBy': 'Admin',
                    'timestamp': Timestamp.now(),
                  });
                  commentController.clear();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Dashboard"),
          backgroundColor: Colors.redAccent,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen(role: 'admin')),
              );
            },
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("reports").snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text("Something went wrong!"));
            }

            final reports = snapshot.data!.docs;

            if (reports.isEmpty) {
              return const Center(child: Text("No reports found."));
            }

            return ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                final data = report.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'Pending';
                final dropdownValue = statusOptions.contains(status) ? status : statusOptions[0];
                final userName = data['userName'] ?? 'User';
                final userImage = data['userImageUrl'];
                final location = data['location'] ?? 'Unknown location';
                final description = data['description'] ?? 'No description';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Info
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: userImage != null
                                  ? NetworkImage(userImage)
                                  : const AssetImage('assets/user_placeholder.png') as ImageProvider,
                              radius: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              userName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Report Info
                        Text("Location: $location", style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                        const SizedBox(height: 4),
                        Text("Description: $description", style: TextStyle(fontSize: 14, color: Colors.grey[700])),

                        const SizedBox(height: 12),

                        // Status & Dropdown
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Chip(
                              label: Text(status),
                              backgroundColor: getStatusColor(status).withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: getStatusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            DropdownButton<String>(
                              value: dropdownValue,
                              underline: Container(height: 1, color: Colors.grey),
                              items: statusOptions.map((value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null && newValue != status) {
                                  updateStatus(report.id, newValue);
                                }
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Comments
                        _buildCommentsSection(report.id),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
