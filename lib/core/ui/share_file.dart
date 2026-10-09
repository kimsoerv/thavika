import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet for a file (save to Drive, send by email...).
Future<void> shareFile(BuildContext context, String path) async {
  // iPad needs a rectangle to anchor the share sheet to.
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  await SharePlus.instance.share(
    ShareParams(files: [XFile(path)], sharePositionOrigin: origin),
  );
}
