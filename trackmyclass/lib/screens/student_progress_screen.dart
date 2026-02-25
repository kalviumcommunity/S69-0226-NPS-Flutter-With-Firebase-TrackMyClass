import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Individual student progress screen.
/// Shows a list of marks entries and lets the teacher add new ones.
class StudentProgressScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? teacherSubject;

  const StudentProgressScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.teacherSubject,
  });

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  static const _backgroundTop = Color(0xFF0B1220);
  static const _backgroundBottom = Color(0xFF111A2E);
  static const _accent = Color(0xFFA78BFA);
  static const _green = Color(0xFF4ADE80);
  static const _red = Color(0xFFFF6B6B);
  static const _yellow = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundTop,
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
            Text(
              widget.studentName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Progress & Marks',
              style: TextStyle(
                color: _accent.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMarksDialog(context),
        backgroundColor: _accent,
        icon: const Icon(Icons.add_rounded, color: Color(0xFF0B1220)),
        label: const Text(
          'Add Marks',
          style: TextStyle(
            color: Color(0xFF0B1220),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_backgroundTop, _backgroundBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('students')
              .doc(widget.studentId)
              .collection('marks')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _accent,
                  strokeWidth: 3,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: _red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load marks',
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

            return _buildMarksList(docs);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assessment_outlined,
                size: 56,
                color: _accent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Marks Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the + button to add marks\nfor ${widget.studentName}.',
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

  Widget _buildMarksList(List<QueryDocumentSnapshot> docs) {
    // Calculate summary
    int totalScore = 0;
    int totalMax = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalScore += (data['score'] as num?)?.toInt() ?? 0;
      totalMax += (data['totalMarks'] as num?)?.toInt() ?? 0;
    }
    final percentage = totalMax > 0 ? (totalScore / totalMax * 100) : 0.0;

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        // Summary card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _accent.withOpacity(0.2),
                    const Color(0xFF6366F1).withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OVERALL',
                          style: TextStyle(
                            color: _accent.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalScore / $totalMax marks',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getPercentageColor(percentage),
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${docs.length}',
                        style: TextStyle(
                          color: _getPercentageColor(percentage),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Section label
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'MARKS HISTORY',
              style: TextStyle(
                color: _accent.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),

        // Marks entries
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final subject = data['subject'] ?? 'Unknown';
            final score = (data['score'] as num?)?.toInt() ?? 0;
            final total = (data['totalMarks'] as num?)?.toInt() ?? 0;
            final date = (data['date'] as Timestamp?)?.toDate();
            final pct = total > 0 ? (score / total * 100) : 0.0;

            return Dismissible(
              key: Key(doc.id),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerRight,
                child: const Icon(Icons.delete_rounded, color: _red, size: 24),
              ),
              confirmDismiss: (_) => _confirmDelete(context),
              onDismissed: (_) {
                FirebaseFirestore.instance
                    .collection('students')
                    .doc(widget.studentId)
                    .collection('marks')
                    .doc(doc.id)
                    .delete();
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2640),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _getPercentageColor(pct).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${pct.round()}%',
                          style: TextStyle(
                            color: _getPercentageColor(pct),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            date != null
                                ? '${date.day}/${date.month}/${date.year}'
                                : '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$score / $total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'marks',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }, childCount: docs.length),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Color _getPercentageColor(double pct) {
    if (pct >= 75) return _green;
    if (pct >= 50) return _yellow;
    return _red;
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2640),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Marks?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This entry will be permanently removed.',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: _red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMarksDialog(BuildContext context) async {
    String? subjectText = widget.teacherSubject;

    // Fallback: If subject is missing, try to fetch it directly
    if (subjectText == null || subjectText.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Try to get from server/cache normally
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 3));
          subjectText = doc.data()?['subject'] as String?;
        } catch (_) {
          // If server fails (offline), try cache specifically
          try {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(const GetOptions(source: Source.cache));
            subjectText = doc.data()?['subject'] as String?;
          } catch (__) {
            // Give up if cache also fails
          }
        }
      }
    }

    if (!mounted) return;

    final subjectCtrl = TextEditingController(text: subjectText);
    final scoreCtrl = TextEditingController();
    final totalCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2640),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Marks',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(
              controller: subjectCtrl,
              hint: 'Subject (e.g., Maths, Science)',
              icon: Icons.book_rounded,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            _buildDialogField(
              controller: scoreCtrl,
              hint: 'Score obtained',
              icon: Icons.star_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            _buildDialogField(
              controller: totalCtrl,
              hint: 'Total marks',
              icon: Icons.format_list_numbered_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
            onPressed: () {
              final subject = subjectCtrl.text.trim();
              final score = int.tryParse(scoreCtrl.text.trim());
              final total = int.tryParse(totalCtrl.text.trim());

              if (subject.isEmpty || score == null || total == null) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields correctly.'),
                    backgroundColor: _red,
                  ),
                );
                return;
              }

              if (score > total) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Score cannot be greater than total marks.'),
                    backgroundColor: _red,
                  ),
                );
                return;
              }

              // Close dialog immediately (optimistic UI)
              Navigator.of(ctx).pop();

              // Fire-and-forget Firestore write — StreamBuilder picks it up
              FirebaseFirestore.instance
                  .collection('students')
                  .doc(widget.studentId)
                  .collection('marks')
                  .add({
                    'subject': subject,
                    'score': score,
                    'totalMarks': total,
                    'date': FieldValue.serverTimestamp(),
                    'addedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
                  })
                  .then((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('Marks added successfully!'),
                          backgroundColor: _green,
                        ),
                      );
                    }
                  })
                  .catchError((e) {
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('Error saving marks: $e'),
                          backgroundColor: _red,
                        ),
                      );
                    }
                  });
            },
            child: const Text(
              'Save',
              style: TextStyle(color: _accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool autofocus = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.4)),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: _accent.withOpacity(0.6), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
