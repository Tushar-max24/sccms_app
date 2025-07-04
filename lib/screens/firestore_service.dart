import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  // Fetch staff list from Firestore
  Future<List<String>> getStaffList() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('staff').get();
    return snapshot.docs.map((doc) => doc['uid'] as String).toList();
  }

  // Fetch the last assigned index
  Future<int> getLastAssignedIndex() async {
    final doc = await FirebaseFirestore.instance.collection('config').doc('lastAssigned').get();
    return doc.exists ? doc['index'] : -1;
  }

  // Assign a report to the next staff member (Round Robin)
  Future<void> assignReportToStaff(Map<String, dynamic> reportData) async {
    // Step 1: Get the list of staff members (UIDs)
    List<String> staffList = await getStaffList();

    // Step 2: Get the last assigned index
    int lastIndex = await getLastAssignedIndex();

    // Step 3: Calculate the next staff index using Round Robin logic
    int nextIndex = (lastIndex + 1) % staffList.length;

    // Step 4: Get the UID of the next staff member
    String assignedStaffUID = staffList[nextIndex];

    // Step 5: Add the assigned staff UID to the report data
    reportData['assignedTo'] = assignedStaffUID;

    // Step 6: Save the report to Firestore
    await FirebaseFirestore.instance.collection('reports').add(reportData);

    // Step 7: Update the last assigned index in Firestore
    await FirebaseFirestore.instance.collection('config').doc('lastAssigned').set({'index': nextIndex});
  }

  // Fetch reports assigned to a specific staff member
  Future<List<DocumentSnapshot>> getReportsForStaff(String staffUID) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('reports')
        .where('assignedTo', isEqualTo: staffUID)
        .get();

    return snapshot.docs;
  }
}
