/// Android: read Play Install Referrer (affiliate_code set by our redirect URL).
import 'package:android_play_install_referrer/android_play_install_referrer.dart';

Future<String?> getInstallReferrerString() async {
  try {
    final ref = await AndroidPlayInstallReferrer.installReferrer;
    final raw = ref.installReferrer;
    return (raw != null && raw.isNotEmpty) ? raw : null;
  } catch (_) {
    return null;
  }
}
