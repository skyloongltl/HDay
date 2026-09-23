import 'package:flutter/animation.dart';

abstract final class WorkoutSkin {
  static const timerTick = Duration(seconds: 1);
  static const pressDuration = Duration(milliseconds: 100);
  static const setStatusDuration = Duration(milliseconds: 200);
  static const activeSetPulseDuration = Duration(milliseconds: 1800);
  static const progressDuration = Duration(milliseconds: 300);
  static const restRingDuration = Duration(milliseconds: 1000);
  static const overtimeDuration = Duration(milliseconds: 300);
  static const sheetDuration = Duration(milliseconds: 280);
  static const summaryPopDuration = Duration(milliseconds: 380);
  static const sheetFraction = 0.82;
  static const restRingSize = 140.0;
  static const summaryStatAspectRatio = 2.2;
  static const Curve sheetCurve = Cubic(0.32, 0.72, 0, 1);
  static const Curve activeSetPulseCurve = Curves.easeOut;
  static const Curve summaryPopCurve = Cubic(0.34, 1.56, 0.64, 1);
}
