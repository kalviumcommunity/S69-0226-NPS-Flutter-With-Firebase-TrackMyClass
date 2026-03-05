import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'attendance_screen.dart';
import 'progress_screen.dart';
import 'social_login_screen.dart';
import 'institution_setup_screen.dart';

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
  // Store remote classes with their Firestore IDs for editing/deletion
  List<Map<String, dynamic>> _remoteClassesData = [];
  String? _selectedClass = _kDefaultClasses.first;
  bool _classesLoading = false; // NOT true — we show defaults instantly
  String? _teacherSubject;
  String? _institutionName;
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
              final data = doc.data();
              final instName = data?['institutionName'] as String?;

              // If institution is missing, redirect to setup
              if (instName == null || instName.isEmpty) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const InstitutionSetupScreen(),
                  ),
                  (_) => false,
                );
                return;
              }

              setState(() {
                _teacherSubject = data?['subject'] as String?;
                _institutionName = instName;
              });

              // Refresh streams with institution filter
              _mergeFirestoreClasses();
              _sessionsStream = _buildSessionsStream(_selectedClass);
            }
          },
          onError: (e) {
            // Silently handle offline/unavailable errors — snapshots continue listening
            debugPrint('User stream notice: $e');
          },
        );
  }

  Stream<QuerySnapshot> _buildSessionsStream(String? className) {
    if (className == null || _institutionName == null) {
      // Return an empty stream when no class is selected or institution unknown
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('sessions')
        .where('institutionName', isEqualTo: _institutionName)
        .where('class', isEqualTo: className)
        .where('active', isEqualTo: true)
        .snapshots();
  }

  /// Fetch classes from Firestore and merge them with the defaults.
  /// The UI already shows defaults, so this is a background update.
  Future<void> _mergeFirestoreClasses() async {
    if (_institutionName == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('institutionName', isEqualTo: _institutionName)
          .get()
          .timeout(const Duration(seconds: 8));

      final List<Map<String, dynamic>> remoteData = snapshot.docs.map((d) {
        return <String, dynamic>{
          'id': d.id,
          'name': (d.data()['name'] as String?) ?? d.id,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _remoteClassesData = remoteData;
        final remoteNames = remoteData.map((d) => d['name'] as String).toList();

        // If user has ANY remote classes, use ONLY those (satisfies "instead of Section 1, 2")
        // If they have none, show the defaults.
        if (remoteNames.isNotEmpty) {
          _classes = remoteNames;
        } else {
          _classes = List<String>.from(_kDefaultClasses);
        }

        // Keep selected class unless it got removed somehow
        if (_selectedClass == null || !_classes.contains(_selectedClass)) {
          _selectedClass = _classes.isNotEmpty ? _classes.first : null;
        }
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
      builder: (_) => _ClassPickerSheet(
        classes: _classes,
        remoteClassesData: _remoteClassesData,
        selected: _selectedClass ?? '',
      ),
    );

    if (result == null || !mounted) return;

    if (result.renameTo != null && result.renameId != null) {
      _renameClass(result.renameId!, result.oldName!, result.renameTo!);
      return;
    }

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
              'institutionName': _institutionName,
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': _user?.uid,
            })
            .then((_) => _mergeFirestoreClasses()) // Refresh IDs
            .catchError((_) => null); // silent fail
      } else if (result.selected != null) {
        _selectedClass = result.selected;
        _sessionsStream = _buildSessionsStream(_selectedClass);
      }
    });
  }

  Future<void> _renameClass(
    String? classId,
    String oldName,
    String newName,
  ) async {
    try {
      if (classId != null) {
        // 1. Update existing class
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .update({'name': newName});
      } else {
        // 1. Create new class from a default placeholder
        await FirebaseFirestore.instance.collection('classes').add({
          'name': newName,
          'institutionName': _institutionName,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': _user?.uid,
        });
      }

      // 2. Cascading update for students using the old name
      final students = await FirebaseFirestore.instance
          .collection('students')
          .where('institutionName', isEqualTo: _institutionName)
          .where('class', isEqualTo: oldName)
          .get();

      if (students.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in students.docs) {
          batch.update(doc.reference, {'class': newName});
        }
        await batch.commit();
      }

      // 3. Cascading update for sessions
      final sessions = await FirebaseFirestore.instance
          .collection('sessions')
          .where('institutionName', isEqualTo: _institutionName)
          .where('class', isEqualTo: oldName)
          .get();

      if (sessions.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in sessions.docs) {
          batch.update(doc.reference, {'class': newName});
        }
        await batch.commit();
      }

      // Update local state
      if (_selectedClass == oldName) {
        setState(() {
          _selectedClass = newName;
          _sessionsStream = _buildSessionsStream(_selectedClass);
        });
      }
      _mergeFirestoreClasses();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Class renamed to "$newName"'),
            backgroundColor: const Color(0xFF4ADE80),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error renaming class: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  // ── Start Session ──────────────────────────────────────────────────────────
  void _startSession() {
    if (_selectedClass == null) return;

    // Fire and forget so we switch tabs instantly even if network is slow
    FirebaseFirestore.instance
        .collection('sessions')
        .add({
          'class': _selectedClass,
          'institutionName': _institutionName,
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
          .where('institutionName', isEqualTo: _institutionName)
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
          // 'active' remains true for 3 seconds so banner shows "Completed"
          'attendanceCount': 0,
          'totalStudents': studentsSnap.docs.length,
        },
      );

      await batch.commit();

      // After 3 seconds, end the session to revert home card to "Start Session"
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          FirebaseFirestore.instance
              .collection('sessions')
              .doc(sessionId)
              .update({'active': false});
        }
      });

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
            institutionName: _institutionName!,
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
                institutionName: _institutionName ?? '',
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
class _ProfileTab extends StatefulWidget {
  final User? user;
  final VoidCallback onSignOut;

