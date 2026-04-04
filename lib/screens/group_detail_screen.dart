import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/thought.dart';
import '../models/thought_group.dart';
import '../providers/synapse_provider.dart';
import '../theme/app_theme.dart';
import 'thought_detail_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final ThoughtGroup group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late ThoughtGroup _group;
  List<Thought> _thoughts = [];
  bool _isLoading = true;

  static const List<Color> _colorOptions = [
    Colors.purple,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.indigo,
  ];

  static const List<int?> _autoDeletePresets = [null, 7, 15, 30, 90, 180, 365];

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _loadThoughts();
  }

  Future<void> _loadThoughts() async {
    setState(() => _isLoading = true);
    final provider = context.read<SynapseProvider>();
    provider.filterByGroup(_group);
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        _thoughts = provider.items.toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groupColor = Color(_group.color);
    final isGlass = SynapseStyle.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: isGlass,
      appBar: AppBar(
        title: Text(_group.name, style: theme.appBarTheme.titleTextStyle),
        backgroundColor: groupColor.withValues(alpha: 0.08),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Rewire Cluster',
            onPressed: () => _showEditDialog(theme, colorScheme),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            tooltip: 'Dissolve Cluster',
            onPressed: () => _confirmDelete(theme, colorScheme),
          ),
        ],
      ),
      body: Container(
        decoration: isGlass
            ? BoxDecoration(
                gradient: isDark
                    ? SynapseColors.gradientAurora
                    : SynapseColors.gradientAuroraLight,
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: isGlass ? kToolbarHeight + MediaQuery.of(context).padding.top : 0,
            ),
            _buildHeader(theme, colorScheme, groupColor),
            Expanded(child: _buildThoughtsList(theme, colorScheme)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddThoughtsDialog(theme, colorScheme),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Wire Thoughts'),
        backgroundColor: groupColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme, Color groupColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: groupColor.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(
            color: groupColor.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_group.description != null && _group.description!.isNotEmpty) ...[
            Text(
              _group.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBadge(
                icon: Icons.format_list_numbered_rounded,
                label: '${_thoughts.length} thought${_thoughts.length == 1 ? '' : 's'}',
                color: groupColor,
                theme: theme,
              ),
              if (_group.autoDeleteDays != null)
                _buildBadge(
                  icon: Icons.auto_delete_rounded,
                  label: 'Auto-delete: ${_group.autoDeleteDays}d',
                  color: Colors.orange,
                  theme: theme,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThoughtsList(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_thoughts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  SynapseColors.gradientPrimary.createShader(bounds),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No synapses in this cluster yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap below to wire some in',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _thoughts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final thought = _thoughts[index];
        return _buildThoughtTile(thought, theme, colorScheme);
      },
    );
  }

  Widget _buildThoughtTile(Thought thought, ThemeData theme, ColorScheme colorScheme) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          thought.type == ThoughtType.link ? Icons.link_rounded : Icons.image_rounded,
          size: 20,
          color: colorScheme.primary,
        ),
      ),
      title: Text(
        thought.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${thought.category.emoji} ${thought.category.label}',
              style: TextStyle(fontSize: 11, color: colorScheme.primary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeago.format(thought.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.remove_circle_outline_rounded,
          size: 20,
          color: colorScheme.error.withValues(alpha: 0.6),
        ),
        tooltip: 'Unwire from cluster',
        onPressed: () async {
          final provider = context.read<SynapseProvider>();
          await provider.removeThoughtFromGroup(_group.id, thought.id);
          _loadThoughts();
        },
      ),
      onTap: () {
        Navigator.push(
          context,
          SynapsePageRoute(
            builder: (_) => ThoughtDetailScreen(item: thought),
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog(ThemeData theme, ColorScheme colorScheme) async {
    final nameController = TextEditingController(text: _group.name);
    final descController = TextEditingController(text: _group.description ?? '');
    int selectedColor = _group.color;
    int? selectedAutoDelete = _group.autoDeleteDays;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Rewire Cluster'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Cluster name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Optional description',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    Text('Color', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _colorOptions.map((color) {
                        final isSelected = selectedColor == color.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() => selectedColor = color.toARGB32());
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: colorScheme.onSurface, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text('Auto-Delete Override', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _autoDeletePresets.map((preset) {
                        final isActive = selectedAutoDelete == preset;
                        final label = preset == null ? 'Use global' : 'Override: ${preset}d';
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() => selectedAutoDelete = preset);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? colorScheme.primary
                                  : colorScheme.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      if (name.isEmpty) return;
      final updated = _group.copyWith(
        name: name,
        description: descController.text.trim().isEmpty ? null : descController.text.trim(),
        color: selectedColor,
        autoDeleteDays: selectedAutoDelete,
        updatedAt: DateTime.now(),
      );
      final provider = context.read<SynapseProvider>();
      await provider.updateGroup(updated);
      setState(() => _group = updated);
    }

    nameController.dispose();
    descController.dispose();
  }

  Future<void> _confirmDelete(ThemeData theme, ColorScheme colorScheme) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Dissolve Cluster?'),
          content: Text(
            'Dissolve "${_group.name}"? '
            'The thoughts within will remain in the brain.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      final provider = context.read<SynapseProvider>();
      await provider.deleteGroup(_group.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _showAddThoughtsDialog(ThemeData theme, ColorScheme colorScheme) async {
    final provider = context.read<SynapseProvider>();

    provider.filterByGroup(null);
    provider.filterByCategory(null);
    await Future.delayed(const Duration(milliseconds: 50));

    final allThoughts = provider.items.toList();
    final existingIds = _thoughts.map((t) => t.id).toSet();
    final available = allThoughts.where((t) => !existingIds.contains(t.id)).toList();

    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All thoughts are already wired to this cluster.')),
        );
      }
      _loadThoughts();
      return;
    }

    final selected = <String>{};

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Wire Thoughts'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: available.length,
                  itemBuilder: (_, index) {
                    final thought = available[index];
                    final isChecked = selected.contains(thought.id);
                    return CheckboxListTile(
                      value: isChecked,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            selected.add(thought.id);
                          } else {
                            selected.remove(thought.id);
                          }
                        });
                      },
                      title: Text(
                        thought.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        '${thought.category.emoji} ${thought.category.label}  •  ${timeago.format(thought.createdAt)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
                  child: Text('Add ${selected.isEmpty ? '' : '(${selected.length})'}'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && selected.isNotEmpty && mounted) {
      await provider.addThoughtsToGroup(_group.id, selected.toList());
      _loadThoughts();
    } else {
      _loadThoughts();
    }
  }
}
