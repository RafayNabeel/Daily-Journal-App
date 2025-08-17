import 'package:dailyjournal/screens/newJournalEntryScreen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyjournal/providers/journalProvider.dart';
import 'package:dailyjournal/models/journalEntryModel.dart';
import 'package:dailyjournal/screens/newJournalEntryScreen.dart';

class EntriesListScreen extends StatefulWidget {
  const EntriesListScreen({super.key});

  @override
  State<EntriesListScreen> createState() => _EntriesListScreenState();
}

class _EntriesListScreenState extends State<EntriesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Entries'),
        actions: [
          IconButton(
            onPressed: _showFilterSheet,
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: () {
              Provider.of<JournalProvider>(context, listen: false).refreshEntries();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search entries...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          Provider.of<JournalProvider>(context, listen: false)
                              .searchEntries('');
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                Provider.of<JournalProvider>(context, listen: false)
                    .searchEntries(value);
                setState(() {});
              },
            ),
          ),

          // Active filters display
          Consumer<JournalProvider>(
            builder: (context, journalProvider, child) {
              final hasFilters = journalProvider.searchQuery.isNotEmpty ||
                  journalProvider.selectedTags.isNotEmpty ||
                  journalProvider.selectedMood != null;

              if (!hasFilters) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Active Filters:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            journalProvider.clearFilters();
                            _searchController.clear();
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (journalProvider.selectedMood != null)
                          Chip(
                            label: Text('Mood: ${_getMoodName(journalProvider.selectedMood!)}'),
                            onDeleted: () => journalProvider.filterByMood(null),
                            deleteIcon: const Icon(Icons.close, size: 18),
                          ),
                        ...journalProvider.selectedTags.map((tag) => Chip(
                              label: Text('Tag: $tag'),
                              onDeleted: () {
                                final newTags = List<String>.from(journalProvider.selectedTags)
                                  ..remove(tag);
                                journalProvider.filterByTags(newTags);
                              },
                              deleteIcon: const Icon(Icons.close, size: 18),
                            )),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // Entries list
          Expanded(
            child: Consumer<JournalProvider>(
              builder: (context, journalProvider, child) {
                if (journalProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (journalProvider.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${journalProvider.errorMessage}',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => journalProvider.refreshEntries(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final entries = journalProvider.entries;

                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          journalProvider.searchQuery.isNotEmpty ||
                                  journalProvider.selectedTags.isNotEmpty ||
                                  journalProvider.selectedMood != null
                              ? 'No entries match your filters'
                              : 'No journal entries yet',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          journalProvider.searchQuery.isNotEmpty ||
                                  journalProvider.selectedTags.isNotEmpty ||
                                  journalProvider.selectedMood != null
                              ? 'Try adjusting your search or filters'
                              : 'Create your first entry to get started!',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NewEntryScreen(),
                              ),
                            );
                            if (result == true) {
                              journalProvider.refreshEntries();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Entry'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return EntryCard(
                      entry: entry,
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NewEntryScreen(existingEntry: entry),
                          ),
                        );
                        if (result == true) {
                          journalProvider.refreshEntries();
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NewEntryScreen(),
            ),
          );
          if (result == true) {
            Provider.of<JournalProvider>(context, listen: false).refreshEntries();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getMoodName(MoodType mood) {
    switch (mood) {
      case MoodType.veryHappy:
        return 'Very Happy';
      case MoodType.happy:
        return 'Happy';
      case MoodType.neutral:
        return 'Neutral';
      case MoodType.sad:
        return 'Sad';
      case MoodType.verySad:
        return 'Very Sad';
    }
  }
}

class EntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;

  const EntryCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title, mood, and favorite
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.moodEmoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  if (entry.isFavorite) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.favorite, color: Colors.red, size: 16),
                  ],
                ],
              ),

              const SizedBox(height: 8),

              // Content preview
              Text(
                entry.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Tags
              if (entry.tags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entry.tags.take(3).map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // Footer with date and actions
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const Spacer(),
                  Consumer<JournalProvider>(
                    builder: (context, journalProvider, child) {
                      return IconButton(
                        onPressed: () async {
                          await journalProvider.toggleFavorite(entry.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(entry.isFavorite 
                                  ? 'Removed from favorites' 
                                  : 'Added to favorites'),
                            ),
                          );
                        },
                        icon: Icon(
                          entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: entry.isFavorite ? Colors.red : Colors.grey,
                          size: 20,
                        ),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Filter Entries',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Mood filter
          Consumer<JournalProvider>(
            builder: (context, journalProvider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter by Mood',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All Moods'),
                        selected: journalProvider.selectedMood == null,
                        onSelected: (selected) {
                          if (selected) {
                            journalProvider.filterByMood(null);
                          }
                        },
                      ),
                      ...MoodType.values.map((mood) => FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_getMoodEmoji(mood)),
                            const SizedBox(width: 4),
                            Text(_getMoodName(mood)),
                          ],
                        ),
                        selected: journalProvider.selectedMood == mood,
                        onSelected: (selected) {
                          journalProvider.filterByMood(selected ? mood : null);
                        },
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tags filter
                  const Text(
                    'Filter by Tags',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (journalProvider.allTags.isEmpty)
                    const Text(
                      'No tags available',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: journalProvider.allTags.map((tag) => FilterChip(
                        label: Text(tag),
                        selected: journalProvider.selectedTags.contains(tag),
                        onSelected: (selected) {
                          final newTags = List<String>.from(journalProvider.selectedTags);
                          if (selected) {
                            newTags.add(tag);
                          } else {
                            newTags.remove(tag);
                          }
                          journalProvider.filterByTags(newTags);
                        },
                      )).toList(),
                    ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            journalProvider.clearFilters();
                            Navigator.pop(context);
                          },
                          child: const Text('Clear Filters'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _getMoodEmoji(MoodType mood) {
    switch (mood) {
      case MoodType.veryHappy:
        return '😄';
      case MoodType.happy:
        return '😊';
      case MoodType.neutral:
        return '😐';
      case MoodType.sad:
        return '😢';
      case MoodType.verySad:
        return '😭';
    }
  }

  String _getMoodName(MoodType mood) {
    switch (mood) {
      case MoodType.veryHappy:
        return 'Very Happy';
      case MoodType.happy:
        return 'Happy';
      case MoodType.neutral:
        return 'Neutral';
      case MoodType.sad:
        return 'Sad';
      case MoodType.verySad:
        return 'Very Sad';
    }
  }}