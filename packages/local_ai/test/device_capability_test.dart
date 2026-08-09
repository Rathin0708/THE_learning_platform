import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_ai/src/device_capability.dart';

/// Real test (THE-62) — actually queries this machine's RAM via the OS
/// command for the current platform, rather than mocking Process.run.
/// Every desktop dev/CI machine has real RAM to report, so a null result
/// here would indicate an actual regression, not an expected skip.
void main() {
  test('detectDeviceRamTier() returns a real tier for this machine, not null', () async {
    final tier = await detectDeviceRamTier();
    expect(tier, isNotNull);
    expect(ModelTier.values, contains(tier));
  });
}
