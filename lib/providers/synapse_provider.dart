import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/thought.dart';
import '../models/thought_group.dart';
import '../services/database_service.dart';
import '../services/group_service.dart';
import '../services/llm_service.dart';
import '../services/dead_link_service.dart';
import '../utils/constants.dart';

enum AppThemeMode { system, light, dark }
enum AppVisualStyle { materialYou, materialGlass }

class BundleSuggestion {
  final String suggestedName;
  final List<String> thoughtIds;
  final String reason;
  bool isDismissed;

  BundleSuggestion({
    required this.suggestedName,
    required this.thoughtIds,
    required this.reason,
    this.isDismissed = false,
  });
}

class SynapseProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final LlmService _llm = LlmService();
  final DeadLinkService _deadLinkService = DeadLinkService();
  late final GroupService _groupService;

  List<Thought> _items = [];
  List<Thought> _filteredItems = [];
  ThoughtCategory? _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isClassifyingAll = false;
  int _classifyProgress = 0;
  int _classifyTotal = 0;
  AppThemeMode _themeMode = AppThemeMode.system;
  AppVisualStyle _visualStyle = AppVisualStyle.materialYou;

  // Groups
  List<ThoughtGroup> _groups = [];
  ThoughtGroup? _selectedGroup;

  // Auto-bundle suggestions
  final List<BundleSuggestion> _bundleSuggestions = [];

  // Dead link state
  int _deadLinkCount = 0;
  bool _isCheckingDeadLinks = false;

  SynapseProvider() {
    _groupService = GroupService(() => _db.database);
  }

  List<Thought> get items =>
      _filteredItems.isEmpty &&
              _searchQuery.isEmpty &&
              _selectedCategory == null &&
              _selectedGroup == null
          ? _items
          : _filteredItems;
  ThoughtCategory? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isClassifyingAll => _isClassifyingAll;
  int get classifyProgress => _classifyProgress;
  int get classifyTotal => _classifyTotal;
  AppThemeMode get themeMode => _themeMode;
  AppVisualStyle get visualStyle => _visualStyle;
  bool get isGlass => _visualStyle == AppVisualStyle.materialGlass;
  List<ThoughtGroup> get groups => _groups;
  ThoughtGroup? get selectedGroup => _selectedGroup;
  List<BundleSuggestion> get bundleSuggestions =>
      _bundleSuggestions.where((s) => !s.isDismissed).toList();
  int get deadLinkCount => _deadLinkCount;
  bool get isCheckingDeadLinks => _isCheckingDeadLinks;

  int get unclassifiedCount => _items.where((i) => !i.isClassified).length;
  String? get lastLlmError => _llm.lastError;

  Future<void> init() async {
    await _loadThemeMode();
    await loadThoughts();
    await loadGroups();
    _purgeExpiredThoughts();
    _checkDeadLinksIfNeeded();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(AppConstants.themePref);
    switch (mode) {
      case 'light':
        _themeMode = AppThemeMode.light;
      case 'dark':
        _themeMode = AppThemeMode.dark;
      default:
        _themeMode = AppThemeMode.system;
    }

    final style = prefs.getString(AppConstants.visualStylePref);
    _visualStyle = style == 'materialGlass'
        ? AppVisualStyle.materialGlass
        : AppVisualStyle.materialYou;
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.themePref, mode.name);
    notifyListeners();
  }

  Future<void> setVisualStyle(AppVisualStyle style) async {
    _visualStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.visualStylePref, style.name);
    notifyListeners();
  }

  // ── Thoughts CRUD ──

  Future<void> loadThoughts() async {
    _isLoading = true;
    notifyListeners();
    _items = await _db.getAllThoughts();
    _applyFilters();
    _isLoading = false;
    notifyListeners();
  }

  void filterByCategory(ThoughtCategory? category) {
    _selectedCategory = category;
    _selectedGroup = null;
    _applyFilters();
    notifyListeners();
  }

  void filterByGroup(ThoughtGroup? group) async {
    _selectedGroup = group;
    _selectedCategory = null;
    if (group != null) {
      final ids = await _groupService.getThoughtIdsForGroup(group.id);
      _filteredItems = _items.where((t) => ids.contains(t.id)).toList();
    } else {
      _applyFilters();
    }
    notifyListeners();
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    if (query.isEmpty) {
      _applyFilters();
    } else {
      _filteredItems = await _db.searchThoughts(query);
      if (_selectedCategory != null) {
        _filteredItems = _filteredItems
            .where((t) => t.category == _selectedCategory)
            .toList();
      }
    }
    notifyListeners();
  }

  void _applyFilters() {
    if (_selectedCategory == null &&
        _searchQuery.isEmpty &&
        _selectedGroup == null) {
      _filteredItems = [];
    } else if (_selectedCategory != null) {
      _filteredItems =
          _items.where((t) => t.category == _selectedCategory).toList();
    }
  }

  Future<void> addThought(Thought thought) async {
    if (_items.any((t) => t.id == thought.id)) {
      final idx = _items.indexWhere((t) => t.id == thought.id);
      if (idx >= 0) _items[idx] = thought;
    } else {
      _items.insert(0, thought);
    }
    _applyFilters();
    notifyListeners();
    _checkAutoBundle();
  }

  Future<void> deleteThought(String id) async {
    await _db.deleteThought(id);
    _items.removeWhere((t) => t.id == id);
    _filteredItems.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> updateThought(Thought thought) async {
    await _db.updateThought(thought);
    final idx = _items.indexWhere((i) => i.id == thought.id);
    if (idx != -1) _items[idx] = thought;
    final fIdx = _filteredItems.indexWhere((i) => i.id == thought.id);
    if (fIdx != -1) _filteredItems[fIdx] = thought;
    notifyListeners();
  }

  Future<void> deleteMultipleThoughts(Set<String> ids) async {
    for (final id in ids) {
      await _db.deleteThought(id);
    }
    _items.removeWhere((t) => ids.contains(t.id));
    _filteredItems.removeWhere((t) => ids.contains(t.id));
    notifyListeners();
  }

  // ── Classification ──

  Thought _applyResult(Thought thought, Map<String, dynamic> result) {
    final category =
        categoryFromString(result['category'] as String? ?? 'other');
    final llmTags = (result['tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final mergedTags = <String>{...thought.tags, ...llmTags}.toList();
    final markdown = result['markdown'] as String?;
    final title = result['title'] as String?;
    final sourceUrl = result['source_url'] as String?;

    return thought.copyWith(
      category: category,
      tags: mergedTags,
      llmSummary: markdown,
      title: (title != null && title.isNotEmpty) ? title : thought.title,
      url: (sourceUrl != null && sourceUrl.isNotEmpty)
          ? sourceUrl
          : thought.url,
      isClassified: true,
      updatedAt: DateTime.now(),
    );
  }

  Future<bool> classifyThought(Thought thought) async {
    if (thought.type == ThoughtType.screenshot) {
      final result = await _llm.extractScreenshotInfo(thought);
      if (result == null) return false;
      await updateThought(_applyResult(thought, result));
      return true;
    }
    // Single link — use batch of 1
    final results = await _llm.classifyBatch([thought]);
    if (results == null || results.isEmpty) return false;
    await updateThought(_applyResult(thought, results.first));
    return true;
  }

  void cancelClassification() {
    _isClassifyingAll = false;
    notifyListeners();
  }

  Future<int> classifyAllThoughts() async {
    final unclassified = _items.where((i) => !i.isClassified).toList();
    if (unclassified.isEmpty) return 0;
    _isClassifyingAll = true;
    _classifyProgress = 0;
    _classifyTotal = unclassified.length;
    _lastClassifyError = null;
    notifyListeners();

    int successCount = 0;
    int consecutiveFailures = 0;

    // Separate links and screenshots
    final links = unclassified.where((t) => t.type == ThoughtType.link).toList();
    final screenshots = unclassified.where((t) => t.type == ThoughtType.screenshot).toList();

    // Process links in batches of 8
    for (int i = 0; i < links.length; i += LlmService.batchSize) {
      if (!_isClassifyingAll) break;

      final batch = links.sublist(i, (i + LlmService.batchSize).clamp(0, links.length));
      final results = await _llm.classifyBatch(batch);

      if (results != null && results.isNotEmpty) {
        final count = results.length.clamp(0, batch.length);
        for (int j = 0; j < count; j++) {
          await updateThought(_applyResult(batch[j], results[j]));
          successCount++;
          _classifyProgress++;
          notifyListeners();
        }
        // Mark any unmatched items in the batch as progressed
        _classifyProgress += (batch.length - count);
        notifyListeners();
        consecutiveFailures = 0;
      } else {
        consecutiveFailures++;
        _classifyProgress += batch.length;
        notifyListeners();
        if (consecutiveFailures >= 3) {
          _lastClassifyError = _llm.lastError ?? 'Multiple failures, stopping.';
          break;
        }
      }

      if (_isClassifyingAll && i + LlmService.batchSize < links.length) {
        await Future.delayed(const Duration(seconds: 4));
      }
    }

    // Process screenshots one at a time (each needs image upload)
    for (final thought in screenshots) {
      if (!_isClassifyingAll) break;

      final result = await _llm.extractScreenshotInfo(thought);
      if (result != null) {
        await updateThought(_applyResult(thought, result));
        successCount++;
        consecutiveFailures = 0;
      } else {
        consecutiveFailures++;
        if (consecutiveFailures >= 3) {
          _lastClassifyError = _llm.lastError ?? 'Multiple failures, stopping.';
          break;
        }
      }
      _classifyProgress++;
      notifyListeners();

      if (_isClassifyingAll && thought != screenshots.last) {
        await Future.delayed(const Duration(seconds: 4));
      }
    }

    _isClassifyingAll = false;
    notifyListeners();
    return successCount;
  }

  String? _lastClassifyError;
  String? get lastClassifyError => _lastClassifyError;

  // ── Manual Tagging ──

  Future<void> addTagToThought(String thoughtId, String tag) async {
    final idx = _items.indexWhere((t) => t.id == thoughtId);
    if (idx == -1) return;
    final thought = _items[idx];
    if (thought.tags.contains(tag)) return;
    final updated = thought.copyWith(
      tags: [...thought.tags, tag],
      updatedAt: DateTime.now(),
    );
    await updateThought(updated);
  }

  Future<void> removeTagFromThought(String thoughtId, String tag) async {
    final idx = _items.indexWhere((t) => t.id == thoughtId);
    if (idx == -1) return;
    final thought = _items[idx];
    final updated = thought.copyWith(
      tags: thought.tags.where((t) => t != tag).toList(),
      updatedAt: DateTime.now(),
    );
    await updateThought(updated);
  }

  Future<void> setCategoryForThought(String thoughtId, ThoughtCategory category) async {
    final idx = _items.indexWhere((t) => t.id == thoughtId);
    if (idx == -1) return;
    final thought = _items[idx];
    final updated = thought.copyWith(
      category: category,
      updatedAt: DateTime.now(),
    );
    await updateThought(updated);
  }

  // ── Q&A ──

  Future<String?> askQuestion(String question) async {
    return await _llm.askQuestion(question, _items);
  }

  Future<int> getRemainingFreeCalls() async {
    return await _llm.getRemainingFreeCalls();
  }

  Future<bool> hasApiKey() async {
    return await _llm.hasApiKey();
  }

  Map<ThoughtCategory, int> getCategoryCounts() {
    final counts = <ThoughtCategory, int>{};
    for (final t in _items) {
      counts[t.category] = (counts[t.category] ?? 0) + 1;
    }
    return counts;
  }

  // ── Groups ──

  Future<void> loadGroups() async {
    _groups = await _groupService.getAllGroups();
    notifyListeners();
  }

  Future<ThoughtGroup> createGroup(String name,
      {String? description, int color = 0xFF6C5CE7}) async {
    final now = DateTime.now();
    final group = ThoughtGroup(
      id: const Uuid().v4(),
      name: name,
      description: description,
      color: color,
      createdAt: now,
      updatedAt: now,
    );
    await _groupService.createGroup(group);
    await loadGroups();
    return group;
  }

  Future<void> updateGroup(ThoughtGroup group) async {
    await _groupService.updateGroup(group);
    await loadGroups();
  }

  Future<void> deleteGroup(String id) async {
    await _groupService.deleteGroup(id);
    if (_selectedGroup?.id == id) _selectedGroup = null;
    await loadGroups();
  }

  Future<void> addThoughtsToGroup(String groupId, List<String> thoughtIds) async {
    for (final id in thoughtIds) {
      await _groupService.addThoughtToGroup(groupId, id);
    }
    notifyListeners();
  }

  Future<void> removeThoughtFromGroup(String groupId, String thoughtId) async {
    await _groupService.removeThoughtFromGroup(groupId, thoughtId);
    if (_selectedGroup?.id == groupId) {
      filterByGroup(_selectedGroup);
    }
  }

  Future<List<ThoughtGroup>> getGroupsForThought(String thoughtId) async {
    return await _groupService.getGroupsForThought(thoughtId);
  }

  // ── Auto-Bundle ──

  void _checkAutoBundle() {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final recentThoughts =
        _items.where((t) => t.createdAt.isAfter(oneHourAgo)).toList();
    if (recentThoughts.length < 3) return;

    // Check for domain clustering
    final domainCounts = <String, List<String>>{};
    for (final t in recentThoughts) {
      if (t.url != null) {
        try {
          final host =
              Uri.parse(t.url!).host.replaceFirst('www.', '');
          domainCounts.putIfAbsent(host, () => []).add(t.id);
        } catch (_) {}
      }
    }
    for (final entry in domainCounts.entries) {
      if (entry.value.length >= 3) {
        final name =
            '${entry.key.split('.').first[0].toUpperCase()}${entry.key.split('.').first.substring(1)} Research';
        if (!_bundleSuggestions.any((s) => s.suggestedName == name)) {
          _bundleSuggestions.add(BundleSuggestion(
            suggestedName: name,
            thoughtIds: entry.value,
            reason:
                '${entry.value.length} thoughts from ${entry.key} in the last hour',
          ));
          notifyListeners();
        }
      }
    }

    // Check for tag clustering
    final tagCounts = <String, List<String>>{};
    for (final t in recentThoughts) {
      for (final tag in t.tags) {
        tagCounts.putIfAbsent(tag.toLowerCase(), () => []).add(t.id);
      }
    }
    for (final entry in tagCounts.entries) {
      if (entry.value.length >= 3) {
        final name =
            '${entry.key[0].toUpperCase()}${entry.key.substring(1)} Research';
        if (!_bundleSuggestions.any((s) => s.suggestedName == name)) {
          _bundleSuggestions.add(BundleSuggestion(
            suggestedName: name,
            thoughtIds: entry.value.toSet().toList(),
            reason: '${entry.value.length} thoughts tagged "${entry.key}"',
          ));
          notifyListeners();
        }
      }
    }
  }

  Future<void> acceptBundleSuggestion(BundleSuggestion suggestion) async {
    final group = await createGroup(suggestion.suggestedName);
    await addThoughtsToGroup(group.id, suggestion.thoughtIds);
    suggestion.isDismissed = true;
    notifyListeners();
  }

  void dismissBundleSuggestion(BundleSuggestion suggestion) {
    suggestion.isDismissed = true;
    notifyListeners();
  }

  // ── Dead Link Checker ──

  Future<void> _checkDeadLinksIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString(AppConstants.lastDeadLinkCheckPref);
    final now = DateTime.now();
    if (lastCheck != null) {
      final last = DateTime.tryParse(lastCheck);
      if (last != null && now.difference(last).inDays < 7) return;
    }
    _runDeadLinkCheck();
  }

  Future<void> _runDeadLinkCheck() async {
    _isCheckingDeadLinks = true;
    notifyListeners();

    final linkThoughts = _items
        .where((t) =>
            t.type == ThoughtType.link &&
            t.url != null &&
            !t.isLinkDead)
        .toList();
    if (linkThoughts.isEmpty) {
      _isCheckingDeadLinks = false;
      notifyListeners();
      return;
    }

    final results = await _deadLinkService.checkLinks(linkThoughts);
    int deadCount = 0;
    for (final result in results) {
      if (result.isDead) {
        deadCount++;
        final idx = _items.indexWhere((t) => t.id == result.thoughtId);
        if (idx != -1) {
          final updated = _items[idx].copyWith(isLinkDead: true);
          await _db.updateThought(updated);
          _items[idx] = updated;
        }
      }
    }

    _deadLinkCount = deadCount;
    _isCheckingDeadLinks = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.lastDeadLinkCheckPref,
        DateTime.now().toIso8601String());

    notifyListeners();
  }

  Future<void> forceDeadLinkCheck() async {
    await _runDeadLinkCheck();
  }

  Future<void> cacheDeadLink(Thought thought) async {
    if (thought.url == null) return;
    final cachedText = await _deadLinkService.cachePageText(thought.url!);
    if (cachedText != null) {
      final updated = thought.copyWith(cachedText: cachedText);
      await updateThought(updated);
    }
  }

  // ── Auto-Delete ──

  Future<void> _purgeExpiredThoughts() async {
    final prefs = await SharedPreferences.getInstance();
    final globalDays = prefs.getInt(AppConstants.autoDeleteDaysPref);
    if (globalDays == null || globalDays <= 0) return;

    final now = DateTime.now();
    final toDelete = <String>[];

    for (final thought in _items) {
      final groups = await _groupService.getGroupsForThought(thought.id);
      int? effectiveDays;

      if (groups.isNotEmpty) {
        // Use group's policy if set, otherwise global
        for (final group in groups) {
          final gDays = group.autoDeleteDays;
          if (gDays != null && gDays > 0) {
            effectiveDays = effectiveDays == null
                ? gDays
                : (gDays > effectiveDays ? gDays : effectiveDays);
          }
        }
        effectiveDays ??= globalDays;
      } else {
        effectiveDays = globalDays;
      }

      if (now.difference(thought.createdAt).inDays >= effectiveDays) {
        toDelete.add(thought.id);
      }
    }

    if (toDelete.isNotEmpty) {
      await deleteMultipleThoughts(toDelete.toSet());
    }
  }
}
