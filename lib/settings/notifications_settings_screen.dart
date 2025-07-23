import 'package:flutter/material.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  // State variables for notification toggles
  bool _pushNotifications = true;
  bool _weatherAlerts = true;
  bool _fieldReminderActivities = true;
  bool _fieldRemindMeAt = false;
  bool _pestReminderActivities = true;
  bool _pestRemindMeAt = false;
  bool _farmReminderActivities = true;
  bool _farmRemindMeAt = false;

  // Placeholder DateTime variables for "Remind Me At"
  DateTime? _fieldReminderTime;
  DateTime? _pestReminderTime;
  DateTime? _farmReminderTime;

  // Define custom green color
  final Color customGreen = const Color(0xFF003900);

  // Helper method to create a green circle with an icon
  Widget _buildIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: customGreen,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  // Method to show a custom dialog for picking date and time
  Future<DateTime?> _showDateTimePickerDialog(BuildContext context) async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    return await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Date and Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: dialogContext,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      selectedDate = pickedDate;
                    });
                  }
                },
                child: const Text('Pick Date'),
              ),
              if (selectedDate != null)
                Text('Selected Date: ${selectedDate.toString().substring(0, 10)}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: selectedDate != null
                    ? () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: dialogContext,
                          initialTime: TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setState(() {
                            selectedTime = pickedTime;
                          });
                        }
                      }
                    : null,
                child: const Text('Pick Time'),
              ),
              if (selectedTime != null)
                Text('Selected Time: ${selectedTime!.format(context)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: (selectedDate != null && selectedTime != null)
                  ? () {
                      final DateTime combinedDateTime = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      Navigator.pop(dialogContext, combinedDateTime);
                    }
                  : null,
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder method to simulate getting reminder time from another section
  DateTime? _getReminderTimeFromSection(String section) {
    switch (section) {
      case 'field':
        return _fieldReminderActivities ? DateTime.now().add(const Duration(hours: 1)) : null;
      case 'pest':
        return _pestReminderActivities ? DateTime.now().add(const Duration(hours: 2)) : null;
      case 'farm':
        return _farmReminderActivities ? DateTime.now().add(const Duration(hours: 3)) : null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth - 32.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Settings',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: customGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'General Notification',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: customGreen,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          secondary: _buildIcon(Icons.notifications),
                          title: Text(
                            'Send Me Push Notifications',
                            style: TextStyle(color: customGreen),
                          ),
                          value: _pushNotifications,
                          activeColor: customGreen,
                          onChanged: (bool value) {
                            setState(() {
                              _pushNotifications = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Field Data Input Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: customGreen,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          secondary: _buildIcon(Icons.cloud),
                          title: Text(
                            'Weather Alerts',
                            style: TextStyle(color: customGreen),
                          ),
                          value: _weatherAlerts,
                          activeColor: customGreen,
                          onChanged: (bool value) {
                            setState(() {
                              _weatherAlerts = value;
                            });
                          },
                        ),
                        const Divider(height: 1, thickness: 1, indent: 50),
                        SwitchListTile(
                          secondary: _buildIcon(Icons.event),
                          title: Text(
                            'Remind Me About Activities Set on Reminder',
                            style: TextStyle(color: customGreen),
                          ),
                          value: _fieldReminderActivities,
                          activeColor: customGreen,
                          onChanged: (bool value) {
                            setState(() {
                              _fieldReminderActivities = value;
                              if (!value) _fieldRemindMeAt = false;
                            });
                          },
                        ),
                        const Divider(height: 1, thickness: 1, indent: 50),
                        ListTile(
                          leading: _buildIcon(Icons.access_time),
                          title: Text(
                            'Remind Me At${_fieldRemindMeAt && _fieldReminderTime != null ? ' ($_fieldReminderTime)' : ''}',
                            style: TextStyle(color: customGreen),
                          ),
                          trailing: Switch(
                            value: _fieldRemindMeAt,
                            activeColor: customGreen,
                            onChanged: _fieldReminderActivities
                                ? (bool value) async {
                                    setState(() {
                                      _fieldRemindMeAt = value;
                                    });
                                    if (value) {
                                      if (_fieldReminderActivities) {
                                        final autoTime = _getReminderTimeFromSection('field');
                                        if (autoTime != null) {
                                          setState(() {
                                            _fieldReminderTime = autoTime;
                                          });
                                        } else if (mounted) {
                                          final time = await _showDateTimePickerDialog(context);
                                          if (time != null) {
                                            setState(() {
                                              _fieldReminderTime = time;
                                            });
                                          }
                                        }
                                      } else if (mounted) {
                                        final time = await _showDateTimePickerDialog(context);
                                        if (time != null) {
                                          setState(() {
                                            _fieldReminderTime = time;
                                          });
                                        }
                                      }
                                    } else {
                                      setState(() {
                                        _fieldReminderTime = null;
                                      });
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pest Management Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: customGreen,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          secondary: _buildIcon(Icons.bug_report),
                          title: Text(
                            'Remind Me About Activities Set on Reminder',
                            style: TextStyle(color: customGreen),
                          ),
                          value: _pestReminderActivities,
                          activeColor: customGreen,
                          onChanged: (bool value) {
                            setState(() {
                              _pestReminderActivities = value;
                              if (!value) _pestRemindMeAt = false;
                            });
                          },
                        ),
                        const Divider(height: 1, thickness: 1, indent: 50),
                        ListTile(
                          leading: _buildIcon(Icons.access_time),
                          title: Text(
                            'Remind Me At${_pestRemindMeAt && _pestReminderTime != null ? ' ($_pestReminderTime)' : ''}',
                            style: TextStyle(color: customGreen),
                          ),
                          trailing: Switch(
                            value: _pestRemindMeAt,
                            activeColor: customGreen,
                            onChanged: _pestReminderActivities
                                ? (bool value) async {
                                    setState(() {
                                      _pestRemindMeAt = value;
                                    });
                                    if (value) {
                                      if (_pestReminderActivities) {
                                        final autoTime = _getReminderTimeFromSection('pest');
                                        if (autoTime != null) {
                                          setState(() {
                                            _pestReminderTime = autoTime;
                                          });
                                        } else if (mounted) {
                                          final time = await _showDateTimePickerDialog(context);
                                          if (time != null) {
                                            setState(() {
                                              _pestReminderTime = time;
                                            });
                                          }
                                        }
                                      } else if (mounted) {
                                        final time = await _showDateTimePickerDialog(context);
                                        if (time != null) {
                                          setState(() {
                                            _pestReminderTime = time;
                                          });
                                        }
                                      }
                                    } else {
                                      setState(() {
                                        _pestReminderTime = null;
                                      });
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Farm Management Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: customGreen,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          secondary: _buildIcon(Icons.agriculture),
                          title: Text(
                            'Remind Me About Activities Set on Reminder',
                            style: TextStyle(color: customGreen),
                          ),
                          value: _farmReminderActivities,
                          activeColor: customGreen,
                          onChanged: (bool value) {
                            setState(() {
                              _farmReminderActivities = value;
                              if (!value) _farmRemindMeAt = false;
                            });
                          },
                        ),
                        const Divider(height: 1, thickness: 1, indent: 50),
                        ListTile(
                          leading: _buildIcon(Icons.access_time),
                          title: Text(
                            'Remind Me At${_farmRemindMeAt && _farmReminderTime != null ? ' ($_farmReminderTime)' : ''}',
                            style: TextStyle(color: customGreen),
                          ),
                          trailing: Switch(
                            value: _farmRemindMeAt,
                            activeColor: customGreen,
                            onChanged: _farmReminderActivities
                                ? (bool value) async {
                                    setState(() {
                                      _farmRemindMeAt = value;
                                    });
                                    if (value) {
                                      if (_farmReminderActivities) {
                                        final autoTime = _getReminderTimeFromSection('farm');
                                        if (autoTime != null) {
                                          setState(() {
                                            _farmReminderTime = autoTime;
                                          });
                                        } else if (mounted) {
                                          final time = await _showDateTimePickerDialog(context);
                                          if (time != null) {
                                            setState(() {
                                              _farmReminderTime = time;
                                            });
                                          }
                                        }
                                      } else if (mounted) {
                                        final time = await _showDateTimePickerDialog(context);
                                        if (time != null) {
                                          setState(() {
                                            _farmReminderTime = time;
                                          });
                                        }
                                      }
                                    } else {
                                      setState(() {
                                        _farmReminderTime = null;
                                      });
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}