  const _ProfileTab({required this.user, required this.onSignOut});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  static const _backgroundTop = Color(0xFF0B1220);
  static const _backgroundBottom = Color(0xFF111A2E);
  static const _accent = Color(0xFF22D3EE);
  static const _cardBg = Color(0xFF1A2640);

  Map<String, dynamic>? _firestoreData;
  bool _firestoreLoading = true;
  StreamSubscription<DocumentSnapshot>? _userSub;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  void _startStream() {
    final uid = widget.user?.uid;
    if (uid == null) {
      setState(() => _firestoreLoading = false);
      return;
    }
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (doc) {
            if (mounted) {
              setState(() {
                _firestoreData = doc.exists ? doc.data() : null;
                _firestoreLoading = false;
              });
            }
          },
          onError: (_) {
            if (mounted) setState(() => _firestoreLoading = false);
          },
        );
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  // Detect if user signed in with email/password (not Google)
  bool get _isEmailPasswordUser {
    final providerData = widget.user?.providerData ?? [];
    return providerData.any((p) => p.providerId == 'password');
  }

  String get _displayName {
    final n = widget.user?.displayName;
    if (n != null && n.isNotEmpty) return n;
    return (_firestoreData?['name'] as String?) ?? 'Teacher';
  }

  String get _email => widget.user?.email ?? '';

  String get _subject => (_firestoreData?['subject'] as String?) ?? '';

