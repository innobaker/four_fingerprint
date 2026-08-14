import 'package:flutter/material.dart';
import 'package:four_fingerprint/four_fingerprint.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: HomePage(),
    debugShowCheckedModeBanner: false,
  ));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _scan(
    BuildContext context, {
    required CaptureProfile profile,
    StorageMode storage = StorageMode.device,
    FingerCode singleFinger = FingerCode.rightIndex,
  }) async {
    final result = await FourFingerprint.scan(
      context,
      subjectId: 'user_001',
      profile: profile,
      storage: storage,
      singleFinger: singleFinger,
    );
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? '${result.profile.name}: '
                  '${result.enrollment?.fingers.length ?? 0} fingers'
              : 'Failed: ${result.error}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('four_fingerprint')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Pick a capture profile — 4-4-2 is optional.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _scan(context, profile: CaptureProfile.fourFour),
            child: const Text('4-4 (left + right slap)'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () =>
                _scan(context, profile: CaptureProfile.fourFourTwo),
            child: const Text('4-4-2 (slap + thumbs)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _scan(context, profile: CaptureProfile.thumbs),
            child: const Text('Thumbs only (2)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _scan(
              context,
              profile: CaptureProfile.single,
              singleFinger: FingerCode.rightIndex,
            ),
            child: const Text('Single finger (right index)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _scan(
              context,
              profile: CaptureProfile.fourFour,
              storage: StorageMode.callback,
            ),
            child: const Text('4-4 → backend callback (no device store)'),
          ),
          const SizedBox(height: 24),
          const Text('Inline scanner (right slap only):'),
          const SizedBox(height: 8),
          SizedBox(
            height: 360,
            child: SlapScanner(
              subjectId: 'user_inline',
              profile: CaptureProfile.rightFour,
              storage: StorageMode.both,
              onResult: (r) => debugPrint('inline: ${r.success}'),
            ),
          ),
        ],
      ),
    );
  }
}
