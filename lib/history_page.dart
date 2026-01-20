import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, Map<String, dynamic>> routesMap = {};

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final snapshot = await _firestore.collection('route').get();
      setState(() {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final routeId = data['route_id']?.toString().toLowerCase() ?? '';
          routesMap[routeId] = {
            'route_id': data['route_id'] ?? '',
            'route_name': data['route_name'] ?? '',
          };
        }
      });
    } catch (e) {
      debugPrint('Error loading routes: $e');
    }
  }

  String getRouteName(String routeId) {
    final route = routesMap[routeId.toLowerCase()];
    if (route != null) {
      return route['route_name'] ?? routeId;
    }
    return routeId;
  }

  Color _getRouteColor(String routeId) {
    switch (routeId.toLowerCase()) {
      case 's1':
        return Colors.blue;
      case 's2':
        return Colors.green;
      case 's3':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _deleteHistory(String docId, String date) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบประวัติวันที่ $date ใช่หรือไม่?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'ลบ',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('Bus').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบประวัติเรียบร้อย'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editHistory(String docId, Map<String, dynamic> data) async {
    final buses = List<Map<String, dynamic>>.from(
      (data['buses'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? [],
    );

    // Get available route options
    final routeOptions = routesMap.values.toList();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              'แก้ไขประวัติ ${data['date'] ?? ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...buses.asMap().entries.map((entry) {
                      final busIndex = entry.key;
                      final bus = entry.value;
                      final currentRouteId =
                          bus['route_id']?.toString().toLowerCase() ??
                          bus['route']?.toString().toLowerCase() ??
                          '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'รถ ${bus['busNumber']}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DropdownButton<String>(
                              value:
                                  routeOptions.any(
                                    (r) =>
                                        r['route_id']
                                            .toString()
                                            .toLowerCase() ==
                                        currentRouteId,
                                  )
                                  ? currentRouteId
                                  : (routeOptions.isNotEmpty
                                        ? routeOptions.first['route_id']
                                              .toString()
                                              .toLowerCase()
                                        : null),
                              items: routeOptions
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r['route_id']
                                          .toString()
                                          .toLowerCase(),
                                      child: Text(
                                        '${r['route_id']} - ${r['route_name']}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setDialogState(() {
                                  buses[busIndex]['route_id'] = val;
                                  buses[busIndex].remove(
                                    'route',
                                  ); // Remove old field if exists
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setDialogState(() {
                                  buses.removeAt(busIndex);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ยกเลิก', style: TextStyle(fontSize: 16)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _firestore.collection('Bus').doc(docId).update({
                    'buses': buses,
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('แก้ไขประวัติเรียบร้อย'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text(
                  'บันทึก',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ประวัติการเดินรถ',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        toolbarHeight: 64,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('Bus')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'เกิดข้อผิดพลาด: ${snapshot.error}',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.purple),
                  SizedBox(height: 16),
                  Text(
                    'กำลังโหลดข้อมูล...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'ไม่มีประวัติการเดินรถ',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final docId = doc.id;
              final data = doc.data() as Map<String, dynamic>;
              final buses = data['buses'] as List? ?? [];

              // Group buses by route_id
              final Map<String, List<String>> busesByRoute = {};
              for (var bus in buses) {
                // Support both 'route_id' (new) and 'route' (old) fields
                final routeId =
                    (bus['route_id'] ?? bus['route'])
                        ?.toString()
                        .toLowerCase() ??
                    'unknown';
                busesByRoute.putIfAbsent(routeId, () => []);
                busesByRoute[routeId]!.add(bus['busNumber']?.toString() ?? '');
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Header
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.purple,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['date']?.toString() ?? 'ไม่ระบุวันที่',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  data['dayType']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${buses.length} คัน',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 24),

                      // Route Summary
                      ...busesByRoute.entries.map((entry) {
                        final routeId = entry.key;
                        final busNumbers = entry.value;
                        final color = _getRouteColor(routeId);
                        final routeName = getRouteName(routeId);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color, width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  routeId.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      routeName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: busNumbers.map((busNum) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: color.withAlpha(128),
                                            ),
                                          ),
                                          child: Text(
                                            'รถ $busNum',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: color,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Action Buttons
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _editHistory(docId, data),
                            icon: const Icon(Icons.edit, size: 20),
                            label: const Text(
                              'แก้ไข',
                              style: TextStyle(fontSize: 14),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _deleteHistory(
                              docId,
                              data['date']?.toString() ?? '',
                            ),
                            icon: const Icon(Icons.delete, size: 20),
                            label: const Text(
                              'ลบ',
                              style: TextStyle(fontSize: 14),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
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
    );
  }
}
