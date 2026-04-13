import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/thought.dart';
import '../providers/synapse_provider.dart';
import '../theme/app_theme.dart';
import 'thought_detail_screen.dart';

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen>
    with AutomaticKeepAliveClientMixin {
  final _graphTransform = TransformationController();
  String? _hoveredNodeId;
  bool _tagsExpanded = false;

  int _lastDataVersion = -1;
  _PulseData? _data;
  bool _isComputing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeIfNeeded());
  }

  @override
  void dispose() {
    _graphTransform.dispose();
    super.dispose();
  }

  void _recomputeIfNeeded() {
    if (!mounted || _isComputing) return;
    final provider = context.read<SynapseProvider>();
    final currentVersion = provider.dataVersion;
    if (currentVersion == _lastDataVersion && _data != null) return;
    _lastDataVersion = currentVersion;
    _isComputing = true;
    setState(() {});
    Future.microtask(() {
      final all = provider.allItems;
      final data = _computeData(all);
      if (mounted) setState(() { _data = data; _isComputing = false; });
    });
  }

  _PulseData _computeData(List<Thought> all) {
    final wired = all.where((t) => t.isClassified).length;
    final tagSet = <String>{};
    final sourceSet = <String>{};
    final tagCounts = <String, int>{};
    final sourceCounts = <String, int>{};
    final catCounts = <ThoughtCategory, int>{};
    final dailyCounts = <String, int>{};

    final now = DateTime.now();
    for (int i = 29; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      dailyCounts['${d.month}/${d.day}'] = 0;
    }

    for (final t in all) {
      catCounts[t.category] = (catCounts[t.category] ?? 0) + 1;
      for (final tag in t.tags) {
        if (tag.isNotEmpty) {
          tagSet.add(tag);
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
      final src = t.siteName ?? _hostFromUrl(t.url);
      if (src != null && src.isNotEmpty) {
        sourceSet.add(src);
        sourceCounts[src] = (sourceCounts[src] ?? 0) + 1;
      }
      final key = '${t.createdAt.month}/${t.createdAt.day}';
      if (dailyCounts.containsKey(key)) {
        dailyCounts[key] = dailyCounts[key]! + 1;
      }
    }

    final graph = _buildGraphData(all, catCounts);

    return _PulseData(
      total: all.length,
      wired: wired,
      unwired: all.length - wired,
      tagCount: tagSet.length,
      sourceCount: sourceSet.length,
      catCounts: catCounts,
      tagCounts: tagCounts,
      sourceCounts: sourceCounts,
      dailyCounts: dailyCounts,
      graph: graph,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentVersion = context.select<SynapseProvider, int>(
        (p) => p.dataVersion);
    if (currentVersion != _lastDataVersion) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeIfNeeded());
    }

    if (_isComputing || _data == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: isDark ? SynapseGradients.pulseBgDark : SynapseGradients.pulseBg,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? SynapseColors.darkAccent : SynapseColors.accent,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Analyzing...',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: SynapseColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data!;
    final provider = context.read<SynapseProvider>();

    if (data.total == 0) {
      return Container(
        decoration: BoxDecoration(
          gradient: isDark ? SynapseGradients.pulseBgDark : SynapseGradients.pulseBg,
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        SynapseColors.mint.withValues(alpha: 0.5),
                        SynapseColors.mint.withValues(alpha: 0.0),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: SynapseColors.mintLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.monitor_heart_outlined,
                          size: 24, color: SynapseColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your pulse is quiet',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Analytics will come to life as you\nadd memories. Start by sharing a\nlink or post from any app.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      color: SynapseColors.inkMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? SynapseGradients.pulseBgDark : SynapseGradients.pulseBg,
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(isDark),
            SliverToBoxAdapter(child: _buildStatsRow(isDark, data, provider)),
            SliverToBoxAdapter(child: _buildSectionTitle(isDark, 'Category Breakdown')),
            SliverToBoxAdapter(child: _buildDonutChart(isDark, data)),
            SliverToBoxAdapter(child: _buildSectionTitle(isDark, 'Activity')),
            SliverToBoxAdapter(child: _buildActivityChart(isDark, data)),
            SliverToBoxAdapter(child: _buildSectionTitle(isDark, 'Top Sources')),
            SliverToBoxAdapter(child: _buildTopSources(isDark, data)),
            SliverToBoxAdapter(child: _buildSectionTitle(isDark, 'Tag Cloud')),
            SliverToBoxAdapter(child: _buildTagCloud(isDark, data)),
            SliverToBoxAdapter(child: _buildGraphHeader(isDark)),
            SliverToBoxAdapter(child: _buildKnowledgeGraph(isDark, data)),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  // ── Header ──

  SliverToBoxAdapter _buildHeader(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 16, 6),
        child: Text(
          'Pulse',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(bool isDark, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildGraphHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Row(
        children: [
          Text(
            'Knowledge Graph',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'touch a node to interact',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 1: Overview Stats ──

  Widget _buildStatsRow(bool isDark, _PulseData data, SynapseProvider provider) {
    final stats = [
      _Stat('Total', data.total, Icons.layers_rounded, const Color(0xFF8B5BD8)),
      _Stat('Wired', data.wired, Icons.auto_awesome_rounded, const Color(0xFF00897B)),
      _Stat('Unwired', data.unwired, Icons.hourglass_top_rounded, const Color(0xFFE88A4D)),
      _Stat('Dead Links', provider.deadLinkCount, Icons.link_off_rounded, const Color(0xFFD32F2F)),
      _Stat('Tags', data.tagCount, Icons.tag_rounded, const Color(0xFF5B9BD5)),
      _Stat('Sources', data.sourceCount, Icons.public_rounded, const Color(0xFFA371F2)),
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _buildStatCard(isDark, stats[i]),
      ),
    );
  }

  Widget _buildStatCard(bool isDark, _Stat stat) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? stat.color.withValues(alpha: 0.12)
            : stat.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stat.color.withValues(alpha: isDark ? 0.2 : 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(stat.icon, size: 18, color: stat.color),
          Text(
            '${stat.value}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
            ),
          ),
          Text(
            stat.label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? SynapseColors.darkInkMuted : SynapseColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 2: Donut Chart ──

  Widget _buildDonutChart(bool isDark, _PulseData data) {
    if (data.catCounts.isEmpty) return _emptySection(isDark, 'No data yet');

    final sorted = data.catCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _sectionBox(isDark),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              width: 180,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _DonutPainter(entries: sorted, total: data.total, isDark: isDark),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${data.total}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                          ),
                        ),
                        Text(
                          'total',
                          style: GoogleFonts.spaceGrotesk(fontSize: 11, color: SynapseColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: sorted.take(8).map((e) {
                final pct = (e.value / data.total * 100).toStringAsFixed(0);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: _categoryColor(e.key), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${e.key.label} $pct%',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? SynapseColors.darkInkMuted : SynapseColors.inkMuted,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section 3: Activity Chart ──

  Widget _buildActivityChart(bool isDark, _PulseData data) {
    if (data.total == 0) return _emptySection(isDark, 'No activity yet');
    final maxVal = data.dailyCounts.values.fold(0, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        decoration: _sectionBox(isDark),
        child: SizedBox(
          height: 140,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _BarChartPainter(data: data.dailyCounts, maxVal: maxVal, isDark: isDark),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }

  // ── Section 4: Top Sources ──

  Widget _buildTopSources(bool isDark, _PulseData data) {
    if (data.sourceCounts.isEmpty) return _emptySection(isDark, 'No sources yet');

    final sorted = data.sourceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    final maxCount = top.first.value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _sectionBox(isDark),
        child: Column(
          children: top.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final fraction = maxCount > 0 ? e.value / maxCount : 0.0;
            return Padding(
              padding: EdgeInsets.only(bottom: i < top.length - 1 ? 8 : 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      e.key,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : SynapseColors.ink.withValues(alpha: 0.04),
                        valueColor: AlwaysStoppedAnimation(_sourceColor(i)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${e.value}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: isDark ? SynapseColors.darkInkMuted : SynapseColors.inkMuted,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Section 5: Tag Cloud ──

  Widget _buildTagCloud(bool isDark, _PulseData data) {
    if (data.tagCounts.isEmpty) return _emptySection(isDark, 'No tags yet');

    final sorted = data.tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sorted.first.value;
    final showCount = _tagsExpanded ? sorted.length.clamp(0, 60) : 12;
    final visible = sorted.take(showCount);
    final hasMore = sorted.length > 12;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _sectionBox(isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: visible.map((e) {
                final scale = maxCount > 1 ? 0.5 + 0.5 * (e.value / maxCount) : 1.0;
                final fontSize = 10.0 + 6.0 * scale;
                final alpha = 0.4 + 0.6 * scale;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: SynapseColors.accent
                        .withValues(alpha: isDark ? 0.08 * scale + 0.04 : 0.05 * scale + 0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: SynapseColors.accent.withValues(alpha: isDark ? 0.15 : 0.08),
                    ),
                  ),
                  child: Text(
                    '#${e.key}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? SynapseColors.darkAccent : SynapseColors.accent)
                          .withValues(alpha: alpha),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _tagsExpanded = !_tagsExpanded),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _tagsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 16,
                        color: SynapseColors.accent.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _tagsExpanded ? 'Show less' : '${sorted.length - 12} more tags',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SynapseColors.accent.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Section 6: Knowledge Graph ──

  Widget _buildKnowledgeGraph(bool isDark, _PulseData data) {
    if (data.total == 0) return _emptySection(isDark, 'Add memories to see your graph');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        children: [
          GestureDetector(
            onTapUp: (d) => _handleGraphTap(d, data.graph, isDark),
            child: Container(
              height: 420,
              decoration: _sectionBox(isDark),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: InteractiveViewer(
                  transformationController: _graphTransform,
                  minScale: 0.3,
                  maxScale: 4.0,
                  boundaryMargin: const EdgeInsets.all(200),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _GraphPainter(
                        graph: data.graph,
                        isDark: isDark,
                        hoveredId: _hoveredNodeId,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => _openFullscreenGraph(isDark, data),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.fullscreen_rounded,
                  size: 18,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreenGraph(bool isDark, _PulseData data) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenGraph(
          graph: data.graph,
          isDark: isDark,
          allItems: context.read<SynapseProvider>().allItems,
        ),
      ),
    );
  }

  _GraphData _buildGraphData(List<Thought> all, Map<ThoughtCategory, int> catCounts) {
    final activeCats = catCounts.keys.toList();
    if (activeCats.isEmpty) {
      return const _GraphData(centroids: [], memoryNodes: [], edges: []);
    }

    final tagToCategories = <String, Set<ThoughtCategory>>{};
    for (final t in all) {
      for (final tag in t.tags) {
        if (tag.isNotEmpty) {
          tagToCategories.putIfAbsent(tag, () => {}).add(t.category);
        }
      }
    }

    const centerX = 210.0;
    const centerY = 210.0;
    const catRadius = 140.0;
    final rng = math.Random(42);

    final centroids = <_GraphNode>[];
    for (int i = 0; i < activeCats.length; i++) {
      final angle = (2 * math.pi * i / activeCats.length) - math.pi / 2;
      centroids.add(_GraphNode(
        id: 'cat_${activeCats[i].name}',
        label: '${activeCats[i].emoji} ${activeCats[i].label}',
        x: centerX + catRadius * math.cos(angle),
        y: centerY + catRadius * math.sin(angle),
        radius: 18 + (catCounts[activeCats[i]]! * 0.5).clamp(0, 12).toDouble(),
        color: _categoryColor(activeCats[i]),
        isCentroid: true,
      ));
    }

    final catIndex = {for (int i = 0; i < activeCats.length; i++) activeCats[i]: i};
    final memoryNodes = <_GraphNode>[];
    final edges = <_GraphEdge>[];

    for (final t in all) {
      final ci = catIndex[t.category]!;
      final centroid = centroids[ci];
      final spreadRadius = 30.0 + (catCounts[t.category]! * 1.5).clamp(0, 40);
      final angle = rng.nextDouble() * 2 * math.pi;
      final dist = rng.nextDouble() * spreadRadius + 20;
      final node = _GraphNode(
        id: t.id,
        label: t.displayTitle,
        x: centroid.x + dist * math.cos(angle),
        y: centroid.y + dist * math.sin(angle),
        radius: 4,
        color: centroid.color.withValues(alpha: 0.7),
        isCentroid: false,
      );
      memoryNodes.add(node);
      edges.add(_GraphEdge(fromId: t.id, toId: centroid.id, strength: 1.0));

      for (final tag in t.tags) {
        final cats = tagToCategories[tag];
        if (cats == null) continue;
        for (final otherCat in cats) {
          if (otherCat == t.category) continue;
          final oi = catIndex[otherCat];
          if (oi == null) continue;
          edges.add(_GraphEdge(fromId: t.id, toId: centroids[oi].id, strength: 0.3));
        }
      }
    }

    _runForceSimulation(centroids, memoryNodes, edges);
    return _GraphData(centroids: centroids, memoryNodes: memoryNodes, edges: edges);
  }

  void _runForceSimulation(
    List<_GraphNode> centroids,
    List<_GraphNode> nodes,
    List<_GraphEdge> edges,
  ) {
    final allNodes = [...centroids, ...nodes];
    final nodeMap = {for (final n in allNodes) n.id: n};
    const iterations = 50;

    for (int iter = 0; iter < iterations; iter++) {
      final temp = 1.0 - (iter / iterations);

      for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
          final a = nodes[i];
          final b = nodes[j];
          var dx = a.x - b.x;
          var dy = a.y - b.y;
          final distSq = dx * dx + dy * dy + 1;
          final force = 200 * temp / distSq;
          dx *= force;
          dy *= force;
          a.x += dx;
          a.y += dy;
          b.x -= dx;
          b.y -= dy;
        }
      }

      for (final edge in edges) {
        final from = nodeMap[edge.fromId];
        final to = nodeMap[edge.toId];
        if (from == null || to == null || from.isCentroid) continue;
        final dx = to.x - from.x;
        final dy = to.y - from.y;
        final springK = 0.02 * edge.strength * temp;
        from.x += dx * springK;
        from.y += dy * springK;
      }
    }
  }

  void _handleGraphTap(TapUpDetails details, _GraphData graph, bool isDark) {
    final localPos = _graphTransform.toScene(details.localPosition);
    _GraphNode? hit;
    for (final n in [...graph.memoryNodes, ...graph.centroids]) {
      final dx = n.x - localPos.dx;
      final dy = n.y - localPos.dy;
      final hitRadius = n.isCentroid ? n.radius + 6 : n.radius + 10;
      if (dx * dx + dy * dy < hitRadius * hitRadius) {
        hit = n;
        break;
      }
    }
    setState(() => _hoveredNodeId = hit?.id);
    if (hit != null && !hit.isCentroid) {
      _showNodePopup(hit, isDark);
    }
  }

  void _showNodePopup(_GraphNode node, bool isDark) {
    final provider = context.read<SynapseProvider>();
    Thought? thought;
    try {
      thought = provider.allItems.firstWhere((t) => t.id == node.id);
    } catch (_) {}

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1A2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  node.label,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (thought != null)
                      GestureDetector(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            SynapsePageRoute(
                              builder: (_) => ThoughtDetailScreen(item: thought!),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: SynapseColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Open Memory',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? SynapseColors.darkAccent : SynapseColors.accent,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? SynapseColors.darkInkMuted : SynapseColors.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ──

  BoxDecoration _sectionBox(bool isDark) => BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        ),
      );

  Widget _emptySection(bool isDark, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(fontSize: 13, color: SynapseColors.inkMuted),
        ),
      ),
    );
  }

  static String? _hostFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return null;
    }
  }

  static Color _sourceColor(int index) {
    const palette = [
      Color(0xFF8B5BD8), Color(0xFF00897B), Color(0xFF5B9BD5), Color(0xFFE88A4D),
      Color(0xFFA371F2), Color(0xFFD32F2F), Color(0xFF43A047), Color(0xFF1E88E5),
    ];
    return palette[index % palette.length];
  }

  static Color _categoryColor(ThoughtCategory cat) {
    const colors = {
      ThoughtCategory.article: Color(0xFF5B9BD5),
      ThoughtCategory.socialMedia: Color(0xFFE040FB),
      ThoughtCategory.video: Color(0xFFFF5252),
      ThoughtCategory.image: Color(0xFF69F0AE),
      ThoughtCategory.recipe: Color(0xFFFFAB40),
      ThoughtCategory.product: Color(0xFF29B6F6),
      ThoughtCategory.news: Color(0xFFEF5350),
      ThoughtCategory.reference: Color(0xFF7E57C2),
      ThoughtCategory.inspiration: Color(0xFFFFD54F),
      ThoughtCategory.todo: Color(0xFF66BB6A),
      ThoughtCategory.game: Color(0xFFAB47BC),
      ThoughtCategory.family: Color(0xFFEC407A),
      ThoughtCategory.entertainment: Color(0xFFFF7043),
      ThoughtCategory.music: Color(0xFF26C6DA),
      ThoughtCategory.tool: Color(0xFF78909C),
      ThoughtCategory.vacation: Color(0xFF26A69A),
      ThoughtCategory.sports: Color(0xFF9CCC65),
      ThoughtCategory.stocks: Color(0xFF42A5F5),
      ThoughtCategory.education: Color(0xFF5C6BC0),
      ThoughtCategory.health: Color(0xFFEF5350),
      ThoughtCategory.finance: Color(0xFF66BB6A),
      ThoughtCategory.travel: Color(0xFF29B6F6),
      ThoughtCategory.other: Color(0xFF8D6E63),
    };
    return colors[cat] ?? const Color(0xFF8D6E63);
  }
}

// ── Cached data ──

class _PulseData {
  final int total, wired, unwired, tagCount, sourceCount;
  final Map<ThoughtCategory, int> catCounts;
  final Map<String, int> tagCounts;
  final Map<String, int> sourceCounts;
  final Map<String, int> dailyCounts;
  final _GraphData graph;

  const _PulseData({
    required this.total,
    required this.wired,
    required this.unwired,
    required this.tagCount,
    required this.sourceCount,
    required this.catCounts,
    required this.tagCounts,
    required this.sourceCounts,
    required this.dailyCounts,
    required this.graph,
  });
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
}

class _GraphNode {
  final String id, label;
  double x, y;
  final double radius;
  final Color color;
  final bool isCentroid;
  _GraphNode({
    required this.id, required this.label,
    required this.x, required this.y,
    required this.radius, required this.color,
    required this.isCentroid,
  });
}

class _GraphEdge {
  final String fromId, toId;
  final double strength;
  const _GraphEdge({required this.fromId, required this.toId, required this.strength});
}

class _GraphData {
  final List<_GraphNode> centroids;
  final List<_GraphNode> memoryNodes;
  final List<_GraphEdge> edges;
  const _GraphData({required this.centroids, required this.memoryNodes, required this.edges});
}

// ── Painters ──

class _DonutPainter extends CustomPainter {
  final List<MapEntry<ThoughtCategory, int>> entries;
  final int total;
  final bool isDark;
  _DonutPainter({required this.entries, required this.total, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;
    final innerR = outerR * 0.6;
    final sw = outerR - innerR;
    double start = -math.pi / 2;
    for (final e in entries) {
      final sweep = (e.value / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (outerR + innerR) / 2),
        start, sweep - 0.02, false,
        Paint()
          ..color = _PulseScreenState._categoryColor(e.key)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.total != total;
}

class _BarChartPainter extends CustomPainter {
  final Map<String, int> data;
  final int maxVal;
  final bool isDark;
  _BarChartPainter({required this.data, required this.maxVal, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxVal == 0) return;
    final entries = data.entries.toList();
    final bw = (size.width / entries.length) * 0.6;
    final gap = (size.width / entries.length) * 0.4;
    final step = bw + gap;
    final ch = size.height - 20;

    for (int i = 0; i < entries.length; i++) {
      final h = (entries[i].value / maxVal) * ch;
      final x = i * step + gap / 2;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, ch - h, bw, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF00897B), const Color(0xFF00897B).withValues(alpha: 0.4)],
          ).createShader(rrect.outerRect),
      );
      if (i % 5 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: entries[i].key,
            style: TextStyle(
              fontSize: 7,
              color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x, ch + 4));
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.maxVal != maxVal;
}

class _GraphPainter extends CustomPainter {
  final _GraphData graph;
  final bool isDark;
  final String? hoveredId;
  _GraphPainter({required this.graph, required this.isDark, this.hoveredId});

  @override
  void paint(Canvas canvas, Size size) {
    final allNodes = {
      for (final n in [...graph.centroids, ...graph.memoryNodes]) n.id: n,
    };

    for (final edge in graph.edges) {
      final from = allNodes[edge.fromId];
      final to = allNodes[edge.toId];
      if (from == null || to == null) continue;
      canvas.drawLine(
        Offset(from.x, from.y),
        Offset(to.x, to.y),
        Paint()
          ..color = (isDark ? Colors.white : Colors.black)
              .withValues(alpha: edge.strength * 0.12)
          ..strokeWidth = edge.strength > 0.5 ? 0.8 : 0.4,
      );
    }

    for (final node in graph.memoryNodes) {
      if (node.id == hoveredId) {
        canvas.drawCircle(Offset(node.x, node.y), node.radius + 3,
            Paint()..color = node.color.withValues(alpha: 0.3));
      }
      canvas.drawCircle(Offset(node.x, node.y), node.radius, Paint()..color = node.color);
    }

    for (final node in graph.centroids) {
      canvas.drawCircle(Offset(node.x, node.y), node.radius + 4,
          Paint()..color = node.color.withValues(alpha: 0.15));
      canvas.drawCircle(Offset(node.x, node.y), node.radius,
          Paint()..color = node.color.withValues(alpha: node.id == hoveredId ? 1.0 : 0.85));
      final tp = TextPainter(
        text: TextSpan(
          text: node.label,
          style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(node.x - tp.width / 2, node.y + node.radius + 4));
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => old.hoveredId != hoveredId || old.isDark != isDark;
}

// ── Fullscreen Graph ──

class _FullscreenGraph extends StatefulWidget {
  final _GraphData graph;
  final bool isDark;
  final List<Thought> allItems;
  const _FullscreenGraph({required this.graph, required this.isDark, required this.allItems});

  @override
  State<_FullscreenGraph> createState() => _FullscreenGraphState();
}

class _FullscreenGraphState extends State<_FullscreenGraph> {
  final _transform = TransformationController();
  String? _hoveredId;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050308) : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            InteractiveViewer(
              transformationController: _transform,
              minScale: 0.2,
              maxScale: 6.0,
              boundaryMargin: const EdgeInsets.all(400),
              child: GestureDetector(
                onTapUp: (d) => _onTap(d, isDark),
                child: CustomPaint(
                  painter: _GraphPainter(
                    graph: widget.graph,
                    isDark: isDark,
                    hoveredId: _hoveredId,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 16,
              child: Text(
                'Knowledge Graph',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.fullscreen_exit_rounded,
                    size: 20,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(TapUpDetails details, bool isDark) {
    final pos = _transform.toScene(details.localPosition);
    _GraphNode? hit;
    for (final n in [...widget.graph.memoryNodes, ...widget.graph.centroids]) {
      final dx = n.x - pos.dx;
      final dy = n.y - pos.dy;
      final hitRadius = n.isCentroid ? n.radius + 6 : n.radius + 10;
      if (dx * dx + dy * dy < hitRadius * hitRadius) {
        hit = n;
        break;
      }
    }
    setState(() => _hoveredId = hit?.id);
    if (hit != null && !hit.isCentroid) {
      Thought? thought;
      try {
        thought = widget.allItems.firstWhere((t) => t.id == hit!.id);
      } catch (_) {}

      showDialog(
        context: context,
        barrierColor: Colors.black38,
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1A2E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hit!.label,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (thought != null)
                        GestureDetector(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).push(
                              SynapsePageRoute(
                                builder: (_) => ThoughtDetailScreen(item: thought!),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: SynapseColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Open Memory',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? SynapseColors.darkAccent : SynapseColors.accent,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Close',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? SynapseColors.darkInkMuted : SynapseColors.inkMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }
}
