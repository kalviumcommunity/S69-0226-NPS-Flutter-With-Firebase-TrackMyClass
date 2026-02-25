import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AttendanceScreen extends StatefulWidget {
  final String className;
  final String sessionId;

  const AttendanceScreen({
    super.key,
    required this.className,
    required this.sessionId,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _attendanceMarked = false;
  List<Map<String, dynamic>> _students = [];
  Map<String, bool> _attendanceStatus =
      {}; // studentId -> true (present) / false (absent)

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Check if attendance is already marked for this session
      final sessionDoc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .get()
          .timeout(const Duration(seconds: 10));

      final data = sessionDoc.data();
      _attendanceMarked = (data?['attendanceMarked'] as bool?) ?? false;

      // 2. Fetch students for this class
      final studentsSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('class', isEqualTo: widget.className)
          .get()
          .timeout(const Duration(seconds: 10));

      List<Map<String, dynamic>> loadedStudents = [];
      Map<String, bool> loadedStatus = {};

      if (_attendanceMarked) {
        // Fetch existing attendance records
        final attendanceSnap = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .collection('attendance')
            .get()
            .timeout(const Duration(seconds: 10));

        // Create a map for quick lookup
        final attendanceMap = {
          for (var doc in attendanceSnap.docs)
            doc.id: (doc.data()['status'] as String?) == 'Present',
        };

        for (var doc in studentsSnap.docs) {
          final sData = doc.data();
          loadedStudents.add({
            'id': doc.id,
            'name': sData['name'] ?? 'Unknown',
            'rollNumber': sData['rollNumber'] ?? '',
          });
          loadedStatus[doc.id] = attendanceMap[doc.id] ?? false;
        }
      } else {
        // Attendance not marked yet, load students with default Absent
        for (var doc in studentsSnap.docs) {
          final sData = doc.data();
          loadedStudents.add({
            'id': doc.id,
            'name': sData['name'] ?? 'Unknown',
            'rollNumber': sData['rollNumber'] ?? '',
          });
          loadedStatus[doc.id] = false; // default absent
        }
      }

      // Sort by roll number if possible, or name
      loadedStudents.sort((a, b) {
        // Try parsing roll number as int for better sorting
        final rollA = int.tryParse(a['rollNumber'].toString());
        final rollB = int.tryParse(b['rollNumber'].toString());

        if (rollA != null && rollB != null) return rollA.compareTo(rollB);
        if (a['rollNumber'].toString().isNotEmpty &&
            b['rollNumber'].toString().isEmpty)
          return -1;
        if (a['rollNumber'].toString().isEmpty &&
            b['rollNumber'].toString().isNotEmpty)
          return 1;

        return a['name'].toString().compareTo(b['name'].toString());
      });

      if (mounted) {
        setState(() {
          _students = loadedStudents;
          _attendanceStatus = loadedStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _loadData,
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveAttendance() async {
    if (_students.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Write attendance records
      for (final student in _students) {
        final docRef = FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .collection('attendance')
            .doc(student['id']);

        batch.set(docRef, {
          'status': _attendanceStatus[student['id']] == true
              ? 'Present'
              : 'Absent',
          'studentName': student['name'],
          'rollNumber': student['rollNumber'],
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Update session document
      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId);

      batch.update(sessionRef, {
        'attendanceMarked': true,
        'attendanceCount': _attendanceStatus.values.where((v) => v).length,
        'totalStudents': _students.length,
      });

      await batch.commit().timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _isSaving = false;
          _attendanceMarked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully!'),
            backgroundColor: Color(0xFF4ADE80),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save attendance: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  void _showAddStudentDialog() {
    final nameCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    const accent = Color(0xFF22D3EE);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2640),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Student',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1A2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Student Name',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1A2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: TextField(
                controller: rollCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  hintText: 'Roll Number (Optional)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final roll = rollCtrl.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(ctx).pop();
                try {
                  await FirebaseFirestore.instance.collection('students').add({
                    'name': name,
                    'rollNumber': roll,
                    'class': widget.className,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  _loadData(); // reload after adding
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding student: $e')),
                    );
                  }
                }
              }
            },
            child: const Text(
              'Add',
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF0B1220);
    const backgroundBottom = Color(0xFF111A2E);
    const accent = Color(0xFF22D3EE);

    return Scaffold(
      backgroundColor: backgroundTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.className,
              style: TextStyle(
                color: accent.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (_attendanceMarked && !_isLoading && _students.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                setState(() => _attendanceMarked = false);
              },
              icon: const Icon(Icons.edit_rounded, color: accent, size: 16),
              label: const Text(
                'Edit',
                style: TextStyle(color: accent, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: accent, strokeWidth: 3),
              )
            : _students.isEmpty
            ? _buildEmptyState()
            : _buildStudentList(),
      ),
      bottomNavigationBar:
          (!_isLoading && _students.isNotEmpty && !_attendanceMarked)
          ? Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1A2E),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.07)),
                ),
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveAttendance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF0B1220),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Color(0xFF0B1220),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Attendance',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF22D3EE).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 64,
                color: Color(0xFF22D3EE),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Students Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'It looks like there are no students added to ${widget.className} yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: _showAddStudentDialog,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE).withOpacity(0.15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(
                Icons.person_add_rounded,
                color: Color(0xFF22D3EE),
              ),
              label: const Text(
                'Add Student',
                style: TextStyle(
                  color: Color(0xFF22D3EE),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        final isPresent = _attendanceStatus[student['id']] ?? false;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2640),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _attendanceMarked
                  ? (isPresent
                        ? const Color(0xFF4ADE80).withOpacity(0.3)
                        : const Color(0xFFFF6B6B).withOpacity(0.3))
                  : (isPresent
                        ? const Color(0xFF22D3EE).withOpacity(0.3)
                        : Colors.transparent),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF0F1A2E),
                child: Text(
                  student['name'][0].toUpperCase(),
                  style: TextStyle(
                    color: _attendanceMarked
                        ? (isPresent
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFFF6B6B))
                        : (isPresent
                              ? const Color(0xFF22D3EE)
                              : Colors.white.withOpacity(0.6)),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (student['rollNumber'].toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Roll: ${student['rollNumber']}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_attendanceMarked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isPresent
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFFF6B6B))
                            .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPresent ? 'Present' : 'Absent',
                    style: TextStyle(
                      color: isPresent
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFFF6B6B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Switch.adaptive(
                  value: isPresent,
                  activeColor: const Color(0xFF22D3EE),
                  activeTrackColor: const Color(0xFF22D3EE).withOpacity(0.3),
                  inactiveThumbColor: Colors.white.withOpacity(0.4),
                  inactiveTrackColor: Colors.white.withOpacity(0.1),
                  onChanged: (val) {
                    setState(() {
                      _attendanceStatus[student['id']] = val;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
