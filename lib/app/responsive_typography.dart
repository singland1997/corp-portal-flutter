import 'package:flutter/widgets.dart';

/// CSS/logical viewport width, not physical monitor pixels. Browser zoom naturally
/// reduces this width. Preserve the user's accessibility scaler, including nonlinear scaling.
double viewportFontScale(double width) => 1 + ((width - 1920) / 1920).clamp(0, 1) * .4;

class ResponsiveTypography extends StatelessWidget {
  const ResponsiveTypography({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: ViewportTextScaler(media.textScaler, viewportFontScale(media.size.width))),
      child: child,
    );
  }
}

class ViewportTextScaler extends TextScaler {
  const ViewportTextScaler(this.accessibility, this.viewportScale);
  final TextScaler accessibility;
  final double viewportScale;
  @override
  double scale(double fontSize) => accessibility.scale(fontSize) * viewportScale;
  @override
  double get textScaleFactor => scale(14) / 14;
  @override
  bool operator ==(Object other) => other is ViewportTextScaler && other.accessibility == accessibility && other.viewportScale == viewportScale;
  @override
  int get hashCode => Object.hash(accessibility, viewportScale);
}
