import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:vaxp_launcher/features/search/domain/models/search_result.dart';

class SearchRepository {
  static const int _fileSearchMaxDepth = 4;
  static const int _fileSearchMaxResults = 50;
  static const Set<String> _fileSearchExcludedDirectoryNames = {
    'desktop',
    'home',
    '.cache',
    '.config',
    '.local',
    '.npm',
    '.cargo',
    '.dart_tool',
    '.idea',
    '.venv',
    '__pycache__',
    'build',
    'dist',
    'node_modules',
    'target',
    'vendor',
  };
  static const Set<String> _archiveExtensions = {
    '.zip',
    '.tar',
    '.tar.gz',
    '.tar.bz2',
    '.tar.xz',
    '.tgz',
    '.tbz',
    '.tbz2',
    '.txz',
    '.gz',
    '.bz2',
    '.xz',
    '.7z',
    '.rar',
  };
  static const Set<String> _imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.bmp',
    '.svg',
    '.webp',
    '.tiff',
    '.ico',
  };
  static const Set<String> _videoExtensions = {
    '.mp4',
    '.mkv',
    '.mov',
    '.avi',
    '.webm',
    '.flv',
    '.wmv',
    '.mpeg',
    '.mpg',
  };
  static const Set<String> _applicationExtensions = {
    '.desktop',
    '.appimage',
    '.sh',
    '.run',
    '.bin',
    '.deb',
    '.rpm',
    '.flatpakref',
    '.flatpakrepo',
  };

  Future<List<SearchResult>> searchFileSystem(String term) async {
    final query = term.toLowerCase();
    if (query.isEmpty) {
      return [];
    }

    final matches = <SearchResult>[];
    final visited = <String>{};
    final queue = Queue<MapEntry<Directory, int>>();

    final homePath = Platform.environment['HOME'] ?? Directory.current.path;
    final roots = <String>{
      homePath,
      '$homePath/Desktop',
      '$homePath/.local/share/applications',
      '/usr/share/applications',
      '/usr/local/share/applications',
    };

    for (final path in roots) {
      final dir = Directory(path);
      if (await dir.exists() && visited.add(dir.path)) {
        queue.add(MapEntry(dir, 0));
      }
    }

    while (queue.isNotEmpty && matches.length < _fileSearchMaxResults) {
      final entry = queue.removeFirst();
      final dir = entry.key;
      final depth = entry.value;

      if (depth > _fileSearchMaxDepth) {
        continue;
      }

      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (matches.length >= _fileSearchMaxResults) break;
          final path = entity.path;
          final segments = path.split(Platform.pathSeparator);
          final name = segments.isNotEmpty ? segments.last : path;
          final lowerName = name.toLowerCase();

          final type = await _classifySearchEntity(entity, lowerName);

          if (lowerName.contains(query)) {
            matches.add(SearchResult(path: path, name: name, type: type));
          }

          if (type == SearchResultType.directory) {
            final shouldTraverse =
                depth < _fileSearchMaxDepth - 1 &&
                    !_fileSearchExcludedDirectoryNames.contains(lowerName);
            if (shouldTraverse && visited.add(path)) {
              queue.add(MapEntry(Directory(path), depth + 1));
            }
          }
        }
      } catch (_) {
        // Skip directories we can't read
      }
    }

    matches.sort((a, b) {
      final typeCompare = a.type.index.compareTo(b.type.index);
      if (typeCompare != 0) return typeCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return matches;
  }

  Future<SearchResultType> _classifySearchEntity(
    FileSystemEntity entity,
    String lowerName,
  ) async {
    if (entity is Directory) return SearchResultType.directory;

    if (_applicationExtensions.any((ext) => lowerName.endsWith(ext))) {
      return SearchResultType.application;
    }

    if (_archiveExtensions.any((ext) => lowerName.endsWith(ext))) {
      return SearchResultType.archive;
    }

    if (_imageExtensions.any((ext) => lowerName.endsWith(ext))) {
      return SearchResultType.image;
    }

    if (_videoExtensions.any((ext) => lowerName.endsWith(ext))) {
      return SearchResultType.video;
    }

    try {
      final stat = await entity.stat();
      if (stat.modeString().startsWith('d')) {
        return SearchResultType.directory;
      }
    } catch (_) {}

    return SearchResultType.other;
  }
}

