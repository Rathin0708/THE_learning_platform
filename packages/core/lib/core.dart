/// Shared business logic for the Language Learning OS — domain entities,
/// SQLite data layer, spaced-repetition engine, and Riverpod providers.
/// Consumed by every app target (mobile/desktop/web); never imports UI.
library;

export 'src/domain/entities/content_entities.dart';
export 'src/domain/entities/user_entities.dart';
export 'src/domain/repositories/content_repository.dart';
export 'src/domain/repositories/progress_repository.dart';

export 'src/data/database/app_database.dart';
export 'src/data/database/database_factory_setup.dart';
export 'src/data/database/schema.dart';
export 'src/data/content_update/content_update_checker.dart';
export 'src/data/repositories/sqlite_content_repository.dart';
export 'src/data/repositories/sqlite_progress_repository.dart';

export 'src/application/srs/spaced_repetition_engine.dart';
export 'src/application/conversation/conversation_response_matcher.dart';
export 'src/domain/ai/local_ai_routing_policy.dart';
export 'src/domain/ai/local_llm_engine.dart';
export 'src/domain/ai/grammar_correction_service.dart';
export 'src/domain/ai/local_ai_model_manager.dart';
export 'src/application/providers/core_providers.dart';
