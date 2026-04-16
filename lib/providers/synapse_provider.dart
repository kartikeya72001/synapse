import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/thought.dart';
import '../models/thought_group.dart';
import '../models/chat_message.dart';
import '../models/chat_conversation.dart';
import '../services/database_service.dart';
import '../services/group_service.dart';
import '../services/llm_service.dart';
import '../services/classification_service.dart';
import '../services/dead_link_service.dart';
import '../services/vector_search_service.dart';
import '../services/local_llm_service.dart';
import '../utils/constants.dart';
import '../utils/url_utils.dart' as url_utils;
import '../services/debug_logger.dart';

enum AppThemeMode { system, light, dark }

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
  final VectorSearchService _vectorSearch = VectorSearchService();
  final LocalLlmService _localLlm = LocalLlmService();
  final _dbg = DebugLogger.instance;
  late final GroupService _groupService;
  late final ClassificationService _classification;

  void setWiringChecker(bool Function(String) checker) {
    _classification.isWiringInProgress = checker;
  }

  void setCarouselFetcher(Future<List<Uint8List>> Function(String) fetcher) {
    _classification.fetchCarouselImages = fetcher;
  }

  bool _isIndexing = false;
  bool get isIndexing => _isIndexing;

  List<Thought> _items = [];
  List<Thought> _filteredItems = [];
  ThoughtCategory? _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isClassifyingAll = false;
  int _classifyProgress = 0;
  int _classifyTotal = 0;
  AppThemeMode _themeMode = AppThemeMode.system;

  // Groups
  List<ThoughtGroup> _groups = [];
  ThoughtGroup? _selectedGroup;

  // Auto-bundle suggestions
  final List<BundleSuggestion> _bundleSuggestions = [];

  // Tracks thoughts currently being wired (to prevent concurrent classification)
  final Set<String> _wiringInProgress = {};

  // Dead link state
  int _deadLinkCount = 0;
  bool _isCheckingDeadLinks = false;
  bool _filterDeadLinks = false;
  bool get filterDeadLinks => _filterDeadLinks;

  // Chat state
  List<ChatMessage> _chatMessages = [];
  bool _isChatLoading = false;
  List<ChatConversation> _conversations = [];
  String? _currentConversationId;

  // Tab / navigation state
  Thought? _pendingSharedThought;
  Thought? get pendingSharedThought => _pendingSharedThought;
  void consumePendingSharedThought() {
    _pendingSharedThought = null;
  }

  LocalLlmService get localLlm => _localLlm;

  SynapseProvider() {
    _groupService = GroupService(() => _db.database);
    _classification = ClassificationService(_llm);
    _llm.onLocalLlmQuery = (prompt, onChunk) async {
      return await _localLlm.askQuestionStreaming(prompt, onChunk);
    };
  }

  List<Thought> get items =>
      _filteredItems.isEmpty &&
              _searchQuery.isEmpty &&
              _selectedCategory == null &&
              _selectedGroup == null
          ? _items
          : _filteredItems;
  int get totalItemCount => _items.length;
  int _dataVersion = 0;
  int get dataVersion => _dataVersion;
  void _bumpDataVersion() { _dataVersion++; }
  List<Thought> get allItems => _items;
  bool get isFilterActive =>
      _selectedCategory != null || _selectedGroup != null ||
      _searchQuery.isNotEmpty || _filterDeadLinks;
  ThoughtCategory? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isClassifyingAll => _isClassifyingAll;
  int get classifyProgress => _classifyProgress;
  int get classifyTotal => _classifyTotal;
  AppThemeMode get themeMode => _themeMode;
  List<ThoughtGroup> get groups => _groups;
  ThoughtGroup? get selectedGroup => _selectedGroup;
  List<BundleSuggestion> get bundleSuggestions =>
      _bundleSuggestions.where((s) => !s.isDismissed).toList();
  int get deadLinkCount => _deadLinkCount;
  bool get isCheckingDeadLinks => _isCheckingDeadLinks;
  List<ChatMessage> get chatMessages => _chatMessages;
  bool get isChatLoading => _isChatLoading;
  List<ChatConversation> get conversations => _conversations;
  String? get currentConversationId => _currentConversationId;
  ChatConversation? get currentConversation =>
      _currentConversationId == null
          ? null
          : _conversations
              .cast<ChatConversation?>()
              .firstWhere((c) => c!.id == _currentConversationId, orElse: () => null);

  int get unclassifiedCount => _items.where((i) => !i.isClassified).length;
  String? get lastLlmError => _llm.lastError;

  Future<void> init() async {
    await _loadThemeMode();
    await loadThoughts();
    await loadGroups();
    await loadConversations();
    _purgeExpiredThoughts();
    _checkDeadLinksIfNeeded();
    _indexEmbeddingsInBackground();
    _retryFailedWirings();
  }

  /// Re-processes unclassified social-media thoughts.
  Future<void> retryFailedWirings() => _retryFailedWirings();

  Future<void> _retryFailedWirings() async {
    await Future.delayed(const Duration(seconds: 5));

    final unclassifiedSocial = _items.where((t) =>
        !t.isClassified &&
        t.url != null &&
        url_utils.isSocialMediaUrl(t.url!)).toList();

    if (unclassifiedSocial.isEmpty) return;

    _dbg.log('RETRY', '${unclassifiedSocial.length} unclassified '
        'social-media thoughts to re-wire');

    for (final thought in unclassifiedSocial) {
      try {
        _dbg.log('RETRY', 'wiring ${thought.id} — ${thought.displayTitle}');
        final success = await classifyThought(thought);
        _dbg.log('RETRY', '${thought.id} → ${success ? "OK" : "FAILED"}');
      } catch (e) {
        _dbg.log('RETRY', '${thought.id} error: $e');
      }
    }
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

  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.themePref, mode.name);
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

  bool _isSemanticSearching = false;
  bool get isSemanticSearching => _isSemanticSearching;

  Future<void> search(String query) async {
    _searchQuery = query;
    if (query.isEmpty) {
      _isSemanticSearching = false;
      _applyFilters();
    } else {
      // Start with fast keyword search for instant results
      _filteredItems = await _db.searchThoughts(query);
      if (_selectedCategory != null) {
        _filteredItems = _filteredItems
            .where((t) => t.category == _selectedCategory)
            .toList();
      }
      notifyListeners();

      // Then augment with semantic search results
      if (query.length >= 3) {
        _isSemanticSearching = true;
        notifyListeners();
        try {
          final scored = await _vectorSearch.search(query, _items, topK: 20);
          if (scored.isNotEmpty && _searchQuery == query) {
            final keywordIds = _filteredItems.map((t) => t.id).toSet();
            final semanticOnly = scored
                .where((s) => !keywordIds.contains(s.thought.id))
                .map((s) => s.thought)
                .toList();
            if (semanticOnly.isNotEmpty) {
              _filteredItems = [..._filteredItems, ...semanticOnly];
              if (_selectedCategory != null) {
                _filteredItems = _filteredItems
                    .where((t) => t.category == _selectedCategory)
                    .toList();
              }
            }
          }
        } catch (e) {
          _dbg.log('SEARCH', 'Semantic search error: $e');
        }
        _isSemanticSearching = false;
      }
    }
    notifyListeners();
  }

  void toggleDeadLinkFilter() {
    _filterDeadLinks = !_filterDeadLinks;
    if (_filterDeadLinks) {
      _selectedCategory = null;
      _selectedGroup = null;
      _searchQuery = '';
    }
    _applyFilters();
    notifyListeners();
  }

  Future<void> deleteAllDeadLinks() async {
    final deadIds = _items.where((t) => t.isLinkDead).map((t) => t.id).toSet();
    if (deadIds.isEmpty) return;
    await deleteMultipleThoughts(deadIds);
    _deadLinkCount = 0;
    _filterDeadLinks = false;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    if (_filterDeadLinks) {
      _filteredItems = _items.where((t) => t.isLinkDead).toList();
    } else if (_selectedCategory == null &&
        _searchQuery.isEmpty &&
        _selectedGroup == null) {
      _filteredItems = [];
    } else if (_selectedCategory != null) {
      _filteredItems =
          _items.where((t) => t.category == _selectedCategory).toList();
    }
  }

  Future<void> addThought(Thought thought, {bool fromShare = false}) async {
    final isNew = !_items.any((t) => t.id == thought.id);
    if (!isNew) {
      final idx = _items.indexWhere((t) => t.id == thought.id);
      if (idx >= 0) _items[idx] = thought;
    } else {
      _items.insert(0, thought);
    }
    _applyFilters();
    _bumpDataVersion();
    if (fromShare && isNew) {
      final prefs = await SharedPreferences.getInstance();
      final bgMode = prefs.getBool(AppConstants.backgroundSharePref) ?? false;
      if (!bgMode) {
        _pendingSharedThought = thought;
      }
    }
    notifyListeners();
    _checkAutoBundle();

    _dbg.log('RAG', 'addThought "${thought.displayTitle}" '
        'isNew=$isNew classified=${thought.isClassified} '
        'hasSummary=${thought.llmSummary != null} '
        'hasExtracted=${thought.extractedInfo != null}');
    _vectorSearch.indexThought(thought);

    if (fromShare && isNew) {
      final prefs2 = await SharedPreferences.getInstance();
      final autoWire = prefs2.getBool(AppConstants.autoWirePref) ?? true;
      if (autoWire && !thought.isClassified) {
        _dbg.log('AUTO-WIRE', 'Auto-wiring "${thought.displayTitle}"');
        classifyThought(thought);
      }
    }
  }

  /// Re-inserts a previously deleted thought back into the database and lists.
  Future<void> restoreThought(Thought thought) async {
    await _db.insertThought(thought);
    if (!_items.any((t) => t.id == thought.id)) {
      _items.insert(0, thought);
    }
    _applyFilters();
    _bumpDataVersion();
    notifyListeners();
    await _vectorSearch.indexThought(thought);
  }

  Future<void> deleteThought(String id) async {
    await _db.deleteThought(id);
    _vectorSearch.removeThought(id);
    _items.removeWhere((t) => t.id == id);
    _filteredItems.removeWhere((t) => t.id == id);
    _bumpDataVersion();
    notifyListeners();
  }

  Future<void> updateThought(Thought thought) async {
    await _db.updateThought(thought);
    final idx = _items.indexWhere((i) => i.id == thought.id);
    if (idx != -1) _items[idx] = thought;
    final fIdx = _filteredItems.indexWhere((i) => i.id == thought.id);
    if (fIdx != -1) _filteredItems[fIdx] = thought;
    _bumpDataVersion();
    notifyListeners();

    _vectorSearch.indexThought(thought);
  }

  Future<void> updateUserNotes(String thoughtId, String notes) async {
    final idx = _items.indexWhere((i) => i.id == thoughtId);
    if (idx == -1) return;
    final updated = _items[idx].copyWith(
      userNotes: notes,
      updatedAt: DateTime.now(),
    );
    await updateThought(updated);
  }

  Future<void> deleteMultipleThoughts(Set<String> ids) async {
    for (final id in ids) {
      await _db.deleteThought(id);
      _vectorSearch.removeThought(id);
    }
    _items.removeWhere((t) => ids.contains(t.id));
    _filteredItems.removeWhere((t) => ids.contains(t.id));
    _bumpDataVersion();
    notifyListeners();
  }

  // ── Classification ──

  bool isWiringThought(String id) => _wiringInProgress.contains(id);

  Future<bool> classifyThought(Thought thought) async {
    if (_wiringInProgress.contains(thought.id)) {
      _dbg.log('WIRE', 'Already wiring "${thought.displayTitle}", skipping');
      return false;
    }
    _wiringInProgress.add(thought.id);
    notifyListeners();
    try {
      final classified = await _classification.classify(thought);
      if (classified == null) {
        _wiringInProgress.remove(thought.id);
        notifyListeners();
        return false;
      }
      await updateThought(classified);
      return true;
    } catch (e) {
      _dbg.log('WIRE', 'Error wiring "${thought.displayTitle}": $e');
      return false;
    } finally {
      _wiringInProgress.remove(thought.id);
      notifyListeners();
    }
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

    for (final thought in unclassified) {
      if (!_isClassifyingAll) break;

      final classified = await _classification.classify(thought);
      if (classified != null) {
        await updateThought(classified);
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

      if (_isClassifyingAll && thought != unclassified.last) {
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

  // ── Conversations & Chat ──

  static const int _maxConversations = 64;

  Future<void> loadConversations() async {
    _conversations = await _db.getAllConversations();
    if (_conversations.isEmpty) {
      await createNewConversation(silent: true);
    } else {
      _currentConversationId = _conversations.first.id;
      _chatMessages = await _db.getConversationMessages(_currentConversationId!);
    }
    notifyListeners();
  }

  Future<void> createNewConversation({bool silent = false}) async {
    final now = DateTime.now();
    final conversation = ChatConversation(
      id: const Uuid().v4(),
      title: 'New Chat',
      createdAt: now,
      updatedAt: now,
    );
    await _db.insertConversation(conversation);
    await _db.purgeOldestUnsavedConversations(_maxConversations);
    _conversations = await _db.getAllConversations();
    _currentConversationId = conversation.id;
    _chatMessages = [];
    if (!silent) notifyListeners();
  }

  Future<void> switchConversation(String id) async {
    if (id == _currentConversationId) return;
    _currentConversationId = id;
    _chatMessages = await _db.getConversationMessages(id);
    notifyListeners();
  }

  Future<void> toggleSaveConversation(String id) async {
    final idx = _conversations.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final updated = _conversations[idx].copyWith(
      isSaved: !_conversations[idx].isSaved,
      updatedAt: DateTime.now(),
    );
    await _db.updateConversation(updated);
    _conversations[idx] = updated;
    notifyListeners();
  }

  Future<void> deleteConversation(String id) async {
    await _db.deleteConversation(id);
    _conversations.removeWhere((c) => c.id == id);
    if (_currentConversationId == id) {
      if (_conversations.isNotEmpty) {
        _currentConversationId = _conversations.first.id;
        _chatMessages = await _db.getConversationMessages(_currentConversationId!);
      } else {
        await createNewConversation();
      }
    }
    notifyListeners();
  }

  Future<void> renameConversation(String id, String newTitle) async {
    final idx = _conversations.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final updated = _conversations[idx].copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );
    await _db.updateConversation(updated);
    _conversations[idx] = updated;
    notifyListeners();
  }

  Future<void> addChatMessage(ChatMessage message) async {
    final msg = ChatMessage(
      id: message.id,
      text: message.text,
      role: message.role,
      timestamp: message.timestamp,
      conversationId: _currentConversationId,
      imagePath: message.imagePath,
    );
    _chatMessages.add(msg);
    await _db.insertChatMessage(msg);

    // Update conversation's updatedAt
    if (_currentConversationId != null) {
      final idx = _conversations.indexWhere((c) => c.id == _currentConversationId);
      if (idx != -1) {
        final updated = _conversations[idx].copyWith(updatedAt: DateTime.now());
        _conversations[idx] = updated;
        await _db.updateConversation(updated);
      }
    }
    notifyListeners();
  }

  Future<void> _autoTitleCurrentConversation(String firstUserMessage) async {
    if (_currentConversationId == null) return;
    final idx = _conversations.indexWhere((c) => c.id == _currentConversationId);
    if (idx == -1) return;
    if (_conversations[idx].title != 'New Chat') return;
    final title = firstUserMessage.length > 40
        ? '${firstUserMessage.substring(0, 40)}...'
        : firstUserMessage;
    final updated = _conversations[idx].copyWith(
      title: title,
      updatedAt: DateTime.now(),
    );
    await _db.updateConversation(updated);
    _conversations[idx] = updated;
  }

  Future<void> sendChatMessage(
    String text, {
    void Function(String partialText)? onStreamChunk,
  }) async {
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      text: text,
      role: ChatMessageRole.user,
    );
    await addChatMessage(userMsg);

    // Auto-title on first user message
    final userMessages = _chatMessages.where((m) => m.isUser).toList();
    if (userMessages.length == 1) {
      await _autoTitleCurrentConversation(text);
    }

    _isChatLoading = true;
    notifyListeners();

    final hasKey = await _llm.hasApiKey();
    if (!hasKey) {
      _isChatLoading = false;
      await addChatMessage(ChatMessage(
        id: const Uuid().v4(),
        text: 'The cortex needs fuel. Add your API key in Settings to unlock neural queries.',
        role: ChatMessageRole.assistant,
      ));
      return;
    }

    // Image generation intent detection
    if (_llm.isImageGenerationRequest(text)) {
      final imagePath = await _llm.generateImage(text);
      _isChatLoading = false;
      if (imagePath != null) {
        await addChatMessage(ChatMessage(
          id: const Uuid().v4(),
          text: '![Generated Image]($imagePath)',
          role: ChatMessageRole.assistant,
          imagePath: imagePath,
        ));
      } else {
        await addChatMessage(ChatMessage(
          id: const Uuid().v4(),
          text: _llm.lastError ?? "Couldn't generate that image. Try rephrasing.",
          role: ChatMessageRole.assistant,
        ));
      }
      return;
    }

    _dbg.log('RAG', 'query="${text.substring(0, text.length.clamp(0, 60))}"');
    List<Thought> contextItems;
    final scored = _items.length >= 20
        ? await _vectorSearch.hierarchicalSearch(text, _items)
        : await _vectorSearch.search(text, _items);
    if (scored.isNotEmpty) {
      contextItems = scored.map((s) => s.thought).toList();
      _dbg.log('RAG', 'sending ${contextItems.length} relevant items '
          'to LLM (out of ${_items.length} total)');
    } else {
      const fallbackCap = 20;
      contextItems = _items.take(fallbackCap).toList();
      _dbg.log('RAG', 'FALLBACK — no vector hits, sending '
          '${contextItems.length} most recent items (capped at $fallbackCap)');
    }

    String? answer;
    try {
      if (onStreamChunk != null) {
        answer = await _llm.askQuestionStreaming(
          text,
          contextItems,
          chatHistory: _chatMessages,
          onChunk: onStreamChunk,
        );
      } else {
        answer = await _llm.askQuestion(text, contextItems, chatHistory: _chatMessages);
      }
    } catch (e) {
      _dbg.log('CHAT', 'LLM error: $e');
      answer = null;
    }
    _isChatLoading = false;

    final errorDetail = _llm.lastError;
    final fallbackMsg = errorDetail != null && errorDetail.isNotEmpty
        ? errorDetail
        : "Signal lost. The cortex couldn't process that. Try rewording.";

    await addChatMessage(ChatMessage(
      id: const Uuid().v4(),
      text: answer ?? fallbackMsg,
      role: ChatMessageRole.assistant,
    ));
  }

  Future<void> clearChat() async {
    if (_currentConversationId != null) {
      await _db.clearConversationMessages(_currentConversationId!);
    }
    _chatMessages = [];
    notifyListeners();
  }

  Future<String?> askQuestion(String question) async {
    final scored = await _vectorSearch.search(question, _items);
    final context = scored.isNotEmpty
        ? scored.map((s) => s.thought).toList()
        : _items.take(20).toList();
    return await _llm.askQuestion(question, context);
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

  // ── Vector Embeddings ──

  /// Called externally (e.g. after API key is saved) to re-trigger indexing.
  Future<void> reindexEmbeddings() async {
    _dbg.log('RAG', 'reindexEmbeddings triggered');
    await _indexEmbeddingsInBackground();
  }

  /// Indexes all thoughts that don't yet have embeddings.
  /// Runs in the background after app init.
  Future<void> _indexEmbeddingsInBackground() async {
    if (_items.isEmpty) return;

    await Future.delayed(const Duration(seconds: 3));

    _dbg.log('RAG', 'starting background indexing '
        '(${_items.length} thoughts)');
    _isIndexing = true;
    notifyListeners();

    try {
      final sw = Stopwatch()..start();
      final indexed = await _vectorSearch.indexAll(_items);
      sw.stop();
      _dbg.log('RAG', 'background indexing done — '
          '$indexed new embeddings in ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      _dbg.log('RAG', 'background indexing error: $e');
    } finally {
      _isIndexing = false;
      notifyListeners();
    }
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

  Future<void> _runDeadLinkCheck({bool includeAlreadyDead = false}) async {
    _isCheckingDeadLinks = true;
    notifyListeners();

    final linkThoughts = _items
        .where((t) =>
            t.type == ThoughtType.link &&
            t.url != null &&
            (!t.isLinkDead || includeAlreadyDead))
        .toList();
        
    if (linkThoughts.isEmpty) {
      _isCheckingDeadLinks = false;
      notifyListeners();
      return;
    }

    final results = await _deadLinkService.checkLinks(linkThoughts);
    int deadCount = _items.where((t) => t.isLinkDead).length; // Start with current count
    
    for (final result in results) {
      final idx = _items.indexWhere((t) => t.id == result.thoughtId);
      if (idx != -1) {
        // Did the status change?
        if (_items[idx].isLinkDead != result.isDead) {
          if (result.isDead) {
            deadCount++;
          } else {
            deadCount--;
          }
          final updated = _items[idx].copyWith(isLinkDead: result.isDead);
          await _db.updateThought(updated);
          _items[idx] = updated;
        }
      }
    }

    // Ensure count is accurate across the entire list just to be safe
    _deadLinkCount = _items.where((t) => t.isLinkDead).length;
    _isCheckingDeadLinks = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.lastDeadLinkCheckPref,
        DateTime.now().toIso8601String());

    notifyListeners();
  }

  Future<void> forceDeadLinkCheck() async {
    await _runDeadLinkCheck(includeAlreadyDead: true);
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
