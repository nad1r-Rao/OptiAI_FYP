import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import 'package:flutter_timezone/flutter_timezone.dart';

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  CalendarService() {
    _init();
  }

  Future<void> _init() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Fallback to UTC or default if timezone detection fails
      print("Failed to get local timezone: $e");
    }
  }

  Future<bool> requestPermissions() async {
    var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
      permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
        return false;
      }
    }
    return true;
  }

  Future<List<Event>> getEventsForDay(DateTime date) async {
    if (!await requestPermissions()) return [];

    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (!calendarsResult.isSuccess || calendarsResult.data == null) return [];

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    List<Event> allEvents = [];

    // Retrieve events from all writable calendars (usually the main ones)
    for (var calendar in calendarsResult.data!) {
      if (calendar.isReadOnly == false) {
        final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(
            startDate: startOfDay,
            endDate: endOfDay,
          ),
        );

        if (eventsResult.isSuccess && eventsResult.data != null) {
          allEvents.addAll(eventsResult.data!);
        }
      }
    }

    return allEvents;
  }

  Future<String> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
  }) async {
    // 1. Check/Request Permissions
    final hasPerms = await requestPermissions();
    if (!hasPerms) {
      return "Permission denied. Please enable Calendar access in Settings.";
    }

    // 2. Retrieve Calendars
    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    
    if (!calendarsResult.isSuccess) {
      final errors = calendarsResult.errors.map((e) => e.errorMessage).join(', ');
      return "Error accessing calendars: $errors";
    }
    
    if (calendarsResult.data == null || calendarsResult.data!.isEmpty) {
      return "No calendars found on your device. Please ensure you have a calendar account setup.";
    }

    // 3. Select Default Calendar
    // Try to find a writable calendar that is default, or just any writable one.
    Calendar? targetCalendar;
    try {
      targetCalendar = calendarsResult.data!.firstWhere((c) => c.isReadOnly == false && c.isDefault == true);
    } catch (_) {
      try {
        targetCalendar = calendarsResult.data!.firstWhere((c) => c.isReadOnly == false);
      } catch (_) {
        return "No writable calendars found.";
      }
    }

    if (targetCalendar == null) return "Could not find a suitable calendar.";

    // 4. Create Event
    final event = Event(
      targetCalendar.id,
      title: title,
      start: tz.TZDateTime.from(startTime, tz.local),
      end: tz.TZDateTime.from(endTime, tz.local),
      description: description,
    );

    final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
    if (result?.isSuccess == true) {
      return "Event created in calendar: '${targetCalendar.name}' (${targetCalendar.accountName})";
    } else {
      final errors = result?.errors.map((e) => e.errorMessage).join(', ') ?? "Unknown error";
      return "Failed to create event: $errors";
    }
  }

  Future<String> deleteEvent(String title) async {
    if (!await requestPermissions()) return "Permission denied";

    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (!calendarsResult.isSuccess || calendarsResult.data == null) {
      return "No calendars found";
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day); // Start of today
    final end = start.add(const Duration(days: 2)); // Look ahead 48 hours

    for (var calendar in calendarsResult.data!) {
      if (calendar.isReadOnly == false) {
        final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(startDate: start, endDate: end),
        );

        if (eventsResult.isSuccess && eventsResult.data != null) {
          // Find event with matching title (case-insensitive partial match)
          try {
            final eventToDelete = eventsResult.data!.firstWhere(
              (e) => e.title!.toLowerCase().contains(title.toLowerCase()),
            );

            final deleteResult = await _deviceCalendarPlugin.deleteEvent(
              calendar.id,
              eventToDelete.eventId!,
            );

            if (deleteResult.isSuccess && deleteResult.data == true) {
              return "Deleted '${eventToDelete.title}' from ${calendar.name}";
            }
          } catch (e) {
            // Continue searching other calendars if not found here
          }
        }
      }
    }
    return "Could not find any event matching '$title' in the next 48 hours.";
  }
}
