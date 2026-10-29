import 'package:flutter/material.dart';

import '../widgets/glass_tab_bar.dart';
import 'actions_screen.dart';
import 'meetings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _visits = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Content scrolls under the floating tab bar, which blurs it.
      extendBody: true,
      // A fresh key per visit reloads the tab, so actions accepted elsewhere show up.
      body: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _index == 0
            ? MeetingsScreen(key: ValueKey('meetings-$_visits'))
            : ActionsScreen(key: ValueKey('actions-$_visits')),
      ),
      bottomNavigationBar: GlassTabBar(
        selectedIndex: _index,
        onSelected: (index) => setState(() {
          _index = index;
          _visits++;
        }),
        tabs: const [
          GlassTab(icon: Icons.event_note_outlined, selectedIcon: Icons.event_note, label: 'Meetings'),
          GlassTab(icon: Icons.checklist_outlined, selectedIcon: Icons.checklist, label: 'Actions'),
        ],
      ),
    );
  }
}
