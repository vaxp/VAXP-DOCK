import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../ui/launcher_home.dart';
import '../features/search/application/search_cubit.dart';
import '../features/search/data/repositories/search_repository.dart';

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
      home: BlocProvider(
        create: (context) => SearchCubit(SearchRepository()),
        child: const LauncherHome(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}


