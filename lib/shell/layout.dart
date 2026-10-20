/// 依視窗寬度決定的導覽型態。
enum NavMode { drawer, rail, extended }

const double contentMaxWidth = 1280;

NavMode navModeFor(double width) {
  if (width < 600) return NavMode.drawer;
  if (width < 1200) return NavMode.rail;
  return NavMode.extended;
}

double horizontalPadding(double width) => width < 600 ? 16 : 32;
