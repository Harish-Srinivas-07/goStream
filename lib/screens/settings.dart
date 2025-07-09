import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/constants.dart';
import '../utils/theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    isDarkMode = ThemeController.isDark;
  }

  Future<void> _clearCacheAndPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Clear SharedPreferences
    await prefs.clear();

    // Clear in-memory global variables
    favouriteMovieIds.clear();
    topMovies.clear();
    recentWatchIds.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          'Cache and preferences cleared.',
          style: GoogleFonts.gabarito(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        duration: Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  void _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text('', style: GoogleFonts.gabarito()),
        backgroundColor: scheme.surface,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      packageInfo.appName,
                      style: GoogleFonts.gabarito(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version: ${packageInfo.version} (${packageInfo.buildNumber})',
                      style: GoogleFonts.gabarito(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Package: ${packageInfo.packageName}',
                      style: GoogleFonts.gabarito(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Signature: ${packageInfo.buildSignature.isNotEmpty ? packageInfo.buildSignature : 'N/A'}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.gabarito(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Installed via: ${packageInfo.installerStore ?? 'Unknown'}',
                      style: GoogleFonts.gabarito(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (packageInfo.installTime != null)
                      Text(
                        'Install time: ${packageInfo.installTime!.toLocal()}',
                        style: GoogleFonts.gabarito(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (packageInfo.updateTime != null)
                      Text(
                        'Last update: ${packageInfo.updateTime!.toLocal()}',
                        style: GoogleFonts.gabarito(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 24),

                // Settings UI continues...
                Text(
                  "Appearance".toUpperCase(),
                  style: GoogleFonts.gabarito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.themeNotifier,
                  builder: (context, mode, _) {
                    final isDark = mode == ThemeMode.dark;
                    return SwitchListTile(
                      value: isDark,
                      onChanged: (value) {
                        ThemeController.toggleTheme(value);
                      },
                      title: const Text('Dark Mode'),
                    );
                  },
                ),

                const SizedBox(height: 20),
                Text(
                  "Having trouble with Player?".toUpperCase(),
                  style: GoogleFonts.gabarito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    'Clear Cache & Preferences',
                    style: GoogleFonts.gabarito(color: Colors.red),
                  ),
                  onTap: _clearCacheAndPrefs,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.only(top: 15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            // decoration: BoxDecoration(
            //   color: Colors.yellow.withAlpha(40),
            //   border: Border.all(color: Colors.yellow),
            //   borderRadius: BorderRadius.circular(12),
            // ),
            child: GestureDetector(
              onTap: () {
                launchUrl(
                  Uri.parse('https://github.com/Harish-Srinivas-07/goStream'),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                // mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Like this project? Star it on GitHub! ',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "Note: This app is a simple experimental demonstration using IMDb web scraping and the vidsrc streaming endpoint. "
              "It explores non-protected content delivery mechanisms purely for educational purposes. "
              "I do not own or host any of the content shown by IMDb or vidsrc. I'm only the developer showcasing a proof-of-concept.",
              style: GoogleFonts.gabarito(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Thanks to IMDb & Vidsrc for content source.',
                    style: GoogleFonts.gabarito(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset('assets/imdb.svg', height: 24),
                    const SizedBox(width: 8),
                    SvgPicture.asset(
                      'assets/vidsrc.svg',
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
