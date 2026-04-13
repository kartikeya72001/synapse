import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import '../providers/synapse_provider.dart';
import '../theme/app_theme.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<SynapseProvider>(
      builder: (context, provider, _) {
        final messages = provider.chatMessages
            .where((m) => !m.isSystem)
            .toList();
        final isLoading = provider.isChatLoading;

        return Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? SynapseGradients.chatBgDark
                : SynapseGradients.chatBg,
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(isDark, messages.isNotEmpty),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: messages.isEmpty
                            ? _buildEmptyChat(isDark, provider)
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  148,
                                ),
                                itemCount:
                                    messages.length + (isLoading ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == messages.length && isLoading) {
                                    return _buildTypingDots(isDark);
                                  }
                                  return _buildBubble(messages[index], isDark);
                                },
                              ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildInput(isDark, provider),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark, bool hasMessages) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 10),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (context, child) {
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  final dx = _shimmerCtrl.value * 3 - 1;
                  return LinearGradient(
                    begin: Alignment(dx - 0.3, 0),
                    end: Alignment(dx + 0.3, 0),
                    colors: [
                      isDark ? SynapseColors.darkInk : SynapseColors.ink,
                      isDark ? SynapseColors.darkAccent : SynapseColors.accent,
                      isDark ? SynapseColors.darkInk : SynapseColors.ink,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(bounds);
                },
                child: child,
              );
            },
            child: Text(
              'Cortex',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const Spacer(),
          if (hasMessages)
            GestureDetector(
              onTap: () => _confirmClearChat(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SynapseColors.ink.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_sweep_outlined,
                  size: 18,
                  color: SynapseColors.inkFaint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(bool isDark, SynapseProvider provider) {
    final suggestions = [
      'What did I save about travel?',
      'Summarize my recent links',
      'Any restaurant recommendations?',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: isDark
                      ? [const Color(0x40BF9EF7), const Color(0x00BF9EF7)]
                      : [const Color(0x40D4C4F0), const Color(0x00D4C4F0)],
                  radius: 0.85,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark
                        ? SynapseColors.darkLavender
                        : SynapseColors.lavenderLight,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: isDark
                        ? SynapseColors.darkAccent
                        : SynapseColors.accent,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Ask me anything',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'I can search through your saved\nmemories and answer questions.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: SynapseColors.inkMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions
                  .map((s) => _suggestionChip(s, provider))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String text, SynapseProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () async {
        _controller.text = text;
        await _send(provider);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? SynapseColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.06,
            ),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg, bool isDark) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(top: 4, right: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? SynapseColors.darkLavender
                    : SynapseColors.lavenderLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: isDark ? SynapseColors.darkAccent : SynapseColors.accent,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: isUser
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? const [Color(0xFFBF9EF7), Color(0xFF9B70E0)]
                            : const [Color(0xFFA371F2), Color(0xFF8B5BD8)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                        bottomLeft: Radius.circular(22),
                        bottomRight: Radius.circular(6),
                      ),
                    )
                  : BoxDecoration(
                      color: isDark ? SynapseColors.darkCard : Colors.white,
                      border: isDark
                          ? null
                          : Border.all(
                              color: Colors.black.withValues(alpha: 0.04),
                            ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(22),
                      ),
                    ),
              child: isUser
                  ? Text(
                      msg.text,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        height: 1.45,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    )
                  : _buildMarkdown(msg.text, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdown(String text, bool isDark) {
    final ink = isDark ? SynapseColors.darkInk : SynapseColors.ink;

    return MarkdownBody(
      data: text,
      selectable: true,
      onTapLink: (_, href, __) {
        if (href != null) launchUrl(Uri.parse(href));
      },
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.spaceGrotesk(fontSize: 14, height: 1.5, color: ink),
        h1: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        h2: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        h3: GoogleFonts.spaceGrotesk(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        strong: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        em: GoogleFonts.spaceGrotesk(fontStyle: FontStyle.italic, color: ink),
        listBullet: GoogleFonts.spaceGrotesk(fontSize: 14, color: ink),
        code: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: SynapseColors.accent,
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : SynapseColors.lavenderLight,
        ),
        codeblockDecoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : SynapseColors.lavenderLight,
          borderRadius: BorderRadius.circular(12),
        ),
        codeblockPadding: const EdgeInsets.all(14),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: SynapseColors.accent.withValues(alpha: 0.4),
              width: 3,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        a: GoogleFonts.spaceGrotesk(
          color: SynapseColors.accent,
          decoration: TextDecoration.underline,
        ),
        tableBorder: TableBorder.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : SynapseColors.ink.withValues(alpha: 0.08),
          width: 0.5,
        ),
        tableHead: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: ink,
        ),
        tableBody: GoogleFonts.spaceGrotesk(fontSize: 12, color: ink),
      ),
    );
  }

  Widget _buildTypingDots(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? SynapseColors.darkLavender
                  : SynapseColors.lavenderLight,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: SynapseColors.accent.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: isDark ? SynapseColors.darkAccent : SynapseColors.accent,
            ),
          ),
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (context, child) {
              final glowAlpha =
                  (0.15 + 0.15 * math.sin(_shimmerCtrl.value * 2 * math.pi));
              return Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                    bottomLeft: Radius.circular(8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SynapseColors.accent.withValues(alpha: glowAlpha),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? SynapseColors.darkCard : Colors.white,
                border: isDark
                    ? null
                    : Border.all(color: Colors.black.withValues(alpha: 0.04)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _PulseDot(delay: i * 180),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(bool isDark, SynapseProvider provider) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad + 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? SynapseColors.darkCard.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Ask about your memories...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(provider),
                maxLines: 3,
                minLines: 1,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: provider.isChatLoading ? null : () => _send(provider),
              child: AnimatedBuilder(
                animation: _shimmerCtrl,
                builder: (context, _) {
                  final pulse =
                      (0.5 +
                          0.5 *
                              math
                                  .sin(_shimmerCtrl.value * 2 * math.pi)
                                  .abs()) *
                      0.3;
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                SynapseColors.darkAccent,
                                const Color(0xFF9B70E0),
                              ]
                            : [SynapseColors.accent, SynapseColors.accentDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: SynapseColors.accent.withValues(alpha: pulse),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: isDark ? Colors.black : Colors.white,
                      size: 20,
                    ),
                  );
                },
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(SynapseProvider provider) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _scrollToBottom();
    await provider.sendChatMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _confirmClearChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('This erases the conversation. Memories are safe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SynapseProvider>().clearChat();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final int delay;
  const _PulseDot({required this.delay});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.3 + 0.7 * _ctrl.value,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: SynapseColors.accent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
