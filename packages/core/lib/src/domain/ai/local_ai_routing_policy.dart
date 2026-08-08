/// Local-AI routing discipline (THE-55, spec 8.5) and platform gating
/// (THE-56, spec 7.3/12), encoded as real, checkable code rather than
/// left as an implicit fact that happens to be true only because no LLM
/// integration exists yet.
///
/// Every interaction type in the app must declare where it's routed.
/// [InteractionType.openEndedExplanation] is the only type ever allowed
/// to reach a local LLM — everything else routes to the database or the
/// scripted Engine A conversation matcher, per spec 8.5's table exactly.
enum InteractionType {
  normalLookup,
  existingTranslation,
  lessonContent,
  quiz,
  scriptedConversation,
  openEndedExplanation,
}

enum RoutingDestination { database, conversationEngineA, localLlm }

class LocalAiRoutingPolicy {
  static const Map<InteractionType, RoutingDestination> _routes = {
    InteractionType.normalLookup: RoutingDestination.database,
    InteractionType.existingTranslation: RoutingDestination.database,
    InteractionType.lessonContent: RoutingDestination.database,
    InteractionType.quiz: RoutingDestination.database,
    InteractionType.scriptedConversation: RoutingDestination.conversationEngineA,
    InteractionType.openEndedExplanation: RoutingDestination.localLlm,
  };

  RoutingDestination routeFor(InteractionType type) {
    final destination = _routes[type];
    if (destination == null) {
      throw StateError('No routing declared for $type — every InteractionType must be routed explicitly.');
    }
    return destination;
  }

  bool requiresLocalLlm(InteractionType type) => routeFor(type) == RoutingDestination.localLlm;
}

/// Platform tier gate (THE-56): local LLM usage stays desktop-weighted
/// per spec — never forced onto mobile hardware. [DevicePlatform] is
/// intentionally app-agnostic (no dart:io / Platform.isX dependency in
/// this pure-Dart domain file); the caller resolves the actual platform
/// and passes it in.
enum DevicePlatform { android, ios, windows, macos, linux, web }

class LocalAiPlatformGate {
  /// Whether local-LLM features (Engine B) should even be offered on this
  /// platform. False for mobile (Android/iOS) and web — true for desktop.
  bool isLocalAiAvailable(DevicePlatform platform) => switch (platform) {
        DevicePlatform.windows || DevicePlatform.macos || DevicePlatform.linux => true,
        DevicePlatform.android || DevicePlatform.ios || DevicePlatform.web => false,
      };
}
