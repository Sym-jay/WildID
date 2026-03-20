import 'package:flutter/material.dart';

/// Responsive layout helper for mobile, tablet, and desktop support
class ResponsiveHelper {
  ResponsiveHelper._();

  // Breakpoints for different screen sizes
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;

  // Device type detection
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isLargeTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  // Screen dimensions
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static double devicePixelRatio(BuildContext context) =>
      MediaQuery.of(context).devicePixelRatio;

  // Safe area constraints
  static EdgeInsets safeAreaPadding(BuildContext context) =>
      MediaQuery.of(context).padding;

  static EdgeInsets viewInsets(BuildContext context) =>
      MediaQuery.of(context).viewInsets;

  // Text scale factor
  static double textScaleFactor(BuildContext context) =>
      MediaQuery.of(context).textScaleFactor;

  // Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24.0);
    } else {
      return const EdgeInsets.all(32.0);
    }
  }

  // Get responsive spacing
  static double getResponsiveSpacing(BuildContext context) {
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 24.0;
    return 32.0;
  }

  // Get responsive font size
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobileSize,
    double? tabletSize,
    double? desktopSize,
  }) {
    tabletSize ??= mobileSize * 1.1;
    desktopSize ??= mobileSize * 1.2;

    if (isMobile(context)) return mobileSize;
    if (isTablet(context)) return tabletSize;
    return desktopSize;
  }

  // Get number of columns based on device
  static int getGridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }

  // Get responsive cross axis count for grids
  static int getResponsiveCrossAxisCount(BuildContext context) {
    final width = screenWidth(context);
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1200) return 3;
    return 4;
  }

  // Max width constraints
  static double getMaxWidth(BuildContext context) {
    if (isMobile(context)) return double.infinity;
    if (isTablet(context)) return 800.0;
    return 1200.0;
  }

  // Get keyboard height
  static double getKeyboardHeight(BuildContext context) =>
      viewInsets(context).bottom;

  static bool isKeyboardVisible(BuildContext context) =>
      getKeyboardHeight(context) > 0;
}

/// Responsive layout builder widget
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget? tabletLayout;
  final Widget? desktopLayout;

  const ResponsiveLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
    this.desktopLayout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return mobileLayout;
        } else if (constraints.maxWidth < 900) {
          return tabletLayout ?? mobileLayout;
        } else {
          return desktopLayout ?? tabletLayout ?? mobileLayout;
        }
      },
    );
  }
}

/// Responsive grid view builder
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final double spacing;
  final double runSpacing;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16.0),
    this.spacing = 16.0,
    this.runSpacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount =
        ResponsiveHelper.getResponsiveCrossAxisCount(context);

    return Padding(
      padding: padding,
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: runSpacing,
        crossAxisSpacing: spacing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}

/// Responsive column with max width constraint
class ResponsiveColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final EdgeInsets padding;

  const ResponsiveColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = ResponsiveHelper.getMaxWidth(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: mainAxisSize,
            children: children,
          ),
        ),
      ),
    );
  }
}
