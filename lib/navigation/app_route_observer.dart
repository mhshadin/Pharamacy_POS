import 'package:flutter/material.dart';

/// Single [RouteObserver] for the app so screens like [HomeScreen] can use
/// [RouteAware] to stop the barcode camera when another route covers them.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
