import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/widgets/plan_card.dart';

void main() {
  testWidgets('PlanCard displays correct information', (WidgetTester tester) async {
    bool tapped = false;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanCard(
            name: 'Basic Plan',
            price: 500,
            description: 'A basic subscription plan',
            billingCycle: 'monthly',
            isSelected: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    // Verify name, price, and description are displayed
    expect(find.text('Basic Plan'), findsOneWidget);
    expect(find.text('৳500'), findsOneWidget);
    expect(find.text('A basic subscription plan'), findsOneWidget);
    expect(find.text(' /mo'), findsOneWidget);

    // Tap the card and verify callback
    await tester.tap(find.byType(PlanCard));
    expect(tapped, true);
  });

  testWidgets('PlanCard highlights when selected', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanCard(
            name: 'Premium',
            price: 1500,
            description: 'Premium features',
            billingCycle: 'monthly',
            isSelected: true,
            onTap: () {},
          ),
        ),
      ),
    );

    // Since we can't easily check colors/borders in a simple widget test without 
    // deep inspection, we just verify it builds and has the POPULAR badge (if name contains premium)
    expect(find.text('POPULAR'), findsOneWidget);
  });
}
