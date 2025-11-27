import 'package:flutter/material.dart';
import 'package:flutter_basic/core/configs/app_config.dart';
import 'package:flutter_basic/core/theme/app_theme.dart';
import 'package:flutter_basic/navigation/app_router.dart';
import 'package:flutter_basic/navigation/app_routes.dart';

import 'package:provider/provider.dart';
import 'package:english_words/english_words.dart';

class MyAppState extends ChangeNotifier {
  WordPair current = WordPair.random();

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }

  var favorites = <WordPair>[];

  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    notifyListeners();
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MyAppState>(
      create: (BuildContext context) => MyAppState(),
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: AppRoutes.shell,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}