  String get _memberSince {
    final ts = _firestoreData?['createdAt'];
    if (ts == null) return '—';
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else {
      return '—';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  bool get _emailVerified =>
      widget.user?.emailVerified ??
      (_firestoreData?['emailVerified'] as bool? ?? false);

  // ── Edit profile (name + subject) ──
  void _editProfile() {
    final nameCtrl = TextEditingController(
      text: _displayName == 'Teacher' ? '' : _displayName,
    );
    final subjectCtrl = TextEditingController(text: _subject);
    bool _saving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A2640),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                // Name field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _accent),
                      ),
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        color: _accent,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Subject field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: subjectCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _accent),
                      ),
                      prefixIcon: Icon(
                        Icons.menu_book_rounded,
                        color: const Color(0xFF4ADE80),
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _saving
                              ? null
                              : () async {
                                  setSheetState(() => _saving = true);
                                  final newName = nameCtrl.text.trim();
                                  final newSubject = subjectCtrl.text.trim();
                                  final uid = widget.user?.uid;
                                  if (uid == null) {
                                    Navigator.of(ctx).pop();
                                    return;
                                  }
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(uid)
                                        .set({
                                          'name': newName,
                                          'subject': newSubject,
                                        }, SetOptions(merge: true));
                                    await FirebaseAuth.instance.currentUser
                                        ?.updateDisplayName(newName);
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Profile updated',
                                          ),
                                          backgroundColor: const Color(
                                            0xFF4ADE80,
                                          ),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setSheetState(() => _saving = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Failed to update. Try again.',
                                          ),
                                          backgroundColor: const Color(
                                            0xFFFF6B6B,
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_accent, const Color(0xFF0EA5E9)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(
                                        color: Color(0xFF0B1220),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Send password reset to current user's email ──
  Future<void> _sendPasswordReset() async {
    final email = _email;
    if (email.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reset Password?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'A password reset link will be sent to\n$email',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
            height: 1.5,
          ),
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
              'Send Link',
              style: TextStyle(color: _accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset link sent to $email'),
          backgroundColor: const Color(0xFF4ADE80),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send reset link. Try again.'),
          backgroundColor: const Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarInitials = _displayName.isNotEmpty
        ? _displayName.trim().split(' ').map((w) => w[0]).take(2).join()
        : 'T';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_backgroundTop, _backgroundBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // ── Page title ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text(
                  'PROFILE',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),

            // ── Hero Card ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _accent.withOpacity(0.18),
                        const Color(0xFF0EA5E9).withOpacity(0.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _accent.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Avatar
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_accent, const Color(0xFF0EA5E9)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _accent.withOpacity(0.45),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    avatarInitials.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF0B1220),
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Name
                              Text(
                                _displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              // Email
                              Text(
                                _email,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Subject badge — only visible when subject is set
                              if (_subject.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: _accent.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.menu_book_rounded,
                                        color: _accent,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _subject,
                                        style: const TextStyle(
                                          color: _accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Edit button — top-right corner
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: _editProfile,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _accent.withOpacity(0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              color: _accent,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── About Me section ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Text(
                  'ABOUT ME',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _firestoreLoading
                    ? Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.07),
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: _accent,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.07),
                          ),
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Full Name',
                              value: _displayName,
                              iconColor: _accent,
                              isFirst: true,
                            ),
                            _InfoRow(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: _email.isNotEmpty ? _email : '—',
                              iconColor: const Color(0xFFA78BFA),
                            ),
                            if (_subject.isNotEmpty)
                              _InfoRow(
                                icon: Icons.menu_book_rounded,
                                label: 'Subject',
                                value: _subject,
                                iconColor: const Color(0xFF4ADE80),
                              ),
                            _InfoRow(
                              icon: Icons.calendar_month_rounded,
                              label: 'Member Since',
                              value: _memberSince,
                              iconColor: const Color(0xFFFBBF24),
                            ),
                            _InfoRow(
                              icon: _emailVerified
                                  ? Icons.verified_rounded
                                  : Icons.cancel_rounded,
                              label: 'Email Verified',
                              value: _emailVerified
                                  ? 'Verified'
                                  : 'Not Verified',
                              iconColor: _emailVerified
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFFF6B6B),
                              valueColor: _emailVerified
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFFF6B6B),
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // ── Account section ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Text(
                  'ACCOUNT',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),

            // Change Password — only shown for email/password users
            if (_isEmailPasswordUser)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: GestureDetector(
                    onTap: _sendPasswordReset,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.07),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24).withOpacity(0.13),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              color: Color(0xFFFBBF24),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Change Password',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
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
                ),
              ),

            // Sign out
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  _isEmailPasswordUser ? 12 : 12,
                  20,
                  0,
                ),
                child: GestureDetector(
                  onTap: widget.onSignOut,
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
                        const Expanded(
                          child: Text(
                            'Sign out',
                            style: TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Info Row
// ─────────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color? valueColor;
  final bool isFirst;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.valueColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: valueColor ?? Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 56,
            endIndent: 16,
            color: Colors.white.withOpacity(0.06),
          ),
      ],
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
  void didUpdateWidget(_HomeAttendanceSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presentCount != widget.presentCount ||
        oldWidget.totalCount != widget.totalCount) {
      _animCtrl.forward(from: 0.0);
    }
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
  final String? renameId; // document ID to rename
  final String? renameTo; // new name for renameId
  final String? oldName; // old name for cascading logic

  const _ClassPickerResult({
    this.selected,
    this.newClass,
    this.renameId,
    this.renameTo,
    this.oldName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Class Picker Bottom Sheet  (now StatefulWidget with + Add class)
// ─────────────────────────────────────────────────────────────────────────────
class _ClassPickerSheet extends StatefulWidget {
  final List<String> classes;
  final List<Map<String, dynamic>> remoteClassesData;
  final String selected;

  const _ClassPickerSheet({
    required this.classes,
    required this.remoteClassesData,
    required this.selected,
  });

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

  Future<void> _showRenameDialog(String? classId, String oldName) async {
    final controller = TextEditingController(text: oldName);
    const accent = Color(0xFF22D3EE);

    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2640),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Rename Class',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a new name for $oldName',
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
                  hintText: 'New Name',
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
              'Rename',
              style: TextStyle(
                color: Color(0xFF22D3EE),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != oldName && mounted) {
      Navigator.of(context).pop(
        _ClassPickerResult(
          renameId: classId,
          renameTo: result,
          oldName: oldName,
        ),
      );
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
                  // Check if this is a remote class (has an ID)
                  final remoteMatch = widget.remoteClassesData
                      .where((d) => d['name'] == cls)
                      .firstOrNull;
                  final classId = remoteMatch?['id'] as String?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
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
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(
                        context,
                      ).pop(_ClassPickerResult(selected: cls)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
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
                            Expanded(
                              child: Text(
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
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (classId != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showRenameDialog(classId, cls),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white.withOpacity(0.4),
                                    size: 14,
                                  ),
                                ),
                              ),
                            ] else ...[
                              // For default classes (no ID yet)
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showRenameDialog(null, cls),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white.withOpacity(0.4),
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 12),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF22D3EE),
                                size: 18,
                              )
                            else
                              const SizedBox(width: 18),
                          ],
                        ),
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
