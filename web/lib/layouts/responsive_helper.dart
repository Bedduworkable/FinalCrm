import 'package:flutter/material.dart';

class ResponsiveHelper {
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
          MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double getScreenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static int getKanbanColumns(BuildContext context) {
    if (isLargeDesktop(context)) return 6; // All columns visible
    if (isDesktop(context)) return 5;
    if (isTablet(context)) return 3;
    return 2; // Mobile fallback
  }

  static double getSidebarWidth(BuildContext context) {
    if (isLargeDesktop(context)) return 280;
    if (isDesktop(context)) return 240;
    return 200; // Tablet fallback
  }

  static double getContentPadding(BuildContext context) {
    if (isLargeDesktop(context)) return 32;
    if (isDesktop(context)) return 24;
    if (isTablet(context)) return 16;
    return 12;
  }

  static EdgeInsets getCardMargin(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.all(8);
    }
    return const EdgeInsets.symmetric(horizontal: 4, vertical: 6);
  }

  static double getLeadCardWidth(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    final columns = getKanbanColumns(context);
    final padding = getContentPadding(context);
    final sidebarWidth = getSidebarWidth(context);

    final availableWidth = screenWidth - sidebarWidth - (padding * 2);
    return (availableWidth / columns) - 16; // 16 for spacing
  }

  static BoxConstraints getModalConstraints(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    final screenHeight = getScreenHeight(context);

    if (isMobile(context)) {
      return BoxConstraints(
        maxWidth: screenWidth * 0.95,
        maxHeight: screenHeight * 0.9,
        minWidth: screenWidth * 0.95,
      );
    }

    if (isTablet(context)) {
      return BoxConstraints(
        maxWidth: 600,
        maxHeight: screenHeight * 0.85,
        minWidth: 500,
      );
    }

    // Desktop
    return BoxConstraints(
      maxWidth: 800,
      maxHeight: screenHeight * 0.8,
      minWidth: 600,
    );
  }

  static bool shouldShowSidebar(BuildContext context) => isDesktop(context);

  static bool shouldShowBottomNav(BuildContext context) => isMobile(context);

  static double getAppBarHeight(BuildContext context) {
    if (isMobile(context)) return 56;
    return 64; // Slightly taller for desktop
  }
}

// Responsive wrapper widget
class ResponsiveWrapper extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveWrapper({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (ResponsiveHelper.isDesktop(context)) {
          return desktop;
        } else if (ResponsiveHelper.isTablet(context) && tablet != null) {
          return tablet!;
        }
        return mobile;
      },
    );
  }
}