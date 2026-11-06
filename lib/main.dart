import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyDaysApp());
}

class MyDaysApp extends StatelessWidget {
  const MyDaysApp({super.key});

  static const deepIndigo = Color(0xFF2A1E5C);
  static const coral = Color(0xFFFF6B5B);
  static const softWhite = Color(0xFFF8F6FF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "My Day's",
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: deepIndigo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: coral,
          brightness: Brightness.dark,
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

// Welcome screen
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                "my day's",
                style: TextStyle(
                  color: MyDaysApp.softWhite,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B2D70),
                    borderRadius: BorderRadius.circular(48),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: MyDaysApp.coral,
                    size: 100,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                'Your memories,\nyour universe.',
                style: TextStyle(
                  color: MyDaysApp.softWhite,
                  fontSize: 38,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Turn your everyday moments into stories '
                'worth reliving.',
                style: TextStyle(
                  color: Color(0xFFC9C2E0),
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MemoryLibraryScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyDaysApp.coral,
                    foregroundColor: MyDaysApp.deepIndigo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Explore my memories',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Every moment has a story.',
                  style: TextStyle(
                    color: Color(0xFFA9A0CA),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// One memory model
class Memory {
  const Memory({
    required this.title,
    required this.description,
    required this.createdAt,
  });

  final String title;
  final String description;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      title: json['title'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

// Local memory storage
class MemoryStorage {
  static const _storageKey = 'my_days_memories';

  static Future<List<Memory>> loadMemories() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);

    if (stored == null) return [];

    try {
      final decoded = jsonDecode(stored) as List<dynamic>;
      return decoded
          .map(
            (item) => Memory.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveMemory(Memory memory) async {
    final prefs = await SharedPreferences.getInstance();
    final memories = await loadMemories();

    memories.insert(0, memory);

    final encoded = jsonEncode(
      memories.map((item) => item.toJson()).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }
}

// Memory library screen
class MemoryLibraryScreen extends StatefulWidget {
  const MemoryLibraryScreen({super.key});

  @override
  State<MemoryLibraryScreen> createState() =>
      _MemoryLibraryScreenState();
}

class _MemoryLibraryScreenState extends State<MemoryLibraryScreen> {
  List<Memory> _memories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    final memories = await MemoryStorage.loadMemories();

    if (!mounted) return;

    setState(() {
      _memories = memories;
      _isLoading = false;
    });
  }

  Future<void> _openCreateMemory() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateMemoryScreen(),
      ),
    );

    if (saved == true) {
      await _loadMemories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Memory Library'),
        backgroundColor: MyDaysApp.deepIndigo,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateMemory,
        backgroundColor: MyDaysApp.coral,
        foregroundColor: MyDaysApp.deepIndigo,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New memory'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _memories.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_stories_rounded,
                          size: 64,
                          color: MyDaysApp.coral,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Your story starts here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Save a moment you want to remember, '
                          'and it will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFC9C2E0),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _openCreateMemory,
                          icon: const Icon(Icons.add),
                          label: const Text('Create my first memory'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MyDaysApp.coral,
                            foregroundColor: MyDaysApp.deepIndigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _memories.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final memory = _memories[index];

                    return Card(
                      color: const Color(0xFF3B2D70),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const CircleAvatar(
                          backgroundColor: MyDaysApp.coral,
                          foregroundColor: MyDaysApp.deepIndigo,
                          child: Icon(Icons.auto_stories_rounded),
                        ),
                        title: Text(
                          memory.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            memory.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MemoryDetailsScreen(memory: memory),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

// Create a memory screen
class CreateMemoryScreen extends StatefulWidget {
  const CreateMemoryScreen({super.key});

  @override
  State<CreateMemoryScreen> createState() =>
      _CreateMemoryScreenState();
}

class _CreateMemoryScreenState extends State<CreateMemoryScreen> {
  final _titleController = TextEditingController();
  final _memoryController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _memoryController.dispose();
    super.dispose();
  }

  Future<void> _saveMemory() async {
    final title = _titleController.text.trim();
    final description = _memoryController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title and memory.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await MemoryStorage.saveMemory(
        Memory(
          title: title,
          description: description,
          createdAt: DateTime.now(),
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory saved on this device!')),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your memory. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a memory'),
        backgroundColor: MyDaysApp.deepIndigo,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                size: 48,
                color: MyDaysApp.coral,
              ),
              const SizedBox(height: 24),
              const Text(
                'Capture this moment.',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Give your memory a name and describe '
                'the moment you want to keep.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFFC9C2E0),
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _titleController,
                maxLength: 80,
                decoration: InputDecoration(
                  hintText: 'Give this memory a title',
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  filled: true,
                  fillColor: const Color(0xFF3B2D70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _memoryController,
                maxLines: 6,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'What happened today?',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: const Color(0xFF3B2D70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveMemory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyDaysApp.coral,
                    foregroundColor: MyDaysApp.deepIndigo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Save my memory',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

// Read a saved memory
class MemoryDetailsScreen extends StatelessWidget {
  const MemoryDetailsScreen({
    super.key,
    required this.memory,
  });

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory details'),
        backgroundColor: MyDaysApp.deepIndigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: MyDaysApp.coral,
              size: 42,
            ),
            const SizedBox(height: 24),
            Text(
              memory.title,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Saved on ${memory.createdAt.toLocal().toString().substring(0, 16)}',
              style: const TextStyle(
                color: Color(0xFFC9C2E0),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              memory.description,
              style: const TextStyle(
                fontSize: 17,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
