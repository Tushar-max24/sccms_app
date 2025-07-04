import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAssignPage extends StatefulWidget {
  const AdminAssignPage({super.key});

  @override
  State<AdminAssignPage> createState() => _AdminAssignPageState();
}

class _AdminAssignPageState extends State<AdminAssignPage> {
  Map<String, int> workloadMap = {};
  String selectedStaff = '';
  List<String> staffList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAvailableStaffAndWorkload();
  }

  Future<void> fetchAvailableStaffAndWorkload() async {
    try {
      final staffSnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('isAvailable', isEqualTo: true)
          .get();

      List<String> names = [];
      for (var doc in staffSnapshot.docs) {
        final name = doc['name']?.toString() ?? 'Unnamed';
        names.add(name);
      }

      // Get workload (how many reports assigned to each staff)
      final reportsSnapshot = await FirebaseFirestore.instance.collection('reports').get();
      Map<String, int> workload = {};

      for (var report in reportsSnapshot.docs) {
        final assignedTo = report['assignedTo'] ?? '';
        if (assignedTo != '') {
          workload[assignedTo] = (workload[assignedTo] ?? 0) + 1;
        }
      }

      setState(() {
        staffList = names;
        selectedStaff = names.isNotEmpty ? names.first : '';
        workloadMap = workload;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error fetching data: $e')),
      );
    }
  }

  Future<void> _assignStaff(String docId, BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Assignment"),
        content: Text("Assign this report to $selectedStaff?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Assign"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('reports').doc(docId).update({
          'assignedTo': selectedStaff,
          'status': 'Pending',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Staff assigned successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error assigning staff: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assign Issues to Staff"),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('assignedTo', isEqualTo: '')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final unassignedReports = snapshot.data?.docs ?? [];

          if (unassignedReports.isEmpty) {
            return const Center(child: Text("🎉 No unassigned reports found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: unassignedReports.length,
            itemBuilder: (context, index) {
              final report = unassignedReports[index];
              final data = report.data() as Map<String, dynamic>;
              final description = data['description'] ?? 'No description';
              final location = data['location'] ?? 'Unknown location';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("📝 $description", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("📍 Location: $location"),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: selectedStaff,
                        isExpanded: true,
                        items: staffList.map((name) {
                          final workload = workloadMap[name] ?? 0;
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text("$name (${workload} tasks)"),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedStaff = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _assignStaff(report.id, context),
                        icon: const Icon(Icons.assignment_ind),
                        label: const Text("Assign Staff"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
