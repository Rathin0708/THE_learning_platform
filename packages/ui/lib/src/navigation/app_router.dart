import 'package:go_router/go_router.dart';

import '../features/conversation/presentation/conversation_detail_screen.dart';
import '../features/conversation/presentation/conversation_list_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/lessons/presentation/lessons_screen.dart';
import '../features/lessons/presentation/study_session_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/progress/presentation/progress_screen.dart';
import '../features/quiz/presentation/quiz_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/sentences/presentation/sentences_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/vocabulary/presentation/vocabulary_screen.dart';
import '../features/word_detail/presentation/word_detail_screen.dart';

/// Navigation shell (THE-16). Every route from spec section 3.1 is
/// reachable: onboarding, home, vocabulary, sentences, grammar, lessons,
/// practice, speaking, listening, conversation, quiz, revision, progress,
/// search, settings.
class AppRoutes {
  AppRoutes._();
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const vocabulary = '/vocabulary';
  static const sentences = '/sentences';
  static const lessons = '/lessons';
  static const practice = '/practice';
  static const speaking = '/speaking';
  static const listening = '/listening';
  static const conversation = '/conversation';
  static const quiz = '/quiz';
  static const revision = '/revision';
  static const progress = '/progress';
  static const search = '/search';
  static const settings = '/settings';
  static String wordDetail(int id) => '/word/$id';
  static String conversationDetail(int id) => '/conversation/$id';
}

GoRouter buildAppRouter({required bool onboardingComplete}) {
  return GoRouter(
    initialLocation: onboardingComplete ? AppRoutes.home : AppRoutes.onboarding,
    routes: [
      GoRoute(path: AppRoutes.onboarding, builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
      GoRoute(path: AppRoutes.vocabulary, builder: (context, state) => const VocabularyScreen()),
      GoRoute(path: AppRoutes.sentences, builder: (context, state) => const SentencesScreen()),
      GoRoute(path: AppRoutes.lessons, builder: (context, state) => const LessonsScreen()),
      GoRoute(path: AppRoutes.practice, builder: (context, state) => const StudySessionScreen()),
      GoRoute(path: AppRoutes.speaking, builder: (context, state) => const StudySessionScreen(speakingMode: true)),
      GoRoute(path: AppRoutes.listening, builder: (context, state) => const VocabularyScreen(listeningMode: true)),
      GoRoute(path: AppRoutes.conversation, builder: (context, state) => const ConversationListScreen()),
      GoRoute(
        path: '${AppRoutes.conversation}/:id',
        builder: (context, state) => ConversationDetailScreen(
          conversationId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: AppRoutes.quiz, builder: (context, state) => const QuizScreen()),
      GoRoute(path: AppRoutes.revision, builder: (context, state) => const StudySessionScreen()),
      GoRoute(path: AppRoutes.progress, builder: (context, state) => const ProgressScreen()),
      GoRoute(path: AppRoutes.search, builder: (context, state) => const SearchScreen()),
      GoRoute(path: AppRoutes.settings, builder: (context, state) => const SettingsScreen()),
      GoRoute(
        path: '/word/:id',
        builder: (context, state) => WordDetailScreen(wordId: int.parse(state.pathParameters['id']!)),
      ),
    ],
  );
}
