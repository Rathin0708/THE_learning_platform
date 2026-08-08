/// Shared business logic for the Language Learning OS — domain entities,
/// SQLite data layer, spaced-repetition engine, and Riverpod providers.
/// Consumed by every app target (mobile/desktop/web); never imports UI.
library core;

export 'src/domain/entities/content_entities.dart';
export 'src/domain/entities/user_entities.dart';
export 'src/domain/repositories/content_repository.dart';
export 'src/domain/repositories/progress_repository.dart';

export 'src/data/database/app_database.dart';
export 'src/data/database/database_factory_setup.dart';
export 'src/data/repositories/sqlite_content_repository.dart';
export 'src/data/repositories/sqlite_progress_repository.dart';

export 'src/application/srs/spaced_repetition_engine.dart';
export 'src/application/providers/core_providers.dart';
