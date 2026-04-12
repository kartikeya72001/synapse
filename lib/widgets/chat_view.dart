import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import '../providers/synapse_provider.dart';
import '../theme/app_theme.dart';

class ChatView extends StatefulWidget {
  final double topPad;
  final double bottomPad;

  const ChatView({
    super.key,
    this.topPad = 0,
    this.bottomPad = 0,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<SynapseProvider>(
      builder: (context, provider, _) {
        final allMessages = provider.chatMessages;
        final messages =
            allMessages.where((m) => !m.isSystem).toList();
        final isLoading = provider.isChatLoading;

        return Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? Padding(
                      padding: EdgeInsets.only(top: widget.topPad),
                      child: _buildEmptyChat(theme, colorScheme),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        16, widget.topPad + 8, 16, 8,
                      ),
                      itemCount: messages.length + (isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && isLoading) {
                          return _buildTypingIndicator(colorScheme);
                        }
                        return _buildMessageBubble(
                          messages[index],
                          theme,
                          colorScheme,
                          isDark,
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: widget.bottomPad),
              child: _buildInputArea(theme, colorScheme, isDark, provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyChat(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SynapseColors.neuroPurple.withValues(alpha: 0.15),
                    SynapseColors.synapseBlue.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: SynapseColors.neuroPurple.withValues(alpha: 0.12),
                ),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    SynapseColors.gradientPrimary.createShader(bounds),
                child: const Icon(
                  Icons.psychology_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Your cortex is ready',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.28),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share links and posts from any app,\nthen ask me anything about them.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.18),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.secondary.withValues(alpha: 0.15),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser ? SynapseColors.gradientPrimary : null,
                color: isUser
                    ? null
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.15),
                      ),
                boxShadow: isUser
                    ? [
                        BoxShadow(
                          color: SynapseColors.neuroPurple.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: isUser
                  ? Text(
                      message.text,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.white,
                      ),
                    )
                  : _buildMarkdownBody(message.text, colorScheme, isDark),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMarkdownBody(
    String text,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return MarkdownBody(
      data: text,
      selectable: true,
      onTapLink: (_, href, __) {
        if (href != null) launchUrl(Uri.parse(href));
      },
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.inter(
          fontSize: 14.5,
          height: 1.55,
          color: colorScheme.onSurface,
        ),
        h1: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          height: 1.4,
        ),
        h2: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          height: 1.4,
        ),
        h3: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          height: 1.4,
        ),
        strong: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        em: GoogleFonts.inter(
          fontStyle: FontStyle.italic,
          color: colorScheme.onSurface.withValues(alpha: 0.85),
        ),
        listBullet: GoogleFonts.inter(
          fontSize: 14.5,
          color: colorScheme.onSurface,
        ),
        code: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: SynapseColors.neuroPurple,
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
        codeblockDecoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: SynapseColors.neuroPurple.withValues(alpha: 0.4),
              width: 3,
            ),
          ),
        ),
        blockquotePadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        a: GoogleFonts.inter(
          color: SynapseColors.neuroPurple,
          decoration: TextDecoration.underline,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        tableBorder: TableBorder.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
        tableHead: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: colorScheme.onSurface,
        ),
        tableBody: GoogleFonts.inter(
          fontSize: 13,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.secondary.withValues(alpha: 0.15),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 600 + i * 200),
                  builder: (_, value, child) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Opacity(
                        opacity: 0.3 + 0.7 * value,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                colorScheme.primary.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
    SynapseProvider provider,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.50),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Ask about your memories...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(provider),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: provider.isChatLoading
                    ? null
                    : () => _sendMessage(provider),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: SynapseColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage(SynapseProvider provider) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
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
}
