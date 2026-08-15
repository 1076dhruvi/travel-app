import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/note_item.dart';

class NotesScreen extends StatefulWidget {
  final int tripId;

  const NotesScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final DatabaseService _databaseService = DatabaseService();

  List<Note> notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final result =
    await _databaseService.getNotesByTrip(widget.tripId);

    setState(() {
      notes = result;
    });
  }

  String _getTimestamp() {
    final now = DateTime.now();

    return "${now.day.toString().padLeft(2, '0')}/"
        "${now.month.toString().padLeft(2, '0')}/"
        "${now.year} "
        "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _showNoteDialog({Note? note}) async {
    final titleController =
    TextEditingController(text: note?.title ?? '');

    final contentController =
    TextEditingController(text: note?.content ?? '');

    int selectedColor =
        note?.color ?? Colors.deepPurple.value;

    bool reminderEnabled = note?.reminderTime != null;

    DateTime? reminderDateTime;

    if (note?.reminderTime != null) {
      reminderDateTime = DateTime.tryParse(note!.reminderTime!);
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                note == null ? "Add Note" : "Edit Note",
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "Title",
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: contentController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: "Note",
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Text("Color"),
                        const SizedBox(width: 12),

                        ...[
                          Colors.deepPurple,
                          Colors.blue,
                          Colors.green,
                          Colors.orange,
                          Colors.red,
                        ].map(
                              (color) => GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = color.value;
                              });
                            },
                            child: Container(
                              margin:
                              const EdgeInsets.only(right: 8),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor ==
                                      color.value
                                      ? Colors.black
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Set Reminder"),
                      value: reminderEnabled,
                      onChanged: (value) {
                        setDialogState(() {
                          reminderEnabled = value;

                          if (!value) {
                            reminderDateTime = null;
                          }
                        });
                      },
                    ),

                    if (reminderEnabled) ...[
                      const SizedBox(height: 8),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.calendar_today,
                          color: Colors.deepPurple,
                        ),
                        title: Text(
                          reminderDateTime == null
                              ? "Select date"
                              : "${reminderDateTime!.day.toString().padLeft(2, '0')}/"
                              "${reminderDateTime!.month.toString().padLeft(2, '0')}/"
                              "${reminderDateTime!.year}",
                        ),
                        onTap: () async {
                          final selectedDate =
                          await showDatePicker(
                            context: context,
                            initialDate:
                            reminderDateTime ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );

                          if (selectedDate != null) {
                            setDialogState(() {
                              reminderDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                reminderDateTime?.hour ?? 9,
                                reminderDateTime?.minute ?? 0,
                              );
                            });
                          }
                        },
                      ),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.access_time,
                          color: Colors.deepPurple,
                        ),
                        title: Text(
                          reminderDateTime == null
                              ? "Select time"
                              : reminderDateTime!
                              .hour
                              .toString()
                              .padLeft(2, '0') +
                              ":" +
                              reminderDateTime!
                                  .minute
                                  .toString()
                                  .padLeft(2, '0'),
                        ),
                        onTap: () async {
                          final selectedTime =
                          await showTimePicker(
                            context: context,
                            initialTime: reminderDateTime == null
                                ? TimeOfDay.now()
                                : TimeOfDay(
                              hour: reminderDateTime!.hour,
                              minute:
                              reminderDateTime!.minute,
                            ),
                          );

                          if (selectedTime != null) {
                            setDialogState(() {
                              final baseDate =
                                  reminderDateTime ??
                                      DateTime.now();

                              reminderDateTime = DateTime(
                                baseDate.year,
                                baseDate.month,
                                baseDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                            });
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        contentController.text.trim().isEmpty) {
                      return;
                    }

                    if (reminderEnabled &&
                        reminderDateTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                          Text("Please select date and time"),
                        ),
                      );
                      return;
                    }

                    if (note == null) {
                      final newNote = Note(
                        tripId: widget.tripId,
                        title: titleController.text.trim(),
                        content: contentController.text.trim(),
                        timestamp: _getTimestamp(),
                        color: selectedColor,
                        reminderTime:
                        reminderDateTime?.toIso8601String(),
                      );

                      final id =
                      await _databaseService.insertNote(newNote);

                      if (reminderDateTime != null) {
                        await NotificationService.scheduleNoteReminder(
                          id: id,
                          title: newNote.title,
                          content: newNote.content,
                          reminderTime: reminderDateTime!,
                        );
                      }
                    } else {
                      await NotificationService.cancelNoteReminder(
                        note.id!,
                      );

                      final updatedNote = Note(
                        id: note.id,
                        tripId: note.tripId,
                        title: titleController.text.trim(),
                        content: contentController.text.trim(),
                        timestamp: _getTimestamp(),
                        color: selectedColor,
                        isPinned: note.isPinned,
                        reminderTime:
                        reminderDateTime?.toIso8601String(),
                      );

                      await _databaseService.updateNote(updatedNote);

                      if (reminderDateTime != null) {
                        await NotificationService.scheduleNoteReminder(
                          id: note.id!,
                          title: updatedNote.title,
                          content: updatedNote.content,
                          reminderTime: reminderDateTime!,
                        );
                      }
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                    }

                    _loadNotes();
                  },
                  child: Text(
                    note == null ? "Add" : "Save",
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteNote(Note note) async {
    await NotificationService.cancelNoteReminder(note.id!);

    await _databaseService.deleteNote(note.id!);

    _loadNotes();
  }

  Future<void> _togglePin(Note note) async {
    await _databaseService.toggleNotePin(note);
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),

      appBar: AppBar(
        title: const Text("Notes"),
        backgroundColor: Colors.deepPurple,
      ),

      body: notes.isEmpty
          ? const Center(
        child: Text(
          "No notes yet",
          style: TextStyle(
            color: Colors.black54,
            fontSize: 16,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];

          return NoteItem(
            note: note,
            onEdit: () => _showNoteDialog(note: note),
            onDelete: () => _deleteNote(note),
            onPin: () => _togglePin(note),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteDialog(),
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }
}