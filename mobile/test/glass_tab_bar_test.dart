import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_action/widgets/glass_tab_bar.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('segment labels sit in the vertical centre of the control', (tester) async {
    await pump(
      tester,
      GlassSegmentedControl(
        selectedIndex: 0,
        onSelected: (_) {},
        tabs: const [
          GlassTab(label: 'Open', badge: 4),
          GlassTab(label: 'All', badge: 8),
        ],
      ),
    );

    final control = tester.getCenter(find.byType(GlassSegmentedControl)).dy;
    expect(tester.getCenter(find.text('Open')).dy, moreOrLessEquals(control, epsilon: 1));
    expect(tester.getCenter(find.text('All')).dy, moreOrLessEquals(control, epsilon: 1));
  });

  testWidgets('tab bar icon and label are centred as a group', (tester) async {
    await pump(
      tester,
      GlassTabBar(
        selectedIndex: 0,
        onSelected: (_) {},
        tabs: const [
          GlassTab(icon: Icons.event_note_outlined, label: 'Meetings'),
          GlassTab(icon: Icons.checklist_outlined, label: 'Actions'),
        ],
      ),
    );

    final bar = tester.getRect(find.byType(GlassTabBar).first);
    final icon = tester.getRect(find.byIcon(Icons.event_note_outlined));
    final label = tester.getRect(find.text('Meetings'));
    final groupCentre = (icon.top + label.bottom) / 2;
    // The bar's own SafeArea adds 10 px below the capsule.
    expect(groupCentre, moreOrLessEquals(bar.center.dy - 5, epsilon: 1.5));
  });
}
