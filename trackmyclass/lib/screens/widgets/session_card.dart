import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum SessionState {
  noSession,
  inProgress,
  completed,
}

class SessionCard extends StatefulWidget {
  final String className;
  final String institutionName;
  final String teacherId;
  final String? teacherName;
  final VoidCallback? onStateChanged;

  const SessionCard({
    super.key,
    required this.className,
    required this.institutionName,
    required this.teacherId,
    this.teacherName,
    this.onStateChanged,
  });

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  String? _currentSessionId;
  SessionState _sessionState = SessionState.noSession;
  bool _isLoading = false;
  bool _isExpandedAttendance = false;
  List<Map<String, dynamic>> _students = [];
  Map<String, bool> _attendanceStatus = {};
  bool _isSavingAttendance = false;
  StreamSubscription? _sessionSub;
  StreamSubscription? _studentsSub;

  @override
  void initState() {
    super.initState();
    _initializeSessionStream();
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _studentsSub?.cancel();
    super.dispose();
  }

  void _initializeSessionStream() {
    _sessionSub = FirebaseFirestore.instance
        .collection('sessions')
        .where('institutionName', isEqualTo: widget.institutionName)
        .where('class', isEqualTo: widget.className)
        .where('active', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.docs.isEmpty) {
              if (mounted) {
                setState(() {
                  _currentSessionId = null;
                  _sessionState = SessionState.noSession;
                  _isExpandedAttendance = false;
                  _students.clear();
                  _attendanceStatus.clear();
                });
              }
              return;
            }

            final sessionDoc = snapshot.docs.first;
            final sessionId = sessionDoc.id;
            final sessionData = sessionDoc.data() as Map<String, dynamic>;
            final isSubmitted = sessionData['sessionSubmitted'] == true;

            if (mounted) {
              setState(() {
                _currentSessionId = sessionId;
                _sessionState = isSubmitted
                    ? SessionState.completed
                    : SessionState.inProgress;
              });
            }

            if (_sessionState == SessionState.inProgress) {
              _loadStudents();
            }
          },
          onError: (e) {
            debugPrint('Session stream error: $e');
          },
        );
  }

  void _loadStudents() {
    _studentsSub?.cancel();
    _studentsSub = FirebaseFirestore.instance
        .collection('students')
        .where('institutionName', isEqualTo: widget.institutionName)
        .where('class', isEqualTo: widget.className)
        .snapshots()
        .listen(
          (snapshot) {
            List<Map<String, dynamic>> students = [];
            for (var doc in snapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              students.add({
                'id': doc.id,
                'name': data['name'] ?? 'Unknown',
                'rollNumber': data['rollNumber'] ?? '',
              });

              if (!_attendanceStatus.containsKey(doc.id)) {
                _attendanceStatus[doc.id] = false;
              }
            }

            students.sort((a, b) {
              final rollA = int.tryParse(a['rollNumber'].toString());
              final rollB = int.tryParse(b['rollNumber'].toString());

              if (rollA != null && rollB != null) return rollA.compareTo(rollB);
              return a['name'].toString().compareTo(b['name'].toString());
            });

            if (mounted) {
              setState(() {
                _students = students;
              });
            }
          },
          onError: (e) {
            debugPrint('Students stream error: $e');
          },
        );
  }

  Future<void> _startNewSession() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('sessions').add({
        'class': widget.className,
        'institutionName': widget.institutionName,
        'active': true,
        'attendanceMarked': false,
        'sessionSubmitted': false,
        'startTime': FieldValue.serverTimestamp(),
        'teacherId': widget.teacherId,
        'teacherName': widget.teacherName,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        widget.onStateChanged?.call();
      }
    } catch (e) {
      debugPrint('Error starting session: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting session: $e')),
        );
      }
    }
  }

  void _toggleAttendance(String studentId) {
    setState(() {
      _attendanceStatus[studentId] = !(_attendanceStatus[studentId] ?? false);
    });
  }

  Future<void> _saveAttendance() async {
    if (_currentSessionId == null || _isSavingAttendance) return;

    setState(() => _isSavingAttendance = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var studentId in _attendanceStatus.keys) {
        batch.set(
          FirebaseFirestore.instance
              .collection('attendance')
              .doc('${_currentSessionId}_$studentId'),
          {
            'sessionId': _currentSessionId,
            'studentId': studentId,
            'present': _attendanceStatus[studentId] ?? false,
            'recordedAt': FieldValue.serverTimestamp(),
            'institutionName': widget.institutionName,
            'class': widget.className,
          },
        );
      }

      batch.update(
        FirebaseFirestore.instance
            .collection('sessions')
            .doc(_currentSessionId!),
        {
          'attendanceMarked': true,
          'sessionSubmitted': true,
          'submittedAt': FieldValue.serverTimestamp(),
          'active': false,
        },
      );

      await batch.commit();

      if (mounted) {
        setState(() {
          _isSavingAttendance = false;
          _isExpandedAttendance = false;
        });
        widget.onStateChanged?.call();
      }
    } catch (e) {
      debugPrint('Error saving attendance: $e');
      if (mounted) {
        setState(() => _isSavingAttendance = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving attendance: $e')),
        );
      }
    }
  }

  SessionState getSessionState() => _sessionState;
  String? getCurrentSessionId() => _currentSessionId;
  List<Map<String, dynamic>> getStudents() => _students;
  Map<String, bool> getAttendanceStatus() => _attendanceStatus;
  bool isExpanded() => _isExpandedAttendance;

  Future<void> startSession() => _startNewSession();
  Future<void> saveAttendance() => _saveAttendance();
  void toggleStudentAttendance(String studentId) => _toggleAttendance(studentId);
  void setExpanded(bool expanded) {
    setState(() => _isExpandedAttendance = expanded);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
