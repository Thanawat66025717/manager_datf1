import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'history_page.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({super.key});

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  static const List<String> columnNames = [
    'เลขรถ',
    'สายรถวันจันทร์-ศุกร์',
    'สายรถวันเสาร์',
    'สายรถวันอาทิตย์',
  ];

  // Route data from Firestore
  List<Map<String, dynamic>> routes = [];
  bool isLoadingRoutes = true;

  // Controllers and state
  final List<TextEditingController> controllersCol0 = List.generate(
    31,
    (_) => TextEditingController(),
  );

  final List<List<String?>> dropdownValues = List.generate(
    31,
    (_) => List.generate(4, (_) => null),
  );

  // Track which column is currently active (-1 means none)
  int activeColumn = -1;

  // Search and filter
  String searchQuery = "";
  String filterOption = "ทั้งหมด";
  final List<String> filterOptions = ["ทั้งหมด", "วิ่งได้", "วิ่งไม่ได้"];

  @override
  void initState() {
    super.initState();
    for (int i = 1; i <= 30; i++) {
      controllersCol0[i].text = i.toString().padLeft(2, '0');
    }
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('route')
          .get();
      setState(() {
        routes = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'doc_id': doc.id,
            'route_id': data['route_id'] ?? '',
            'route_name': data['route_name'] ?? '',
          };
        }).toList();
        isLoadingRoutes = false;
      });
    } catch (e) {
      setState(() {
        isLoadingRoutes = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถโหลดข้อมูลสายรถได้: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get route name from route_id
  String getRouteName(String routeId) {
    final route = routes.firstWhere(
      (r) => r['route_id'] == routeId,
      orElse: () => {'route_name': routeId},
    );
    return route['route_name'] ?? routeId;
  }

  // Get dropdown options (route_id list)
  List<String> get dropdownOptions {
    return routes.map((r) => r['route_id'] as String).toList();
  }

  // Check if a bus has any route assigned in the active column
  bool isBusActive(int row) {
    if (activeColumn == -1) return false;
    return dropdownValues[row][activeColumn + 1] != null;
  }

  // Compute summary counts - count routes based on active column
  Map<String, int> get routeCounts {
    Map<String, int> counts = {};
    for (var route in routes) {
      counts[route['route_id']] = 0;
    }
    if (activeColumn == -1) return counts;

    for (int r = 1; r <= 30; r++) {
      if (dropdownValues[r][activeColumn + 1] != null) {
        String routeId = dropdownValues[r][activeColumn + 1]!;
        counts[routeId] = (counts[routeId] ?? 0) + 1;
      }
    }
    return counts;
  }

  // Count buses that have route assigned in active column
  int get activeBusCount {
    if (activeColumn == -1) return 0;
    int count = 0;
    for (int r = 1; r <= 30; r++) {
      if (dropdownValues[r][activeColumn + 1] != null) {
        count++;
      }
    }
    return count;
  }

  // Get bus numbers for each route
  Map<String, List<String>> get busNumbersByRoute {
    Map<String, List<String>> result = {};
    for (var route in routes) {
      result[route['route_id']] = [];
    }
    if (activeColumn == -1) return result;

    for (int r = 1; r <= 30; r++) {
      if (dropdownValues[r][activeColumn + 1] != null) {
        String routeId = dropdownValues[r][activeColumn + 1]!;
        String busNumber = controllersCol0[r].text;
        result[routeId]?.add(busNumber);
      }
    }
    return result;
  }

  // Filter rows based on search and filter
  List<int> get filteredRows {
    List<int> rows = [];
    for (int r = 1; r <= 30; r++) {
      String busNumber = controllersCol0[r].text;

      // Search filter
      if (searchQuery.isNotEmpty && !busNumber.contains(searchQuery)) {
        continue;
      }

      // Status filter - based on whether bus has routes assigned
      bool isActive = isBusActive(r);
      if (filterOption == "วิ่งได้" && !isActive) {
        continue;
      }
      if (filterOption == "วิ่งไม่ได้" && isActive) {
        continue;
      }

      rows.add(r);
    }
    return rows;
  }

  // Enable column when dropdown is tapped
  void enableColumn(int col) {
    if (activeColumn != col) {
      setState(() {
        activeColumn = col;
      });
    }
  }

  // Get color for route
  Color _getRouteColor(String routeId) {
    switch (routeId.toLowerCase()) {
      case 's1':
        return Colors.blue;
      case 's2':
        return Colors.green;
      case 's3':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  Widget buildDropdown(int row, int col) {
    bool isEnabled = (activeColumn == col);

    return GestureDetector(
      onTap: () {
        enableColumn(col);
      },
      child: AbsorbPointer(
        absorbing: !isEnabled,
        child: DropdownButtonFormField<String>(
          value: dropdownValues[row][col + 1],
          isExpanded: true,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isEnabled ? Colors.purple : Colors.black45,
                width: isEnabled ? 2 : 1.5,
              ),
            ),
            filled: true,
            fillColor: isEnabled ? Colors.white : Colors.grey.shade200,
          ),
          items: routes
              .map(
                (route) => DropdownMenuItem(
                  value: route['route_id'] as String,
                  child: Text(
                    '${route['route_id']} - ${route['route_name']}',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: isEnabled
              ? (val) {
                  setState(() {
                    dropdownValues[row][col + 1] = val;
                  });
                }
              : null,
          disabledHint: dropdownValues[row][col + 1] != null
              ? Text(
                  '${dropdownValues[row][col + 1]} - ${getRouteName(dropdownValues[row][col + 1]!)}',
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                )
              : const Text(
                  "กดเพื่อเลือก",
                  style: TextStyle(color: Color(0xFF757575), fontSize: 16),
                ),
        ),
      ),
    );
  }

  void resetAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ยืนยันการรีเซ็ต',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'ต้องการล้างค่าทั้งหมดใช่หรือไม่?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                for (int r = 1; r <= 30; r++) {
                  for (int c = 1; c <= 3; c++) {
                    dropdownValues[r][c] = null;
                  }
                }
                activeColumn = -1;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('รีเซ็ตข้อมูลทั้งหมดเรียบร้อย')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'รีเซ็ต',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void saveData() {
    if (activeColumn == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกวันที่ต้องการบันทึกก่อน (คลิกที่หัวตาราง)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final busByRoute = busNumbersByRoute;

    // Prepare buses list for Firestore with route_id as foreign key
    List<Map<String, String>> busesToSave = [];
    for (int r = 1; r <= 30; r++) {
      if (dropdownValues[r][activeColumn + 1] != null) {
        busesToSave.add({
          'busNumber': controllersCol0[r].text,
          'route_id': dropdownValues[r][activeColumn + 1]!, // Foreign key
        });
      }
    }

    // Get current date and day type
    final now = DateTime.now();
    final thaiMonths = [
      '',
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    final thaiYear = now.year + 543;
    final dateString = '${now.day} ${thaiMonths[now.month]} $thaiYear';
    final dayType = columnNames[activeColumn + 1];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'ยืนยันการบันทึก',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'สรุปข้อมูลที่จะบันทึก:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'วันที่: $dateString',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ประเภท: $dayType',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Route summaries
              ...routes.map((route) {
                final routeId = route['route_id'] as String;
                final routeName = route['route_name'] as String;
                final buses = busByRoute[routeId] ?? [];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildRouteSummary(
                    '$routeId ($routeName)',
                    buses,
                    _getRouteColor(routeId),
                  ),
                );
              }),

              const Divider(height: 24),
              Text(
                'รถที่วิ่งได้: $activeBusCount คัน',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Save references before closing dialog
              final scaffoldMessenger = ScaffoldMessenger.of(this.context);

              Navigator.pop(dialogContext); // Close confirm dialog

              // Show loading using parent context
              showDialog(
                context: this.context,
                barrierDismissible: false,
                builder: (ctx) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                // Create document ID from date-time (วว-ดด-ปปปป_ชช-นน format with พ.ศ.)
                final docId =
                    '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${thaiYear}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';

                // Save to Firestore with custom document ID and route_id as foreign key
                await FirebaseFirestore.instance
                    .collection('Bus')
                    .doc(docId)
                    .set({
                      'date': dateString,
                      'dayType': dayType,
                      'timestamp': FieldValue.serverTimestamp(),
                      'buses': busesToSave, // Contains route_id as foreign key
                    });

                if (mounted) {
                  Navigator.of(this.context).pop(); // Close loading
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('บันทึกข้อมูลลง Firestore เรียบร้อย'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(this.context).pop(); // Close loading
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('เกิดข้อผิดพลาด: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              'บันทึก',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSummary(
    String route,
    List<String> busNumbers,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$route: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${busNumbers.length} เที่ยว',
                style: TextStyle(fontSize: 14, color: color),
              ),
            ],
          ),
          if (busNumbers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'เลขรถ: ${busNumbers.join(", ")}',
              style: TextStyle(
                fontSize: 12,
                color: color.withAlpha((0.8 * 255).round()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingRoutes) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'จัดการการเดินรถ',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.purple,
          toolbarHeight: 64,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.purple),
              SizedBox(height: 16),
              Text('กำลังโหลดข้อมูลสายรถ...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'จัดการการเดินรถ',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        toolbarHeight: 64,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, size: 28),
            tooltip: 'ประวัติการเดินรถ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    onChanged: (value) => setState(() => searchQuery = value),
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'ค้นหาเลขรถ...',
                      hintStyle: const TextStyle(fontSize: 16),
                      prefixIcon: const Icon(Icons.search, size: 24),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<String>(
                    value: filterOption,
                    underline: const SizedBox(),
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    icon: const Icon(Icons.filter_list, color: Colors.purple),
                    items: filterOptions
                        .map(
                          (f) => DropdownMenuItem(
                            value: f,
                            child: Text(
                              f,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => filterOption = val!),
                  ),
                ),
              ],
            ),
          ),

          // Summary Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: Column(
              children: [
                if (activeColumn >= 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'กำลังแก้ไข: ${columnNames[activeColumn + 1]}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    ...routes.map((route) {
                      final routeId = route['route_id'] as String;
                      return _buildSummaryChip(
                        '$routeId',
                        routeCounts[routeId] ?? 0,
                        _getRouteColor(routeId),
                        false,
                      );
                    }),
                    _buildSummaryChip(
                      'วิ่งได้',
                      activeBusCount,
                      Colors.purple,
                      true,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Button
          Container(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: resetAll,
              icon: const Icon(Icons.refresh, size: 22),
              label: const Text(
                'รีเซ็ต',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Table
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade400,
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Table(
                    border: TableBorder.symmetric(
                      inside: const BorderSide(color: Colors.black12),
                      outside: const BorderSide(color: Colors.black26),
                    ),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FixedColumnWidth(120),
                      1: FixedColumnWidth(220),
                      2: FixedColumnWidth(200),
                      3: FixedColumnWidth(200),
                    },
                    children: [
                      // Header
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                        ),
                        children: [
                          for (int i = 0; i < columnNames.length; i++)
                            GestureDetector(
                              onTap: i > 0 ? () => enableColumn(i - 1) : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: (i > 0 && activeColumn == i - 1)
                                      ? Colors.purple.shade200
                                      : Colors.transparent,
                                ),
                                child: Text(
                                  columnNames[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: (i > 0 && activeColumn == i - 1)
                                        ? Colors.purple.shade900
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Data Rows
                      for (int r in filteredRows)
                        TableRow(
                          decoration: BoxDecoration(
                            color: isBusActive(r)
                                ? Colors.green.shade50
                                : (r % 2 == 0
                                      ? Colors.white
                                      : Colors.grey.shade100),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: TextField(
                                controller: controllersCol0[r],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black45,
                                      width: 1.5,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                readOnly: true,
                              ),
                            ),
                            for (int c = 0; c < 3; c++)
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: buildDropdown(r, c),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: saveData,
                  icon: const Icon(Icons.save, size: 24),
                  label: const Text(
                    'บันทึก',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 18,
                    ),
                    minimumSize: const Size(160, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('โหมดแก้ไขข้อมูล')),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 24),
                  label: const Text(
                    'แก้ไข',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 18,
                    ),
                    minimumSize: const Size(160, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
    String label,
    int count,
    Color color,
    bool isBusCount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '$count ${isBusCount ? "คัน" : "เที่ยว"}',
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
