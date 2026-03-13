import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trip_dashboard/main.dart';

void main() {
  testWidgets('App loads test', (WidgetTester tester) async {

    await tester.pumpWidget(const TripDashboardApp());

    expect(find.text('My Trips'), findsOneWidget);

  });
}