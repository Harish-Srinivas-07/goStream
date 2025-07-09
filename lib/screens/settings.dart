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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isDarkMode = ThemeController.isDark;
      setState(() {});
    });
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

  Widget _infoRow(String label, String value, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.gabarito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.gabarito(
                fontSize: 14,
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
              // padding: const EdgeInsets.all(16),
              children: [
                // const SizedBox(height: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    Center(
                      child: Text(
                        packageInfo.appName,
                        style: GoogleFonts.gabarito(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                          letterSpacing: 1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'APP INFO',
                        style: GoogleFonts.gabarito(
                          fontSize: 12,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Divider(
                    //   thickness: 0.8,
                    //   color: scheme.outline.withOpacity(0.3),
                    // ),
                    const SizedBox(height: 12),

                    _infoRow(
                      'VERSION',
                      '${packageInfo.version} (${packageInfo.buildNumber})',
                      scheme,
                    ),
                    _infoRow('PACKAGE', packageInfo.packageName, scheme),
                    _infoRow(
                      'SIGNATURE',
                      packageInfo.buildSignature.isNotEmpty
                          ? packageInfo.buildSignature
                          : 'N/A',
                      scheme,
                    ),
                    _infoRow(
                      'INSTALLER',
                      packageInfo.installerStore ?? 'Unknown',
                      scheme,
                    ),
                    if (packageInfo.installTime != null)
                      _infoRow(
                        'INSTALLED ON',
                        packageInfo.installTime!
                            .toLocal()
                            .toString()
                            .split('.')
                            .first,
                        scheme,
                      ),
                    if (packageInfo.updateTime != null)
                      _infoRow(
                        'LAST UPDATE',
                        packageInfo.updateTime!
                            .toLocal()
                            .toString()
                            .split('.')
                            .first,
                        scheme,
                      ),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(),
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  // decoration: BoxDecoration(
                  //   borderRadius: BorderRadius.circular(12),
                  //   color: Theme.of(
                  //     context,
                  //   ).colorScheme.surfaceVariant.withOpacity(0.1),
                  // ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Appearance".toUpperCase(),
                        style: GoogleFonts.gabarito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeController.themeNotifier,
                        builder: (context, mode, _) {
                          final isDark = mode == ThemeMode.dark;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isDark ? Icons.dark_mode : Icons.light_mode,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Dark Mode',
                                    style: GoogleFonts.gabarito(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: isDark,
                                onChanged:
                                    (value) =>
                                        ThemeController.toggleTheme(value),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  // Optional: Uncomment this to give it a light background like Appearance
                  // decoration: BoxDecoration(
                  //   borderRadius: BorderRadius.circular(12),
                  //   color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.05),
                  // ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Having trouble with player?".toUpperCase(),
                        style: GoogleFonts.gabarito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _clearCacheAndPrefs,
                        child: Row(
                          children: [
                            Text(
                              'Clear Cache & Preferences',
                              style: GoogleFonts.gabarito(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.red,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(8),
                              // decoration: BoxDecoration(
                              //   color: Colors.red.withOpacity(0.1),
                              //   borderRadius: BorderRadius.circular(8),
                              // ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),

          Divider(
            color: Theme.of(context).colorScheme.outline,
            height: 1,
            thickness: 1,
          ),

          GestureDetector(
            onTap: () {
              launchUrl(
                Uri.parse('https://github.com/Harish-Srinivas-07/goStream'),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(top: 5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              // decoration: BoxDecoration(
              //   color: Colors.yellow.withAlpha(40),
              //   border: Border.all(color: Colors.yellow),
              //   borderRadius: BorderRadius.circular(12),
              // ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                // mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.orange),
                  SizedBox(width: 8),
                  Text.rich(
                    TextSpan(
                      text: 'Like this project? Star it on ',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: 'GitHub!',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
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
