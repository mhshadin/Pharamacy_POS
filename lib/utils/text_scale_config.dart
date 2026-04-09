import 'package:flutter/widgets.dart';

/// After neutralizing OS text scaling in [MaterialApp.builder], optionally multiply
/// all text. Use `1.0` for design-tuned sizes. Try `0.92`–`0.98` if every device
/// should look slightly smaller (does not fix width-based [ResponsiveHelper] sizes).
const double kAppVisualTextScale = 1.0;

/// Final scaler for the app subtree (replaces OS text scale).
TextScaler appRootTextScaler() => TextScaler.linear(kAppVisualTextScale);
