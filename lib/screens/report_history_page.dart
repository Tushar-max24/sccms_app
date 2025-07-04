import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportHistoryPage extends StatefulWidget {
  final bool isAdmin;
  const ReportHistoryPage({super.key, required this.isAdmin});

  @override
  State<ReportHistoryPage> createState() => _ReportHistoryPageState();
}

class _ReportHistoryPageState extends State<ReportHistoryPage> {
  final user = FirebaseAuth.instance.currentUser;
  String? selectedStatus;
  String searchQuery = "";
  DateTimeRange? selectedDateRange;

  List<String> statuses = ['Pending', 'Resolved'];

  @override
  Widget build(BuildContext context) {
    final reportsRef = FirebaseFirestore.instance.collection('reports');

    Query query = reportsRef;

    if (!widget.isAdmin && user != null) {
      query = query.where('userID', isEqualTo: user!.uid);
    }

    if (widget.isAdmin && selectedStatus != null) {
      query = query.where('status', isEqualTo: selectedStatus);
    }

    if (selectedDateRange != null) {
      query = query
          .where('timestamp', isGreaterThanOrEqualTo: selectedDateRange!.start)
          .where('timestamp', isLessThanOrEqualTo: selectedDateRange!.end);
    }

    query = query.orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Reports'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Download PDF",
            onPressed: () async {
              final snapshot = await query.get();
              final filteredReports = snapshot.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['description'] ?? '').toString().toLowerCase().contains(searchQuery) ||
                    (data['location'] ?? '').toString().toLowerCase().contains(searchQuery) ||
                    (data['status'] ?? '').toString().toLowerCase().contains(searchQuery);
              }).toList();

              final pdf = await generatePDF(filteredReports);
              await Printing.layoutPdf(onLayout: (format) => pdf.save());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DropdownButton<String>(
                      hint: const Text('Status'),
                      value: selectedStatus,
                      items: statuses
                          .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                          .toList(),
                      onChanged: (value) => setState(() => selectedStatus = value),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: () async {
                        final DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                          initialDateRange: selectedDateRange,
                          currentDate: DateTime.now(),
                        );
                        if (picked != null && picked != selectedDateRange) {
                          setState(() {
                            selectedDateRange = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(selectedDateRange == null
                          ? "Select Date Range"
                          : DateFormat('dd MMM yyyy').format(selectedDateRange!.start) +
                          ' - ' +
                          DateFormat('dd MMM yyyy').format(selectedDateRange!.end)),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedStatus = null;
                          selectedDateRange = null;
                        });
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text("Clear Filters"),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: '🔍 Search description/location/status...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              onChanged: (value) {
                setState(() => searchQuery = value.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong.'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('No reports found.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final filteredReports = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['description'] ?? '').toString().toLowerCase().contains(searchQuery) ||
                      (data['location'] ?? '').toString().toLowerCase().contains(searchQuery) ||
                      (data['status'] ?? '').toString().toLowerCase().contains(searchQuery);
                }).toList();

                if (filteredReports.isEmpty) {
                  return const Center(child: Text('No matching reports.'));
                }

                return ListView.builder(
                  itemCount: filteredReports.length,
                  itemBuilder: (context, index) {
                    final report = filteredReports[index];
                    final data = report.data() as Map<String, dynamic>;

                    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a')
                        .format((data['timestamp'] as Timestamp).toDate());

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Icon(
                          data['status'] == 'Resolved'
                              ? Icons.check_circle_outline
                              : Icons.pending_actions,
                          color: data['status'] == 'Resolved' ? Colors.green : Colors.orange,
                          size: 35,
                        ),
                        title: Text(
                          "${data['description']} (${data['status']})",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          "Location: ${data['location']}\n$formattedDate",
                          style: const TextStyle(color: Colors.black54),
                        ),
                        isThreeLine: true,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text(data['description'] ?? 'No Title'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Location: ${data['location']}"),
                                    Text("Status: ${data['status']}"),
                                    Text("Reported at: $formattedDate"),
                                    const SizedBox(height: 10),
                                    if (data['imageURL'] != null)
                                      Image.network(data['imageURL']),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text("Close"),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<pw.Document> generatePDF(List<QueryDocumentSnapshot> reports) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoExtraLight();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Text("Report History", style: pw.TextStyle(font: font, fontSize: 24)),
          pw.SizedBox(height: 20),
          ...reports.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp).toDate();
            final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Description: ${data['description']}"),
                  pw.Text("Location: ${data['location']}"),
                  pw.Text("Status: ${data['status']}"),
                  pw.Text("Date: $formattedDate"),
                  pw.Divider(),
                ],
              ),
            );
          }),
        ],
      ),
    );
    return pdf;
  }
}
