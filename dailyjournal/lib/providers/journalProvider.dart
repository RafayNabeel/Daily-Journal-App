import 'package:dailyjournal/models/journalEntryModel.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
// Import your journal model here
// import 'path/to/journal_model.dart';

class JournalProvider extends ChangeNotifier {
  List<JournalEntry> _entries = [];
  List<JournalEntry> _filteredEntries = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  List<String> _selectedTags = [];
  MoodType? _selectedMood;

  // Getters
  List<JournalEntry> get entries => _filteredEntries;
  List<JournalEntry> get allEntries => _entries;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  List<String> get selectedTags => _selectedTags;
  MoodType? get selectedMood => _selectedMood;
  
  // Get favorite entries
  List<JournalEntry> get favoriteEntries => _entries.where((entry) => entry.isFavorite).toList();
  
  // Get all unique tags
  List<String> get allTags {
    final Set<String> tagSet = {};
    for (final entry in _entries) {
      tagSet.addAll(entry.tags);
    }
    return tagSet.toList()..sort();
  }

  // Get entries count by mood
  Map<MoodType, int> get moodCounts {
    final Map<MoodType, int> counts = {};
    for (final mood in MoodType.values) {
      counts[mood] = _entries.where((entry) => entry.mood == mood).length;
    }
    return counts;
  }

  JournalProvider() {
    _loadEntries();
  }

  // Load entries from storage
  Future<void> _loadEntries() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = prefs.getStringList('journal_entries') ?? [];
      
      _entries = entriesJson
          .map((json) => JournalEntry.fromJson(jsonDecode(json)))
          .toList();
      
      // Sort by creation date (newest first)
      _entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _applyFilters();
    } catch (e) {
      _setError('Failed to load entries: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Save entries to storage
  Future<void> _saveEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = _entries
          .map((entry) => jsonEncode(entry.toJson()))
          .toList();
      
      await prefs.setStringList('journal_entries', entriesJson);
    } catch (e) {
      _setError('Failed to save entries');
    }
  }

  // Add new entry
  Future<bool> addEntry({
    required String userId,
    required String title,
    required String content,
    required MoodType mood,
    List<String> tags = const [],
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final newEntry = JournalEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: title,
        content: content,
        mood: mood,
        tags: tags,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _entries.insert(0, newEntry); // Add to beginning of list
      await _saveEntries();
      _applyFilters();
      
      return true;
    } catch (e) {
      _setError('Failed to add entry');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update existing entry
  Future<bool> updateEntry(String entryId, {
    String? title,
    String? content,
    MoodType? mood,
    List<String>? tags,
    bool? isFavorite,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final entryIndex = _entries.indexWhere((entry) => entry.id == entryId);
      if (entryIndex == -1) {
        throw Exception('Entry not found');
      }

      final updatedEntry = _entries[entryIndex].copyWith(
        title: title,
        content: content,
        mood: mood,
        tags: tags,
        isFavorite: isFavorite,
        updatedAt: DateTime.now(),
      );

      _entries[entryIndex] = updatedEntry;
      await _saveEntries();
      _applyFilters();
      
      return true;
    } catch (e) {
      _setError('Failed to update entry');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete entry
  Future<bool> deleteEntry(String entryId) async {
    _setLoading(true);
    _clearError();

    try {
      _entries.removeWhere((entry) => entry.id == entryId);
      await _saveEntries();
      _applyFilters();
      
      return true;
    } catch (e) {
      _setError('Failed to delete entry');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Toggle favorite status
  Future<bool> toggleFavorite(String entryId) async {
    final entry = _entries.firstWhere(
      (entry) => entry.id == entryId,
      orElse: () => throw Exception('Entry not found'),
    );

    return await updateEntry(entryId, isFavorite: !entry.isFavorite);
  }

  // Get entry by ID
  JournalEntry? getEntryById(String entryId) {
    try {
      return _entries.firstWhere((entry) => entry.id == entryId);
    } catch (e) {
      return null;
    }
  }

  // Get entries by date range
  List<JournalEntry> getEntriesByDateRange(DateTime startDate, DateTime endDate) {
    return _entries.where((entry) {
      final entryDate = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      
      return entryDate.isAtSameMomentAs(start) ||
             entryDate.isAtSameMomentAs(end) ||
             (entryDate.isAfter(start) && entryDate.isBefore(end));
    }).toList();
  }

  // Search entries
  void searchEntries(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  // Filter by tags
  void filterByTags(List<String> tags) {
    _selectedTags = tags;
    _applyFilters();
  }

  // Filter by mood
  void filterByMood(MoodType? mood) {
    _selectedMood = mood;
    _applyFilters();
  }

  // Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedTags = [];
    _selectedMood = null;
    _applyFilters();
  }

  // Apply current filters
  void _applyFilters() {
    _filteredEntries = _entries.where((entry) {
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final matchesTitle = entry.title.toLowerCase().contains(searchLower);
        final matchesContent = entry.content.toLowerCase().contains(searchLower);
        final matchesTags = entry.tags.any((tag) => tag.toLowerCase().contains(searchLower));
        
        if (!matchesTitle && !matchesContent && !matchesTags) {
          return false;
        }
      }

      // Tags filter
      if (_selectedTags.isNotEmpty) {
        final hasSelectedTags = _selectedTags.every((tag) => entry.tags.contains(tag));
        if (!hasSelectedTags) {
          return false;
        }
      }

      // Mood filter
      if (_selectedMood != null && entry.mood != _selectedMood) {
        return false;
      }

      return true;
    }).toList();

    notifyListeners();
  }

  // Get entries for today
  List<JournalEntry> getTodaysEntries() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return _entries.where((entry) =>
        entry.createdAt.isAfter(todayStart) && entry.createdAt.isBefore(todayEnd)
    ).toList();
  }

  // Get streak count (consecutive days with entries)
  int getStreakCount() {
    if (_entries.isEmpty) return 0;

    final sortedEntries = List<JournalEntry>.from(_entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final Set<String> entryDates = sortedEntries
        .map((entry) => '${entry.createdAt.year}-${entry.createdAt.month}-${entry.createdAt.day}')
        .toSet();

    int streak = 0;
    final today = DateTime.now();
    
    for (int i = 0; i < 365; i++) { // Check up to 365 days
      final checkDate = today.subtract(Duration(days: i));
      final dateKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
      
      if (entryDates.contains(dateKey)) {
        streak++;
      } else {
        break;
      }
    }
    
    return streak;
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Refresh entries
  Future<void> refreshEntries() async {
    await _loadEntries();
  }
}