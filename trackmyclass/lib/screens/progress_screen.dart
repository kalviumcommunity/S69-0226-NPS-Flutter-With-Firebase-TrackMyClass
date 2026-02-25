import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'student_progress_screen.dart';

/// Shows all students belonging to a particular class/section.
/// Tapping a student navigates to their individual progress page.
class ProgressScreen extends StatelessWidget {
  final String className;
  final String? teacherSubject;

  const ProgressScreen({
    super.key,
    required this.className,
    this.teacherSubject,
  });

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF0B1220);
    const backgroundBottom = Color(0xFF111A2E);
    const accent = Color(0xFFA78BFA); // purple accent for progress

    return Scaffold(
      backgroundColor: backgroundTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // No back button when used as a tab
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              className,
              style: TextStyle(
                color: accent.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('students')
              .where('class', isEqualTo: className)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: accent, strokeWidth: 3),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFFF6B6B),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load students',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return _buildEmptyState();
            }

            // Sort by roll number, then name
            final students = docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                'name': d['name'] ?? 'Unknown',
                'rollNumber': d['rollNumber'] ?? '',
              };
            }).toList();

            students.sort((a, b) {
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

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return _StudentCard(
                  name: student['name'] as String,
                  rollNumber: student['rollNumber'] as String,
                  studentId: student['id'] as String,
                  studentName: student['name'] as String,
                  teacherSubject: teacherSubject,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    const accent = Color(0xFFA78BFA);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 56,
                color: accent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Students Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add students in the Attendance screen first,\nthen you can track their progress here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student Card
// ─────────────────────────────────────────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  final String name;
  final String rollNumber;
  final String studentId;
  final String studentName;
  final String? teacherSubject;

  const _StudentCard({
    required this.name,
    required this.rollNumber,
    required this.studentId,
    required this.studentName,
    this.teacherSubject,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFA78BFA);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StudentProgressScreen(
              studentId: studentId,
              studentName: studentName,
              teacherSubject: teacherSubject,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2640),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: accent.withOpacity(0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (rollNumber.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Roll: $rollNumber',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
