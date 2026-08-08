/// Shared presentation layer for the Language Learning OS: theme,
/// navigation shell, and every feature screen. Consumed by apps/mobile,
/// apps/desktop, and apps/web so UI is written once (spec 2.6 monorepo
/// principle).
library ui;

export 'src/theme/app_theme.dart';
export 'src/navigation/app_router.dart';
export 'src/features/onboarding/presentation/onboarding_screen.dart';
export 'src/features/home/presentation/home_screen.dart';
