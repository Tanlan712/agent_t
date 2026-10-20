/// 依視窗寬度決定的導覽型態（MASTER.md 第 3 節）。
enum NavMode { bottom, rail, extended }

const double contentMaxWidth = 1280;

NavMode navModeFor(double width) {
  if (width < 600) return NavMode.bottom;
  if (width < 1024) return NavMode.rail;
  return NavMode.extended;
}

double horizontalPadding(double width) => width < 600 ? 16 : 32;
