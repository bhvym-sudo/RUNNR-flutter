import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/liked_songs_service_hive.dart';
import 'services/playlist_service.dart';
import 'services/version_check_service.dart';
import 'providers/player_provider.dart';
import 'providers/liked_songs_provider.dart';
import 'providers/playlist_provider.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'widgets/mini_player.dart';
import 'widgets/force_update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage (must be called first)
  await Hive.initFlutter();
  await LikedSongsServiceHive.initialize();
  await PlaylistService.initialize();

  // Request notification permission for Android 13+
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1E202E), // davysGray
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const RunnrApp());
}

class RunnrApp extends StatelessWidget {
  const RunnrApp({super.key});

  // RUNNR Color Palette
  static const Color night = Color(0xFF000000); // #000000
  static const Color eerieBlack = Color(0xFF0A0A0D); // #0a0a0d
  static const Color darkerBg = Color(0xFF08080B); // #08080b
  static const Color davysGray = Color(0xFF1E202E); // #1e202e
  static const Color cardBg = Color(0xFF1E202E); // #1e202e
  static const Color accentColor = Color(0xFF3D59A1); // #3d59a1
  static const Color accentHover = Color(0xFF4A6BB5); // #4a6bb5

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProxyProvider<PlayerProvider, LikedSongsProvider>(
          create: (context) => LikedSongsProvider()..loadLikedSongs(),
          update: (context, playerProvider, likedSongsProvider) {
            // Link the providers so liked songs can update player's playlist
            likedSongsProvider!.setPlayerProvider(playerProvider);
            return likedSongsProvider;
          },
        ),
        ChangeNotifierProxyProvider<PlayerProvider, PlaylistProvider>(
          create: (context) => PlaylistProvider()..loadPlaylists(),
          update: (context, playerProvider, playlistProvider) {
            // Link the providers so playlists can update player's playlist
            playlistProvider!.setPlayerProvider(playerProvider);
            return playlistProvider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'RUNNR',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.dark(
            primary: accentColor,
            secondary: accentHover,
            surface: cardBg,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Colors.white,
          ),
          scaffoldBackgroundColor: night,
          appBarTheme: const AppBarTheme(
            backgroundColor: eerieBlack,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: davysGray,
            selectedItemColor: accentColor,
            unselectedItemColor: Color(0xFF6B6B7B),
            type: BottomNavigationBarType.fixed,
            elevation: 8,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white70),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isUpdateRequired = false;
  String _currentVersion = '';
  String _latestVersion = '';

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Check for updates when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _checkForUpdates();
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final updateRequired = await VersionCheckService.isUpdateRequired();

      if (!mounted) return;

      if (updateRequired) {
        final currentVersion = await VersionCheckService.getCurrentVersion();
        final latestVersion = await VersionCheckService.getLatestVersion();

        setState(() {
          _isUpdateRequired = true;
          _currentVersion = currentVersion;
          _latestVersion = latestVersion ?? '';
        });

        // Show dialog after frame is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isUpdateRequired) {
            _showForceUpdateDialog();
          }
        });
      } else {
        // Update not required - dismiss dialog if showing
        setState(() {
          _isUpdateRequired = false;
        });
        if (mounted) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
  }

  void _showForceUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ForceUpdateDialog(
        currentVersion: _currentVersion,
        latestVersion: _latestVersion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Stack(
          children: [
            // Main content
            IndexedStack(index: _currentIndex, children: _screens),

            // Mini player
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayer(),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E202E), // davysGray
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: BottomNavigationBar(
                      currentIndex: _currentIndex,
                      onTap: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.home_outlined),
                          activeIcon: Icon(Icons.home),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.search_outlined),
                          activeIcon: Icon(Icons.search),
                          label: 'Search',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.library_music_outlined),
                          activeIcon: Icon(Icons.library_music),
                          label: 'Library',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
