import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/realtime_service.dart';
import '../tabs/devices_tab.dart';
import '../tabs/feed_tab.dart';
import '../tabs/partner_tab.dart';
import '../widgets/partner_request_dialog.dart';
import 'auth_screen.dart';

class MainLayout extends StatefulWidget {
  final String token;
  const MainLayout({super.key, required this.token});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _currentIndex = 0;

  late final List<Widget> _tabs;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabs = [
      FeedTab(token: widget.token),
      DevicesTab(token: widget.token),
      PartnerTab(token: widget.token),
    ];

    RealtimeService.instance.connect(widget.token);
    _eventSubscription = RealtimeService.instance.events.listen(_handleEvent);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndShowPendingPartnerRequests(context, widget.token);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      RealtimeService.instance.connect(widget.token);
      checkAndShowPendingPartnerRequests(context, widget.token);
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    if (event['type'] == 'partner_request') {
      checkAndShowPendingPartnerRequests(context, widget.token);
    }
  }

  void _logout() async {
    RealtimeService.instance.disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_jwt');
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kyndora'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dynamic_feed), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.devices), label: 'Geräte'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Partner'),
        ],
      ),
    );
  }
}