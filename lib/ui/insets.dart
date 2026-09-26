import 'package:flutter/widgets.dart';

/// Padding for a full-screen scrolling list. Android 15+ draws apps behind
/// the navigation bar, and a ListView with explicit padding no longer adds
/// room for it, so the last items would sit under the bar.
EdgeInsets screenListPadding(
  BuildContext context, {
  double all = 16,
  double extraBottom = 0,
}) => EdgeInsets.fromLTRB(
  all,
  all,
  all,
  all + extraBottom + MediaQuery.viewPaddingOf(context).bottom,
);
