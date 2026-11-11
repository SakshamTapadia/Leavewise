import 'package:flutter/material.dart';

/// Foundation shell only. The real application UI (onboarding, dashboard,
/// calendar and the rest) is tracked in TODO.md and is not built yet.
void main() {
  runApp(const LeaveWiseApp());
}

class LeaveWiseApp extends StatelessWidget {
  const LeaveWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeaveWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F2A60),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('LeaveWise')),
      ),
    );
  }
}
