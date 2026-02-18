import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do List',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const TodoHomePage(),
    );
  }
}

class Task {
  Task({
    required this.id,
    required this.title,
    this.isDone = false,
    required this.createdAt,
  });

  final String id;
  final String title;
  bool isDone;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'isDone': isDone,
        'createdAt': createdAt.toIso8601String(),
      };

  static Task fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as String,
        title: map['title'] as String,
        isDone: map['isDone'] as bool? ?? false,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  static const _storageKey = 'tasks_v1';
  final _uuid = const Uuid();
  final List<Task> _tasks = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.trim().isEmpty) {
 
      _tasks
        ..clear()
        ..addAll([
          Task(
            id: _uuid.v4(),
            title: 'Read Flutter docs for 30 minutes',
            createdAt: DateTime.now(),
          ),
          Task(
            id: _uuid.v4(),
            title: 'Build To-Do UI (ListView + Checkbox)',
            createdAt: DateTime.now(),
          ),
          Task(
            id: _uuid.v4(),
            title: 'Add SharedPreferences persistence',
            createdAt: DateTime.now(),
          ),
          Task(
            id: _uuid.v4(),
            title: 'Take screenshots for README',
            createdAt: DateTime.now(),
          ),
          Task(
            id: _uuid.v4(),
            title: 'Push project to GitHub repository',
            createdAt: DateTime.now(),
          ),
        ]);
      await _saveTasks();
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final loaded = decoded
          .whereType<Map<String, dynamic>>()
          .map(Task.fromMap)
          .toList();

      _tasks
        ..clear()
        ..addAll(loaded);
    } catch (_) {
      
      _tasks
        ..clear()
        ..addAll([
          Task(
            id: _uuid.v4(),
            title: 'Welcome! Add your first task',
            createdAt: DateTime.now(),
          ),
        ]);
      await _saveTasks();
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_tasks.map((t) => t.toMap()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> _addTaskDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Task'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Task title',
              hintText: 'e.g., Finish assignment',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Title is required';
              if (v.length < 2) return 'Title is too short';
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == null) return;

    setState(() {
      _tasks.insert(
        0,
        Task(
          id: _uuid.v4(),
          title: result,
          createdAt: DateTime.now(),
        ),
      );
    });
    await _saveTasks();
  }

  Future<void> _toggleDone(Task task) async {
    setState(() => task.isDone = !task.isDone);
    await _saveTasks();
  }

  Future<void> _deleteTask(Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Remove "${task.title}" from the list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _tasks.removeWhere((t) => t.id == task.id));
    await _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _tasks.where((t) => t.isDone).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '$doneCount/${_tasks.length} done',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTaskDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(
                  child: Text(
                    'No tasks yet.\nTap + to add one.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = _tasks[index];

                    return Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 1,
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: Checkbox(
                          value: task.isDone,
                          onChanged: (_) => _toggleDone(task),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration:
                                task.isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          'Created: ${_formatDate(task.createdAt)}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteTask(task),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(DateTime dt) {

    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
