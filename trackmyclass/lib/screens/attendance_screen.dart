import 'dart:async';
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
  Map<String, bool> _attendanceStatus = {};
  StreamSubscription<QuerySnapshot>? _studentsSub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. Subscribe to students stream — shows data as soon as it arrives
    _studentsSub = FirebaseFirestore.instance
        .collection('students')
        .where('class', isEqualTo: widget.className)
        .snapshots()
        .listen(
          (studentsSnap) {
            List<Map<String, dynamic>> loadedStudents = [];

            for (var doc in studentsSnap.docs) {
              final sData = doc.data();
              loadedStudents.add({
                'id': doc.id,
                'name': sData['name'] ?? 'Unknown',
                'rollNumber': sData['rollNumber'] ?? '',
              });

              // Default absent if no status yet
              if (!_attendanceStatus.containsKey(doc.id)) {
                _attendanceStatus[doc.id] = false;
              }
            }

            // Sort by roll number if possible, or name
            loadedStudents.sort((a, b) {
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
                _isLoading = false; // Show UI immediately
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error syncing data: $error')),
              );
            }
          },
        );

    // 2. Fetch session/attendance data in background (non-blocking)
    //    When it arrives, merge attendance status into the UI.
    _loadSessionData();
  }

  /// Loads session + attendance data in background and merges into UI.
  Future<void> _loadSessionData() async {
    try {
      // Fetch session doc + attendance records in parallel — faster load
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .get(),
        FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .collection('attendance')
            .get(),
      ]);

      final sessionDoc = results[0] as DocumentSnapshot;
      final attendanceSnap = results[1] as QuerySnapshot;

      final data = sessionDoc.data() as Map<String, dynamic>?;
      _attendanceMarked = (data?['attendanceMarked'] as bool?) ?? false;

      final attendanceMap = <String, bool>{
        for (var doc in attendanceSnap.docs)
          doc.id:
              ((doc.data() as Map<String, dynamic>)['status'] as String?) ==
              'Present',
      };

      // Subscribe to real-time student updates
      _studentsSub?.cancel();
      _studentsSub = FirebaseFirestore.instance
          .collection('students')
          .where('class', isEqualTo: widget.className)
          .snapshots()
          .listen(
            (studentsSnap) {
              final loadedStudents = <Map<String, dynamic>>[];

              for (var doc in studentsSnap.docs) {
                final sData = doc.data();
                loadedStudents.add({
                  'id': doc.id,
                  'name': sData['name'] ?? 'Unknown',
                  'rollNumber': sData['rollNumber'] ?? '',
                });

                if (!_attendanceStatus.containsKey(doc.id)) {
                  _attendanceStatus[doc.id] = _attendanceMarked
                      ? (attendanceMap[doc.id] ?? false)
                      : false;
                }
              }

              loadedStudents.sort((a, b) {
                final rollA = int.tryParse(a['rollNumber'].toString());
                final rollB = int.tryParse(b['rollNumber'].toString());
                if (rollA != null && rollB != null)
                  return rollA.compareTo(rollB);
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
                  _isLoading = false;
                });
              }
            },
            onError: (error) {
              if (mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error syncing students: $error')),
                );
              }
            },
          );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load: $e'),
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

      for (final student in _students) {
        batch.set(
          FirebaseFirestore.instance
              .collection('sessions')
              .doc(widget.sessionId)
              .collection('attendance')
              .doc(student['id']),
          {
            'status': _attendanceStatus[student['id']] == true
                ? 'Present'
                : 'Absent',
            'studentName': student['name'],
            'rollNumber': student['rollNumber'],
            'timestamp': FieldValue.serverTimestamp(),
          },
        );
      }

      batch.update(
        FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId),
        {
          'attendanceMarked': true,
          'attendanceCount': _attendanceStatus.values.where((v) => v).length,
          'totalStudents': _students.length,
        },
      );

      // Fire and forget batch commit.
      // Firestore will instantly save to local cache and sync in the background.
      // This avoids slow responses and erroneous timeout messages.
      batch.commit().catchError((error) {
        debugPrint('Background sync error: $error');
      });

      if (mounted) {
        setState(() {
          _isSaving = false;
          _attendanceMarked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully!'),
            backgroundColor: Color(0xFF4ADE80),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  /// Re-fetches saved values from Firestore before entering edit mode,
  /// so toggles always reflect what was actually saved.
  Future<void> _enterEditMode() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('attendance')
          .get();
      if (!mounted) return;
      setState(() {
        for (final doc in snap.docs) {
          _attendanceStatus[doc.id] =
              ((doc.data() as Map<String, dynamic>)['status'] as String?) ==
              'Present';
        }
        _attendanceMarked = false;
      });
    } catch (_) {
      if (mounted) setState(() => _attendanceMarked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF0B1220);
    const backgroundBottom = Color(0xFF111A2E);
    const accent = Color(0xFF22D3EE);

    return Scaffold(
      backgroundColor: backgroundTop,
      floatingActionButton:
          (!_isLoading && _students.isNotEmpty && !_attendanceMarked)
          ? FloatingActionButton.extended(
              onPressed: _showAddStudentDialog,
              backgroundColor: accent,
              icon: const Icon(
                Icons.person_add_rounded,
                color: Color(0xFF0B1220),
              ),
              label: const Text(
                'Add Student',
                style: TextStyle(
                  color: Color(0xFF0B1220),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
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
              onPressed: _enterEditMode,
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

  Widget _buildEmptyState() {
    final nameCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    const accent = Color(0xFF22D3EE);
    bool isAdding = false;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: StatefulBuilder(
          builder: (context, setInnerState) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 56,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Add First Student',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add students to ${widget.className} to start tracking attendance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Student Full Name',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: accent.withOpacity(0.7),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: TextField(
                    controller: rollCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: 'Roll/ID Number (Optional)',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      prefixIcon: Icon(
                        Icons.badge_outlined,
                        color: accent.withOpacity(0.7),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isAdding
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final roll = rollCtrl.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Student name is required.'),
                                ),
                              );
                              return;
                            }
                            setInnerState(() => isAdding = true);
                            try {
                              await FirebaseFirestore.instance
                                  .collection('students')
                                  .add({
                                    'name': name,
                                    'rollNumber': roll,
                                    'class': widget.className,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                              if (mounted)
                                setInnerState(() => isAdding = false);
                            } catch (e) {
                              if (mounted) {
                                setInnerState(() => isAdding = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error adding student: $e'),
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF0B1220),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: isAdding
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Color(0xFF0B1220),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Add Student',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    const accent = Color(0xFF22D3EE);

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
                  : (isPresent ? accent.withOpacity(0.3) : Colors.transparent),
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
                        : (isPresent ? accent : Colors.white.withOpacity(0.6)),
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
              // Badge when saved, toggle when editing
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
                  activeColor: accent,
                  activeTrackColor: accent.withOpacity(0.3),
                  inactiveThumbColor: Colors.white.withOpacity(0.4),
                  inactiveTrackColor: Colors.white.withOpacity(0.1),
                  onChanged: (val) {
                    setState(() => _attendanceStatus[student['id']] = val);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
