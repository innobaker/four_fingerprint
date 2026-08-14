# four_fingerprint

Contactless slap fingerprint capture for Flutter — 4-4-2 sequencing, minutiae extraction, and matching via phone camera.

## Installation

```yaml
dependencies:
  four_fingerprint: ^2.0.0
```

Run `flutter pub get`.

## Usage

```dart
import 'package:four_fingerprint/four_fingerprint.dart';

await FourFingerprint.instance.initialize();

final controller = FpCaptureController();
await controller.initialize();

// Start 4-4-2 capture
controller.startCapture();
cam.startImageStream((image) async {
  await controller.processFrame(image);
});

// Save enrollment
final enrollment = controller.buildEnrollment('user_001');
await FpSecureStorage().storeEnrollment(enrollment!);
```

## Screenshots

<table>
  <tr>
    <td><img src="screenshots/left_slap.png" width="200"></td>
    <td><img src="screenshots/right_slap.png" width="200"></td>
    <td><img src="screenshots/thumbs.png" width="200"></td>
  </tr>
</table>

## API

| Class | Purpose |
|-------|---------|
| `FourFingerprint` | Plugin entry point. Initializes native processing. |
| `FpCaptureController` | 4-4-2 capture state machine with burst frame selection. |
| `FpSecureStorage` | Encrypted template storage via `flutter_secure_storage`. |
| `FpEnrollmentRecord` | Enrollment data model. |
| `FpMatchResult` | Verification result with score and match decision. |

## Platform support

| Platform | Supported |
|----------|-----------|
| Android  | Yes |
| iOS      | Yes |
| Linux    | Yes (requires system OpenCV) |

