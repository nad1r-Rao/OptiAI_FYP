import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../providers/speech_provider.dart';

class GlassesStatus extends StatefulWidget {
  const GlassesStatus({super.key});

  @override
  State<GlassesStatus> createState() => _GlassesStatusState();
}

class _GlassesStatusState extends State<GlassesStatus> {
  bool _isConnected = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    // Poll every 5 seconds
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _checkConnection());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final aiService = context.read<AiService>();
    final connected = await aiService.checkEsp32Connection();
    if (mounted && connected != _isConnected) {
      setState(() {
        _isConnected = connected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final speechProvider = context.watch<SpeechProvider>(); // Watch for awake state
    final isAwake = speechProvider.isAwake;

    // Determine status text and color
    String statusText;
    Color statusColor;

    if (!_isConnected) {
      statusText = 'Camera Not Attached';
      statusColor = Colors.red;
    } else if (isAwake) {
      statusText = 'Listening...';
      statusColor = AppColors.neonBlue;
    } else {
      statusText = 'Standby (Say "Opti")';
      statusColor = AppColors.neonGreen;
    }

    return InkWell(
      onTap: () {
        // Manual retry on tap
        _checkConnection();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Checking connection..."), duration: Duration(seconds: 1)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/glasses.png',
              width: 24,
              height: 24,
              color: statusColor,
            ),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: AppFonts.body.copyWith(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
