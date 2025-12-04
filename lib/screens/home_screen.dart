import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/liked_songs_provider.dart';
import '../constants/app_colors.dart';
import '../widgets/typing_animation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, dynamic>> _changelog = [
    {
      'version': 'v2.0.0',
      'date': 'December 2025',
      'changes': [
        '✨ Full playlist feature with create, edit, and delete',
        '✨ Add/remove songs from playlists with visual feedback',
        '✨ Swipe to delete songs from playlists',
        '🎵 Dynamic playlist synchronization with audio player',
        '💾 Hive-based local storage for instant data access',
        '🔧 Fixed playlist persistence after app restart',
        '🎨 Updated app icon and splash screen with RUNNR logo',
        '🎯 Mini player now visible across all screens',
        '⚡ Optimized queue loading for instant playback',
      ],
    },
    {
      'version': 'v1.1.0',
      'date': 'October 2025',
      'changes': [
        'Fixed unlike button showing wrong song details',
        'Improved app performance by removing debug logs',
        'Enhanced splash screen logo visibility with black background',
        'Fixed previous button with 5-second threshold logic',
        'Optimized background color extraction in full player',
      ],
    },
    {
      'version': 'v1.0.0',
      'date': 'October 2025',
      'changes': [
        'Complete audio player with queue management',
        'Shuffle and repeat modes',
        'Background playback with notifications',
        'Like songs and create library',
        'Navigation controls (previous/next)',
        'Custom RUNNR color palette',
        'Smooth animations and UI polish',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    final likedSongsProvider = Provider.of<LikedSongsProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: Colors.black,
              floating: true,
              title: const Text(
                'RUNNR',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),

            // Greeting
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _getGreeting(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Made by bhvym - Typing Animation
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[900]!, Colors.blue[700]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: TypingAnimation(
                      texts: const [
                        'Hey there!',
                        'Fuck spotify',
                        'Enjoy',
                        'made by bhvym',
                      ],
                      textStyle: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                      typingSpeed: const Duration(milliseconds: 100),
                      deletingSpeed: const Duration(milliseconds: 50),
                      pauseDuration: const Duration(seconds: 2),
                    ),
                  ),
                ),
              ),
            ),

            // Changelog Section Header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Text(
                  'What\'s New',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Changelog Cards
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final versionInfo = _changelog[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Card(
                    color: AppColors.davysGray,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                versionInfo['version'],
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentColor,
                                ),
                              ),
                              Text(
                                versionInfo['date'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(
                            (versionInfo['changes'] as List).length,
                            (changeIndex) {
                              final change =
                                  versionInfo['changes'][changeIndex];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        change,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }, childCount: _changelog.length),
            ),

            // Bottom padding for mini player
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}
