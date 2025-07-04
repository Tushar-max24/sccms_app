import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ViewReportsScreen extends StatefulWidget {
  @override
  _ViewReportsScreenState createState() => _ViewReportsScreenState();
}

class _ViewReportsScreenState extends State<ViewReportsScreen> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  String filterStatus = 'All';
  String searchQuery = '';

  final List<String> statusOptions = ['Pending', 'In Progress', 'Resolved'];

  String formatTimestamp(Timestamp timestamp) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
  }

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

  void updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(docId)
        .update({'status': newStatus});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status updated to "$newStatus"')),
    );
  }

  void deleteReport(BuildContext context, String docId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Report"),
        content: Text("Are you sure you want to delete this report?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('reports').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Report deleted")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Reported Issues"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () async {
              final result = await showSearch<String>(
                context: context,
                delegate: ReportSearchDelegate(),
              );
              if (result != null) {
                setState(() {
                  searchQuery = result;
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(15),
            child: DropdownButton<String>(
              value: filterStatus,
              onChanged: (value) {
                setState(() {
                  filterStatus = value!;
                });
              },
              style: TextStyle(color: Colors.deepPurple, fontSize: 16),
              iconEnabledColor: Colors.deepPurple,
              items: ['All', 'Pending', 'In Progress', 'Resolved']
                  .map((status) => DropdownMenuItem(
                value: status,
                child: Text(status),
              ))
                  .toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("reports")
                  .where("userID", isEqualTo: uid)
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text("Something went wrong."));
                if (snapshot.connectionState == ConnectionState.waiting)
                  return Center(child: CircularProgressIndicator());

                final filteredData = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final status = (data['status'] ?? '').toString();
                  final location = (data['location'] ?? '').toString();
                  final description = (data['description'] ?? '').toString();

                  final matchesStatus = filterStatus == 'All' ||
                      status.toLowerCase() == filterStatus.toLowerCase();
                  final matchesQuery = location
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()) ||
                      description
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase());

                  return matchesStatus && matchesQuery;
                }).toList();

                if (filteredData.isEmpty)
                  return Center(child: Text("No reports found."));

                return ListView.builder(
                  itemCount: filteredData.length,
                  itemBuilder: (context, index) {
                    final report = filteredData[index];
                    final data = report.data() as Map<String, dynamic>;

                    final imageUrl = data['imageURL'] ?? '';
                    final location = data['location'] ?? 'No Location';
                    final description = data['description'] ?? 'No Description';
                    final rawStatus = data['status'] ?? 'Pending';
                    final timestamp = data['timestamp'] as Timestamp;
                    final docId = report.id;

                    // Normalize the status for dropdown
                    final currentStatus = statusOptions.firstWhere(
                          (s) =>
                      s.toLowerCase() ==
                          rawStatus.toString().toLowerCase(),
                      orElse: () => statusOptions[0],
                    );

                    return Card(
                      elevation: 5,
                      margin:
                      EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(imageUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover)
                                      : Icon(Icons.image, size: 80),
                                ),
                                SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(location,
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      SizedBox(height: 6),
                                      Text(description,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () =>
                                      deleteReport(context, docId),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                DropdownButton<String>(
                                  value: currentStatus,
                                  onChanged: (newStatus) {
                                    if (newStatus != null) {
                                      updateStatus(docId, newStatus);
                                    }
                                  },
                                  items: statusOptions.map((status) {
                                    return DropdownMenuItem<String>(
                                      value: status,
                                      child: Text(status),
                                    );
                                  }).toList(),
                                  dropdownColor: Colors.white,
                                  iconEnabledColor:
                                  getStatusColor(currentStatus),
                                  style: TextStyle(
                                    color: getStatusColor(currentStatus),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(formatTimestamp(timestamp),
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to report submission screen
        },
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class ReportSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return ListTile(
      title: Text("Search result for '$query'"),
      onTap: () => close(context, query),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ListTile(
      title: Text("Suggested result for '$query'"),
      onTap: () => close(context, query),
    );
  }
}
