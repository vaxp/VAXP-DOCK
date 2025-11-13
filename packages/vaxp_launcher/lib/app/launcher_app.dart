import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../ui/launcher_home.dart';
import '../features/search/application/search_cubit.dart';
import '../features/search/data/repositories/search_repository.dart';
import '../features/settings/application/settings_cubit.dart';
import '../features/settings/data/repositories/settings_repository.dart';

class LauncherApp extends StatelessWidget {
  const LauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAXP Launcher',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(125, 0, 170, 255),
          brightness: Brightness.dark,
        ),
      ),
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => SearchCubit(SearchRepository()),
          ),
          BlocProvider(
            create: (context) => SettingsCubit(SettingsRepository()),
          ),
        ],
        child: const LauncherHome(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}


