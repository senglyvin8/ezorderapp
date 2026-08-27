import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(
    ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const RestaurantApp(),
    ),
  );
}
