import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CleaningStaffDashboard extends StatefulWidget {
  final String staffName;

  const CleaningStaffDashboard({super.key, required this.staffName});

  @override
  State<CleaningStaffDashboard> createState() => _CleaningStaffDashboardState();
}

class _CleaningStaffDashboardState extends State<CleaningStaffDashboard> {
  String userEmail = "";

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        userEmail = currentUser.email ?? "";
      });
    }
  }

  void _editReport(BuildContext context, String reportId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Edit Report", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("You can edit the report details here."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _addComment(BuildContext context, String reportId) {
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Add Comment"),
          content: TextField(
            controller: commentController,
            decoration: const InputDecoration(labelText: 'Enter your comment'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final comment = commentController.text.trim();
                if (comment.isNotEmpty) {
                  FirebaseFirestore.instance.collection('reports').doc(reportId).update({
                    'comments': FieldValue.arrayUnion([comment]),
                  }).then((_) {
                    Navigator.pop(context);
                    commentController.clear();
                  });
                }
              },
              child: const Text("Add Comment"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, ${widget.staffName}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.list),
              label: const Text("View All Cleanliness Reports"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {},
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('assignedTo', isEqualTo: userEmail)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reports = snapshot.data?.docs ?? [];

                if (reports.isEmpty) {
                  return const Center(
                    child: Text('No reports assigned to you.'),
                  );
                }

                return ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final data = report.data() as Map<String, dynamic>? ?? {};

                    final description = data['description']?.toString() ?? 'No description';
                    final location = data['location']?.toString() ?? 'Unknown location';
                    final status = data['status']?.toString() ?? 'Pending';
                    final assignedTo = data['assignedTo']?.toString() ?? 'Unassigned';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 10,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(description, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Location: $location"),
                              Text("Status: $status"),
                              Text("Assigned To: $assignedTo"),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection('reports')
                                      .doc(report.id)
                                      .update({'status': 'Resolved'});
                                },
                                child: const Text('Resolve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _editReport(context, report.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Remove the static comment button if not used
        ],
      ),
    );
  }
}
