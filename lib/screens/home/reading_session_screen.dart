import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReadingSessionScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final int totalPages;

  const ReadingSessionScreen({
    Key? key,
    required this.bookId,
    required this.bookTitle,
    required this.totalPages,
  }) : super(key: key);

  @override
  State<ReadingSessionScreen> createState() => _ReadingSessionScreenState();
}

class _ReadingSessionScreenState extends State<ReadingSessionScreen> {
  late Stopwatch _stopwatch;
  late Stream<DocumentSnapshot> _bookStream;
  late TextEditingController _pageController;
  int _currentPage = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _pageController = TextEditingController();
    
    final currentUser = FirebaseAuth.instance.currentUser!;
    _bookStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('books')
        .doc(widget.bookId)
        .snapshots();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _pageController.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      if (_isRunning) {
        _stopwatch.stop();
      } else {
        _stopwatch.start();
      }
      _isRunning = !_isRunning;
    });
  }

  Future<void> _saveProgress() async {
    if (_pageController.text.isEmpty) return;

    final newPage = int.tryParse(_pageController.text) ?? 0;
    if (newPage < 0 || newPage > widget.totalPages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid page number')),
      );
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final readingTimeMinutes = _stopwatch.elapsed.inMinutes;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('books')
          .doc(widget.bookId)
          .update({
        'currentPage': newPage,
        'lastReadDate': DateTime.now(),
        'totalReadingTime': FieldValue.increment(readingTimeMinutes),
      });

      _stopwatch.reset();
      _pageController.clear();
      _isRunning = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _bookStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final bookData = snapshot.data?.data() as Map<String, dynamic>?;
          _currentPage = bookData?['currentPage'] ?? 0;
          final readingSpeed = (bookData?['readingSpeed'] ?? 0.25) as num;

          final pagesRemaining = widget.totalPages - _currentPage;
          final minutesRemaining = (pagesRemaining / readingSpeed).toInt();
          final completionDate = DateTime.now().add(
            Duration(minutes: minutesRemaining),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Reading Session',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _formatDuration(_stopwatch.elapsed),
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _toggleTimer,
                          icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                          label: Text(_isRunning ? 'Pause' : 'Start Reading'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _currentPage / widget.totalPages,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_currentPage / ${widget.totalPages} pages',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter current page number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.bookmark_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _saveProgress,
                  icon: const Icon(Icons.check),
                  label: const Text('Save Progress'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Completion Forecast',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Est. Finish',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(completionDate),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Time Remaining',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$minutesRemaining min',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
