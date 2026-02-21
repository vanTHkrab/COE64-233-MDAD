/// Barrel export for the entire storage layer.
///
/// Import this single file to access:
///   • Entity classes
///   • Data sources
///   • Repositories (via injection.dart)
///   • Sync service
///   • Database singleton
library database;

export 'app_database.dart';
export 'local_datasource.dart'
    show
        PollingStationEntity,
        ViolationTypeEntity,
        IncidentReportEntity,
        LocalDataSource;
export 'remote_datasource.dart' show RemoteDataSource;
export 'sync_service.dart' show SyncService;
export '../services/auto_sync_manager.dart'
    show AutoSyncManager, SyncState, SyncStatus;
