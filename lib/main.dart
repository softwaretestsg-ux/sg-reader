import 'package:flutter/material.dart';
import 'constants/branding.dart';
import 'constants/theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SGReaderApp());
}

class SGReaderApp extends StatelessWidget {
  const SGReaderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: BrandConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: SGTheme.themeData,
      home: const SplashScreen(),
    );
  }
}
