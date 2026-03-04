import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'attendance_screen.dart';
import 'progress_screen.dart';
import 'social_login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Default classes shown instantly — no Firestore wait needed
// ─────────────────────────────────────────────────────────────────────────────
const List<String> _kDefaultClasses = ['Section 1', 'Section 2', 'Section 3'];

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen — root shell with bottom nav
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;

  int _selectedTab = 0;

  final User? _user = FirebaseAuth.instance.currentUser;

  // ── Class state ────────────────────────────────────────────────────────────
  // Pre-populated with defaults so the UI loads immediately.
  List<String> _classes = List<String>.from(_kDefaultClasses);
  String? _selectedClass = _kDefaultClasses.first;
  bool _classesLoading = false; // NOT true — we show defaults instantly
  String? _teacherSubject;
  StreamSubscription? _userSub;

  // Stable stream — rebuilt only when _selectedClass changes, never inside build()
  late Stream<QuerySnapshot> _sessionsStream;

  @override
  void initState() {
    super.initState();

    // Initialise the stable sessions stream for the default class
    _sessionsStream = _buildSessionsStream(_selectedClass);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _floatingAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _mergeFirestoreClasses();
    _startUserStream();
  }

  void _startUserStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (doc) {
            if (doc.exists && mounted) {
              setState(() {
                _teacherSubject = doc.data()?['subject'] as String?;
              });
            }
          },
          onError: (e) {
            // Silently handle offline/unavailable errors — snapshots continue listening
            debugPrint('User stream notice: $e');
          },
        );
  }

  Stream<QuerySnapshot> _buildSessionsStream(String? className) {
    if (className == null) {
      // Return an empty stream when no class is selected
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('sessions')
        .where('class', isEqualTo: className)
        .where('active', isEqualTo: true)
        .snapshots();
  }

  /// Fetch classes from Firestore and merge them with the defaults.
  /// The UI already shows defaults, so this is a background update.
  Future<void> _mergeFirestoreClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .get()
          .timeout(const Duration(seconds: 8));

      final remote = snapshot.docs
          .map((d) => (d.data()['name'] as String?) ?? d.id)
          .where((n) => n.isNotEmpty)
          .toList();

      if (!mounted) return;

      setState(() {
        // Merge: keep defaults, add any remote that aren't already present
        final merged = List<String>.from(_kDefaultClasses);
        for (final r in remote) {
          if (!merged.contains(r)) merged.add(r);
        }
        _classes = merged;
        // Keep selected class unless it got removed somehow
        _selectedClass ??= merged.first;
      });
    } catch (_) {
      // Firestore unavailable — defaults are already shown, nothing to do
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatingController.dispose();
    _userSub?.cancel();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _displayName {
    final name = _user?.displayName;
    if (name != null && name.isNotEmpty) return name.split(' ').first;
    return 'Teacher';
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2640),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign out?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'You will be returned to the login screen.',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
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
              'Sign out',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SocialLoginScreen()),
      (_) => false,
    );
  }

  // ── Class picker bottom sheet ───────────────────────────────────────────────
  Future<void> _openClassPicker() async {
    final result = await showModalBottomSheet<_ClassPickerResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _ClassPickerSheet(classes: _classes, selected: _selectedClass ?? ''),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (result.newClass != null &&
          !_classes.contains(result.newClass!) &&
          result.newClass!.trim().isNotEmpty) {
        _classes = [..._classes, result.newClass!.trim()];
        _selectedClass = result.newClass!.trim();
        _sessionsStream = _buildSessionsStream(_selectedClass);
        // Persist new class to Firestore in background
        FirebaseFirestore.instance
            .collection('classes')
            .add({
              'name': result.newClass!.trim(),
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': _user?.uid,
            })
            .then((_) {})
            .catchError((_) => null); // silent fail
      } else if (result.selected != null) {
        _selectedClass = result.selected;
        _sessionsStream = _buildSessionsStream(_selectedClass);
      }
    });
  }

  // ── Start Session ──────────────────────────────────────────────────────────
  void _startSession() {
    if (_selectedClass == null) return;

    // Fire and forget so we switch tabs instantly even if network is slow
    FirebaseFirestore.instance
        .collection('sessions')
        .add({
          'class': _selectedClass,
          'active': true,
          'attendanceMarked': false,
          'sessionSubmitted': false,
          'startTime': FieldValue.serverTimestamp(),
          'teacherId': _user?.uid,
          'teacherName': _user?.displayName,
        })
        .then((_) {})
        .catchError((e) {
          debugPrint('Error starting session: $e');
        });

    setState(() => _selectedTab = 1);
  }

  Future<void> _saveAttendanceFromHome(
    String sessionId,
    String className,
  ) async {
    try {
      final studentsSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('class', isEqualTo: className)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in studentsSnap.docs) {
        batch.set(
          FirebaseFirestore.instance
              .collection('sessions')
              .doc(sessionId)
              .collection('attendance')
              .doc(doc.id),
          {
            'status': 'Absent', // default to Absent
            'studentName': doc.data()['name'],
            'rollNumber': doc.data()['rollNumber'],
            'timestamp': FieldValue.serverTimestamp(),
          },
        );
      }

      batch.update(
        FirebaseFirestore.instance.collection('sessions').doc(sessionId),
        {
          'attendanceMarked': true,
          'sessionSubmitted': true,
          'attendanceCount': 0,
          'totalStudents': studentsSnap.docs.length,
        },
      );

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Attendance saved as default (Absent). You can edit later.',
            ),
            backgroundColor: Color(0xFF4ADE80),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error auto-saving attendance: $e');
    }
  }

  void _openActiveSessionSheet(String sessionId, bool isAttendanceMarked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ActiveSessionSheet(
        sessionId: sessionId,
        isAttendanceMarked: isAttendanceMarked,
        onViewAttendance: () => setState(() => _selectedTab = 1),
        onSaveAttendance: () {
          if (_selectedClass != null) {
            _saveAttendanceFromHome(sessionId, _selectedClass!);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF0B1220);

    // Build the attendance tab widget once, driven by the active session stream.
    // ── Attendance tab ─────────────────────────────────────────────────────
    // Uses the STABLE _sessionsStream — same object across builds so
    // StreamBuilder never restarts, never destroys AttendanceScreen state.
    final attendanceTab = StreamBuilder<QuerySnapshot>(
      key: ValueKey(_selectedClass),
      stream: _sessionsStream,
      builder: (context, snapshot) {
        final isActive = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        if (isActive) {
          final sessionId = snapshot.data!.docs.first.id;
          return AttendanceScreen(
            key: ValueKey(sessionId),
            className: _selectedClass!,
            sessionId: sessionId,
          );
        }
        return _PlaceholderTab(
          icon: Icons.how_to_reg_rounded,
          label: 'Attendance',
        );
      },
    );

    // ── Home tab ────────────────────────────────────────────────────────────
    final homeTab = StreamBuilder<QuerySnapshot>(
      key: ValueKey('home_$_selectedClass'),
      stream: _sessionsStream,
      builder: (context, snapshot) {
        final isSessionActive =
            snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        final docData = isSessionActive
            ? snapshot.data!.docs.first.data() as Map<String, dynamic>?
            : null;
        final activeSessionId = isSessionActive
            ? snapshot.data!.docs.first.id
            : null;
        // Only show "Attendance Completed" when teacher explicitly submitted from home popup
        final isAttendanceMarked = docData?['sessionSubmitted'] == true;
        final presentCount = (docData?['attendanceCount'] as int?) ?? 0;
        final totalCount = (docData?['totalStudents'] as int?) ?? 0;

        return _HomeTab(
          greeting: _greeting,
          displayName: _displayName,
          selectedClass: _selectedClass,
          classesLoading: _classesLoading,
          onClassTap: _openClassPicker,
          floatingAnimation: _floatingAnimation,
          isSessionActive: isSessionActive,
          isAttendanceMarked: isAttendanceMarked,
          presentCount: presentCount,
          totalCount: totalCount,
          onStartSession: _startSession,
          onActiveSessionTap: () {
            if (activeSessionId != null) {
              _openActiveSessionSheet(activeSessionId, isAttendanceMarked);
            }
          },
          onViewAttendance: () {
            setState(() => _selectedTab = 1);
          },
          onViewProgress: () {
            setState(() => _selectedTab = 2);
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: backgroundTop,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1A2E),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.07)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: _selectedTab == 0,
                  onTap: () => setState(() => _selectedTab = 0),
                ),
                _NavItem(
                  icon: Icons.how_to_reg_rounded,
                  label: 'Attendance',
                  selected: _selectedTab == 1,
                  onTap: () => setState(() => _selectedTab = 1),
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Progress',
                  selected: _selectedTab == 2,
                  onTap: () => setState(() => _selectedTab = 2),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  selected: _selectedTab == 3,
                  onTap: () => setState(() => _selectedTab = 3),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          // IndexedStack keeps ALL tabs alive — no state loss on tab switch
          child: IndexedStack(
            index: _selectedTab,
            children: [
              homeTab,
              attendanceTab,
              ProgressScreen(
                className: _selectedClass ?? 'Section 1',
                teacherSubject: _teacherSubject,
              ),
              _ProfileTab(user: _user, onSignOut: _signOut),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Tab
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final String greeting;
  final String displayName;
  final String? selectedClass;
  final bool classesLoading;
  final VoidCallback onClassTap;
  final Animation<double> floatingAnimation;
  final bool isSessionActive;
  final bool isAttendanceMarked;
  final int presentCount;
  final int totalCount;
  final VoidCallback onStartSession;
  final VoidCallback onActiveSessionTap;
  final VoidCallback onViewAttendance;
  final VoidCallback onViewProgress;

  const _HomeTab({
    required this.greeting,
    required this.displayName,
    required this.selectedClass,
    required this.classesLoading,
    required this.onClassTap,
    required this.floatingAnimation,
    required this.isSessionActive,
    required this.isAttendanceMarked,
    required this.presentCount,
    required this.totalCount,
    required this.onStartSession,
    required this.onActiveSessionTap,
    required this.onViewAttendance,
    required this.onViewProgress,
  });

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF0B1220);
    const backgroundBottom = Color(0xFF111A2E);
    const accent = Color(0xFF22D3EE);

    return Stack(
      children: [
        // Background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [backgroundTop, backgroundBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Decorative circle
        AnimatedBuilder(
          animation: floatingAnimation,
          builder: (_, __) => Positioned(
            top: -50 + floatingAnimation.value,
            right: -50,
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        // Content
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // App bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'TrackMyClass',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      // Class selector pill — always ready (no loading state)
                      GestureDetector(
                        onTap: onClassTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2640),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: accent.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.class_rounded,
                                color: accent,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                selectedClass ?? 'Select class',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withOpacity(0.5),
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Greeting
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting,',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ready to track your class today?',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Today's Class card (Start Session) — always shown for teachers
              if (!isSessionActive)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: GestureDetector(
                      onTap: onStartSession,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withOpacity(0.25),
                              const Color(0xFF0EA5E9).withOpacity(0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedClass?.toUpperCase() ??
                                        'NO CLASS SET',
                                    style: TextStyle(
                                      color: accent.withOpacity(0.8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'No session started',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to start session',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: accent,
                                size: 26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Active session banner
              if (isSessionActive)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: GestureDetector(
                      onTap: onActiveSessionTap,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isAttendanceMarked
                                ? [
                                    accent.withOpacity(0.2),
                                    const Color(0xFF0EA5E9).withOpacity(0.1),
                                  ]
                                : [
                                    const Color(0xFF4ADE80).withOpacity(0.2),
                                    const Color(0xFF22D3EE).withOpacity(0.1),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isAttendanceMarked
                                ? accent.withOpacity(0.4)
                                : const Color(0xFF4ADE80).withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isAttendanceMarked
                                    ? accent.withOpacity(0.2)
                                    : const Color(0xFF4ADE80).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAttendanceMarked
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_checked,
                                color: isAttendanceMarked
                                    ? accent
                                    : const Color(0xFF4ADE80),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedClass?.toUpperCase() ?? '',
                                    style: TextStyle(
                                      color:
                                          (isAttendanceMarked
                                                  ? accent
                                                  : const Color(0xFF4ADE80))
                                              .withOpacity(0.9),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isAttendanceMarked
                                        ? 'Attendance Completed'
                                        : 'Session in progress',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isAttendanceMarked
                                    ? accent
                                    : const Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    isSessionActive ? 32 : 40,
                    20,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QUICK ACTIONS',
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          // When attendance is saved: show pie-chart card as button
                          if (isAttendanceMarked)
                            _HomeAttendanceSummaryCard(
                              presentCount: presentCount,
                              totalCount: totalCount,
                              onTap: onViewAttendance,
                            )
                          else
                            _QuickActionCard(
                              icon: Icons.how_to_reg_rounded,
                              label: 'View Attendance',
                              color: const Color(0xFF4ADE80),
                              onTap: onViewAttendance,
                            ),
                          const SizedBox(height: 14),
                          _QuickActionCard(
                            icon: Icons.bar_chart_rounded,
                            label: 'View Progress',
                            color: const Color(0xFFA78BFA),
                            onTap: onViewProgress,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Tab
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  final User? user;
  final VoidCallback onSignOut;

  const _ProfileTab({required this.user, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF0B1220);
    const backgroundBottom = Color(0xFF111A2E);
    const accent = Color(0xFF22D3EE);

    final displayName = () {
      final n = user?.displayName;
      return (n != null && n.isNotEmpty) ? n : 'Teacher';
    }();
    final email = user?.email ?? '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundTop, backgroundBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Text(
                'PROFILE',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),

          // Avatar + name card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2640),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: accent.withOpacity(0.2),
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'T',
                        style: const TextStyle(
                          color: Color(0xFF22D3EE),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            email,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Account section label
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Text(
                'ACCOUNT',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),

          // Sign out button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: GestureDetector(
                onTap: onSignOut,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF6B6B).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withOpacity(0.13),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFFF6B6B),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Sign out',
                        style: TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder Tab
// ─────────────────────────────────────────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlaceholderTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B1220), Color(0xFF111A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF22D3EE), size: 48),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Action Card
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Home Attendance Summary Card (replaces View Attendance when done)
// ─────────────────────────────────────────────────────────────────────────────
class _HomeAttendanceSummaryCard extends StatefulWidget {
  final int presentCount;
  final int totalCount;
  final VoidCallback onTap;

  const _HomeAttendanceSummaryCard({
    required this.presentCount,
    required this.totalCount,
    required this.onTap,
  });

  @override
  State<_HomeAttendanceSummaryCard> createState() =>
      _HomeAttendanceSummaryCardState();
}

class _HomeAttendanceSummaryCardState extends State<_HomeAttendanceSummaryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _sweepAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _sweepAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalCount;
    final present = widget.presentCount;
    final absent = total - present;
    final pct = total > 0 ? (present / total * 100).round() : 0;
    final presentFrac = total > 0 ? present / total : 0.0;

    const green = Color(0xFF059669); // Emerald 600 (Darker)
    const red = Color(0xFFE11D48); // Rose 600 (Darker)
    const cyan = Color(0xFF0EA5E9); // Sky Blue 500

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Column(
          children: [
            // ── Top section: header + donut ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      const Text(
                        'Attendance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, color: green, size: 9),
                            SizedBox(width: 2),
                            Text(
                              'Saved',
                              style: TextStyle(
                                color: green,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withOpacity(0.25),
                        size: 13,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Donut chart — centred, slightly smaller
                  AnimatedBuilder(
                    animation: _sweepAnim,
                    builder: (context, _) => SizedBox(
                      width: 110,
                      height: 110,
                      child: CustomPaint(
                        painter: _HomeDonutPainter(
                          presentFraction: total > 0
                              ? presentFrac * _sweepAnim.value
                              : 0,
                          sweep: _sweepAnim.value,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$pct%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'attendance',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Full-width segmented bar
                  AnimatedBuilder(
                    animation: _sweepAnim,
                    builder: (context, _) {
                      final animPresentFrac = presentFrac * _sweepAnim.value;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 6,
                          child: Row(
                            children: [
                              if (animPresentFrac > 0)
                                Flexible(
                                  flex: (animPresentFrac * 1000).round(),
                                  child: Container(color: green),
                                ),
                              if (animPresentFrac < _sweepAnim.value)
                                Flexible(
                                  flex: ((1 - animPresentFrac) * 1000)
                                      .round()
                                      .clamp(1, 1000),
                                  child: Container(color: red.withOpacity(0.7)),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 4),

                  // Bar labels
                  Row(
                    children: [
                      Text(
                        'Present  $present',
                        style: TextStyle(
                          color: green.withOpacity(0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Absent  $absent',
                        style: TextStyle(
                          color: red.withOpacity(0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Divider ──────────────────────────────────────────────────
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withOpacity(0.06),
            ),

            // ── Bottom stat pills row ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  _StatPill(
                    label: 'Total',
                    value: '$total',
                    color: cyan,
                    icon: Icons.groups_rounded,
                  ),
                  const SizedBox(width: 8),
                  _StatPill(
                    label: 'Present',
                    value: '$present',
                    color: green,
                    icon: Icons.how_to_reg_rounded,
                  ),
                  const SizedBox(width: 8),
                  _StatPill(
                    label: 'Absent',
                    value: '$absent',
                    color: red,
                    icon: Icons.person_off_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stat pill widget for the home attendance card
class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color.withOpacity(0.85), size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Donut painter (home screen version)
class _HomeDonutPainter extends CustomPainter {
  final double presentFraction;
  final double sweep;

  const _HomeDonutPainter({required this.presentFraction, required this.sweep});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width / 2) - 6;
    const strokeWidth = 11.0;
    const pi = 3.14159265358979;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Background track
    paint.color = Colors.white.withOpacity(0.07);
    canvas.drawCircle(Offset(cx, cy), radius, paint);

    final startAngle = -pi / 2;

    // Absent arc
    final absentFraction =
        (1.0 - (sweep > 0 ? presentFraction / sweep : 0)) * sweep;
    if (absentFraction > 0) {
      paint.color = const Color(0xFFE11D48); // Darker Rose
      canvas.drawArc(
        rect,
        startAngle + presentFraction * 2 * pi,
        absentFraction * 2 * pi,
        false,
        paint,
      );
    }

    // Present arc
    if (presentFraction > 0) {
      paint.color = const Color(0xFF059669); // Darker Emerald
      canvas.drawArc(rect, startAngle, presentFraction * 2 * pi, false, paint);
    }

    // 100% edge case
    if (presentFraction >= sweep && sweep > 0.99) {
      paint.color = const Color(0xFF059669); // Darker Emerald
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_HomeDonutPainter old) =>
      old.presentFraction != presentFraction || old.sweep != sweep;
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2640),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Nav Item
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF22D3EE);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? accent : Colors.white.withOpacity(0.35),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? accent : Colors.white.withOpacity(0.35),
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result model returned by the class picker sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ClassPickerResult {
  final String? selected; // an existing class was tapped
  final String? newClass; // a brand-new class name was added

  const _ClassPickerResult({this.selected, this.newClass});
}

// ─────────────────────────────────────────────────────────────────────────────
// Class Picker Bottom Sheet  (now StatefulWidget with + Add class)
// ─────────────────────────────────────────────────────────────────────────────
class _ClassPickerSheet extends StatefulWidget {
  final List<String> classes;
  final String selected;

  const _ClassPickerSheet({required this.classes, required this.selected});

  @override
  State<_ClassPickerSheet> createState() => _ClassPickerSheetState();
}

class _ClassPickerSheetState extends State<_ClassPickerSheet> {
  late List<String> _localClasses;
  late String _currentSelected;

  @override
  void initState() {
    super.initState();
    _localClasses = List<String>.from(widget.classes);
    _currentSelected = widget.selected;
  }

  Future<void> _showAddClassDialog() async {
    final controller = TextEditingController();
    const accent = Color(0xFF22D3EE);

    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2640),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add New Class',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a class or section name',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1A2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g., Grade 6A, Section 4',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Navigator.of(ctx).pop(v.trim());
                },
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
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.of(ctx).pop(v);
            },
            child: const Text(
              'Add',
              style: TextStyle(
                color: Color(0xFF22D3EE),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      // Close the sheet and pass the new class back to parent
      Navigator.of(context).pop(_ClassPickerResult(newClass: result));
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF22D3EE);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header row
          Row(
            children: [
              const Text(
                'SELECT CLASS',
                style: TextStyle(
                  color: Color(0xFF22D3EE),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              // + Add class button
              GestureDetector(
                onTap: _showAddClassDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: accent, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        'Add class',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Class list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: _localClasses.map((cls) {
                  final isSelected = cls == _currentSelected;
                  return GestureDetector(
                    onTap: () => Navigator.of(
                      context,
                    ).pop(_ClassPickerResult(selected: cls)),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent.withOpacity(0.12)
                            : const Color(0xFF1A2640),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? accent.withOpacity(0.4)
                              : Colors.white.withOpacity(0.07),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.class_rounded,
                            color: isSelected
                                ? accent
                                : Colors.white.withOpacity(0.4),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            cls,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF22D3EE),
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Session Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveSessionSheet extends StatefulWidget {
  final String sessionId;
  final bool isAttendanceMarked;
  final VoidCallback onViewAttendance;
  final VoidCallback onSaveAttendance;

  const _ActiveSessionSheet({
    required this.sessionId,
    required this.isAttendanceMarked,
    required this.onViewAttendance,
    required this.onSaveAttendance,
  });

  @override
  State<_ActiveSessionSheet> createState() => _ActiveSessionSheetState();
}

class _ActiveSessionSheetState extends State<_ActiveSessionSheet> {
  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF22D3EE);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ACTIVE SESSION',
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Submit or View Attendance Option
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              if (widget.isAttendanceMarked) {
                widget.onViewAttendance();
              } else {
                widget.onSaveAttendance();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2640),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isAttendanceMarked
                          ? Icons.assignment_turned_in_rounded
                          : Icons.how_to_reg_rounded,
                      color: const Color(0xFF4ADE80),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.isAttendanceMarked
                          ? 'View Attendance'
                          : 'Save Attendance',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Cancel Option
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2640),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cancel_rounded,
                      color: Colors.white.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
