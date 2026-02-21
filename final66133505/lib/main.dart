import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'core/di/injection.dart';
import 'core/database/database.dart';
import 'core/constants/firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'shared/widgets/splash_screen.dart';

final _log = Logger('MyApp');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      // ignore: avoid_print
      print('  ERROR: ${record.error}');
    }
    if (record.stackTrace != null) {
      // ignore: avoid_print
      print('  STACK: ${record.stackTrace}');
    }
  });

  _log.info('App starting...');

  // 1. Firebase must be ready before anything else.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Register all singletons (DB, data sources, repos, sync manager).
  await configureDependencies();

  _log.info('Firebase & DI ready — showing splash');

  runApp(const MyApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// Root app
// ─────────────────────────────────────────────────────────────────────────────

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _startupDone = false;

  /// All heavy async work that must finish before the main shell is shown.
  ///
  /// Runs inside the SplashScreen so the user sees progress feedback.
  Future<void> _startup() async {
    // Step 1 — Ensure Firestore ↔ SQLite seed integrity.
    await _ensureFirestoreSeeded();

    // Step 2 — Pull latest data from Firestore → SQLite (startup pull-first).
    //           Always runs; gracefully skips if offline.
    _log.info('Startup pull from Firestore…');
    await sl<SyncService>().pullFromFirestoreOnStartup();
    _log.info('Startup pull done');

    // Step 3 — Start the auto-sync manager (periodic + lifecycle-aware).
    await sl<AutoSyncManager>().initialize();

    _log.info('Startup sequence complete ✓');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Election Incident Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Show splash while loading; swap to the router shell when done.
      home: _startupDone
          ? _RouterShell()
          : SplashScreen(
              startupFuture: _startup,
              onReady: () => setState(() => _startupDone = true),
            ),
    );
  }
}

/// Thin wrapper that hands off to the go_router configuration.
class _RouterShell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      title: 'Election Incident Monitor',
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context),
    );
  }
}

// ---------------------------------------------------------------------------
// Firestore seed check — production safe
// ---------------------------------------------------------------------------

/// Ensures bidirectional seed integrity between SQLite and Firestore.
///
/// Order matters: reference data (stations, types) is resolved FIRST so that
/// incident reports can satisfy their foreign-key constraints.
///
/// For each collection:
///   - If Firestore is empty BUT SQLite has data → push SQLite → Firestore.
///   - If Firestore has data BUT SQLite is empty → pull Firestore → SQLite.
///   - If both have data → nothing to do (regular sync handles merges).
///   - If both empty → the SQLite `_onCreate` seed should have run by now;
///     re-check and push if local data appeared.
Future<void> _ensureFirestoreSeeded() async {
  final firestore = FirebaseFirestore.instance;

  try {
    // ────────────────────────────────────────────────────────────────────────
    // STEP 1 — Reference data (must come first for FK integrity)
    // ────────────────────────────────────────────────────────────────────────

    // ── polling_stations ─────────────────────────────────────────────────
    final stationRepo = sl<PollingStationRepository>();
    // Calling getAll() ensures the DB is opened (triggers _onCreate + seed).
    var localStations = await stationRepo.getAll();
    final stationsSnap = await firestore
        .collection('polling_stations')
        .limit(1)
        .get();

    if (stationsSnap.docs.isEmpty && localStations.isNotEmpty) {
      _log.info(
        'Firestore: polling_stations empty, SQLite has ${localStations.length} → pushing',
      );
      await stationRepo.pushAllToFirestore();
    } else if (stationsSnap.docs.isNotEmpty && localStations.isEmpty) {
      _log.info('Firestore: polling_stations has data, SQLite empty → pulling');
      await stationRepo.pullFromFirestore();
    } else if (stationsSnap.docs.isEmpty && localStations.isEmpty) {
      _log.warning(
        'Firestore & SQLite both empty for polling_stations — no seed data available',
      );
    } else {
      _log.fine('Firestore: polling_stations — both sides have data ✓');
    }

    // ── violation_types ──────────────────────────────────────────────────
    final typeRepo = sl<ViolationTypeRepository>();
    var localTypes = await typeRepo.getAll();
    final typesSnap = await firestore
        .collection('violation_types')
        .limit(1)
        .get();

    if (typesSnap.docs.isEmpty && localTypes.isNotEmpty) {
      _log.info(
        'Firestore: violation_types empty, SQLite has ${localTypes.length} → pushing',
      );
      await typeRepo.pushAllToFirestore();
    } else if (typesSnap.docs.isNotEmpty && localTypes.isEmpty) {
      _log.info('Firestore: violation_types has data, SQLite empty → pulling');
      await typeRepo.pullFromFirestore();
    } else if (typesSnap.docs.isEmpty && localTypes.isEmpty) {
      _log.warning(
        'Firestore & SQLite both empty for violation_types — no seed data available',
      );
    } else {
      _log.fine('Firestore: violation_types — both sides have data ✓');
    }

    // ────────────────────────────────────────────────────────────────────────
    // STEP 2 — Incident reports (depends on reference data above)
    // ────────────────────────────────────────────────────────────────────────

    // Re-read reference data to confirm FK targets exist before pulling.
    localStations = await stationRepo.getAll();
    localTypes = await typeRepo.getAll();

    if (localStations.isEmpty || localTypes.isEmpty) {
      _log.warning(
        'Skipping incident_reports sync — reference data missing '
        '(stations: ${localStations.length}, types: ${localTypes.length})',
      );
      return;
    }

    final reportRepo = sl<IncidentReportRepository>();
    final localReports = await reportRepo.getAll();
    final reportsSnap = await firestore
        .collection('incident_reports')
        .limit(1)
        .get();

    if (reportsSnap.docs.isEmpty && localReports.isNotEmpty) {
      _log.info(
        'Firestore: incident_reports empty, SQLite has ${localReports.length} → pushing',
      );
      await reportRepo.pushAllToFirestore();
    } else if (reportsSnap.docs.isNotEmpty && localReports.isEmpty) {
      _log.info('Firestore: incident_reports has data, SQLite empty → pulling');
      await reportRepo.pullFromFirestore();
    } else if (reportsSnap.docs.isEmpty && localReports.isEmpty) {
      _log.fine(
        'Firestore & SQLite both empty for incident_reports — nothing to sync',
      );
    } else {
      _log.fine('Firestore: incident_reports — both sides have data ✓');
    }

    _log.info('Firestore seed check complete');
  } catch (e, s) {
    _log.severe('Firestore seed check failed (offline?)', e, s);
  }
}
