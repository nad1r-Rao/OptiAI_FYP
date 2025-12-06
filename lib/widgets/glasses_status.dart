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
  bool _isChecking = false;  // Prevent concurrent checks
  DateTime? _lastCheckTime;  // For debouncing manual checks
  
  // Configuration
  static const Duration _debounceInterval = Duration(seconds: 5); // Minimum time between manual checks

  @override
  void initState() {
    super.initState();
    // Delay initial check slightly to let app initialize
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _checkConnection();
    });
    // Automatic periodic polling removed as per user request
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkConnection({bool manual = false}) async {
    // Prevent concurrent checks
    if (_isChecking) {
      debugPrint('GlassesStatus: Check already in progress, skipping');
      return;
    }
    
    // Debounce manual checks (prevent spam clicking)
    if (manual && _lastCheckTime != null) {
      final timeSinceLastCheck = DateTime.now().difference(_lastCheckTime!);
      if (timeSinceLastCheck < _debounceInterval) {
        debugPrint('GlassesStatus: Debouncing manual check (${timeSinceLastCheck.inSeconds}s < ${_debounceInterval.inSeconds}s)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Please wait ${_debounceInterval.inSeconds - timeSinceLastCheck.inSeconds}s before checking again"),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        return;
      }
    }
    
    if (mounted) {
      setState(() => _isChecking = true);
    }
    
    _lastCheckTime = DateTime.now();
    
    try {
      final aiService = context.read<AiService>();
      final connected = await aiService.checkEsp32Connection();
      
      if (mounted && connected != _isConnected) {
        setState(() {
          _isConnected = connected;
        });
        debugPrint('GlassesStatus: Connection state changed to $connected');
      }
    } catch (e) {
      debugPrint('GlassesStatus: Error checking connection - $e');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final speechProvider = context.watch<SpeechProvider>();
    final isAwake = speechProvider.isAwake;

    // Determine status text and color
    String statusText;
    Color statusColor;
    IconData? statusIcon;

    if (_isChecking) {
      statusText = 'Checking...';
      statusColor = Colors.orange;
      statusIcon = Icons.sync;
    } else if (!_isConnected) {
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
      onTap: _isChecking ? null : () {
        // Manual retry on tap with debouncing
        _checkConnection(manual: true);
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
            if (_isChecking)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              )
            else
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

