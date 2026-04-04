import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/synapse_provider.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/share_handler_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'utils/permissions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const SynapseApp());
}

class SynapseApp extends StatefulWidget {
  const SynapseApp({super.key});

  @override
  State<SynapseApp> createState() => _SynapseAppState();
}

class _SynapseAppState extends State<SynapseApp> {
  final _shareHandler = ShareHandlerService();
  static const _qsChannel = MethodChannel('com.synapse.synapse/quicksettings');
  late SynapseProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = SynapseProvider();
    _provider.init();

    _shareHandler.onThoughtSaved = (thought) {
      _provider.addThought(thought);
    };
    _shareHandler.init();

    _qsChannel.setMethodCallHandler(_handleQsMethod);
    _checkInitialAction();
  }

  Future<void> _checkInitialAction() async {
    try {
      final action = await _qsChannel.invokeMethod<String>('getAction');
      if (action == 'save_latest_screenshot') {
        _saveLatestScreenshot();
      }
    } catch (_) {}
  }

  Future<dynamic> _handleQsMethod(MethodCall call) async {
    if (call.method == 'onQuickCapture') {
      _saveLatestScreenshot();
    }
  }

  Future<void> _saveLatestScreenshot() async {
    try {
      final granted = await AppPermissions.requestPhotosAccess();
      if (!granted) {
        debugPrint('Synapse: photo permission denied for QS tile');
        return;
      }
      final List<dynamic>? paths =
          await _qsChannel.invokeMethod<List<dynamic>>('listScreenshots');
      if (paths != null && paths.isNotEmpty) {
        final latestPath = paths.first as String;
        final thought = await _shareHandler.importImageIfNew(latestPath);
        if (thought != null) {
          _provider.addThought(thought);
          await _provider.loadThoughts();
        }
      }
    } catch (e) {
      debugPrint('Save latest screenshot failed: $e');
    }
  }

  @override
  void dispose() {
    _shareHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<SynapseProvider>(
        builder: (context, provider, _) {
          final isGlass = provider.isGlass;
          return SynapseStyle(
            isGlass: isGlass,
            child: MaterialApp(
              title: 'Synapse',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(glass: isGlass),
              darkTheme: AppTheme.darkTheme(glass: isGlass),
              themeMode: _mapThemeMode(provider.themeMode),
              home: _SynapseHome(
                shareHandler: _shareHandler,
                provider: _provider,
              ),
            ),
          );
        },
      ),
    );
  }

  ThemeMode _mapThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

class _SynapseHome extends StatefulWidget {
  final ShareHandlerService shareHandler;
  final SynapseProvider provider;

  const _SynapseHome({
    required this.shareHandler,
    required this.provider,
  });

  @override
  State<_SynapseHome> createState() => _SynapseHomeState();
}

class _SynapseHomeState extends State<_SynapseHome> {
  static const _qsChannel = MethodChannel('com.synapse.synapse/quicksettings');
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFirstLaunchPrompts();
    });
  }

  Future<void> _showFirstLaunchPrompts() async {
    final prefs = await SharedPreferences.getInstance();

    final qsPrompted = prefs.getBool(AppConstants.qsTilePromptedPref) ?? false;
    if (!qsPrompted && mounted) {
      await prefs.setBool(AppConstants.qsTilePromptedPref, true);
      await _showQsTileDialog();
    }

    if (!mounted) return;

    final galleryPrompted = prefs.getBool(AppConstants.galleryImportPromptedPref) ?? false;
    if (!galleryPrompted && mounted) {
      await prefs.setBool(AppConstants.galleryImportPromptedPref, true);
      await _showGalleryImportDialog();
    }
  }

  Future<void> _showQsTileDialog() async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.screenshot_monitor_rounded, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Instant Recall')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capture a thought the moment it sparks.'),
            SizedBox(height: 12),
            Text('Wire up the Quick Settings tile:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('1. Swipe down from the top of your screen'),
            Text('2. Swipe down again to expand Quick Settings'),
            Text('3. Tap the pencil/edit icon'),
            Text('4. Find "Synapse Capture" and drag it to your tiles'),
            SizedBox(height: 12),
            Text('Take a screenshot, then tap the tile to fire it into your brain!'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Wired!'),
          ),
        ],
      ),
    );
  }

  Future<void> _showGalleryImportDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.photo_library_rounded, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Absorb Memories')),
          ],
        ),
        content: const Text(
          'Want to absorb existing screenshots into your brain? '
          'Synapse will scan your device automatically. '
          'Already memorized ones are skipped.\n\n'
          'You can always do this later from Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Absorb'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _importScreenshotsFromDevice();
    }
  }

  Future<void> _importScreenshotsFromDevice() async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final granted = await AppPermissions.requestPhotosAccess();
    if (!granted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Synapse needs photo access to scan your memories.')),
      );
      return;
    }

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Scanning neural pathways...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final List<dynamic>? paths =
          await _qsChannel.invokeMethod<List<dynamic>>('listScreenshots');

      if (paths == null || paths.isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('No memories found to absorb.')),
        );
        return;
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Found ${paths.length} memories, absorbing...'),
          duration: const Duration(seconds: 2),
        ),
      );

      int imported = 0;
      int skipped = 0;

      for (final p in paths) {
        final path = p as String;
        final thought = await widget.shareHandler.importImageIfNew(path);
        if (thought != null) {
          widget.provider.addThought(thought);
          imported++;
        } else {
          skipped++;
        }
      }

      await widget.provider.loadThoughts();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Absorbed $imported memory${imported != 1 ? ' fragments' : ''}'
            '${skipped > 0 ? ', $skipped already in the brain' : ''}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Screenshot import failed: $e');
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Couldn\'t reach the memory banks.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onComplete: () => setState(() => _showSplash = false),
      );
    }
    return const HomeScreen();
  }
}
