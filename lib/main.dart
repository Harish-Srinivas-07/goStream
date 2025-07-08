import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'screens/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightScheme =
            lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.deepPurple);
        final ColorScheme darkScheme =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          home: const Home(),
        );
      },
    );
  }
}
