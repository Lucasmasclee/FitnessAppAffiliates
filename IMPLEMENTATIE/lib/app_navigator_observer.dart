import 'package:flutter/material.dart';

/// Route observer voor navigator. Gebruikt o.a. door WeekplanningScreen
/// om te refreshen wanneer de gebruiker terugkeert naar het scherm.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
