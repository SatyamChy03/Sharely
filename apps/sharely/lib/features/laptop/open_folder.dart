import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger('OpenFolder');

/// Opens [folderPath] in the system file manager.
Future<void> openFolder(String folderPath) async {
  if (!await launchUrl(Uri.directory(folderPath))) {
    _log.warning('No app could open the folder');
  }
}
