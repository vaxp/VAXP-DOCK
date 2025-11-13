enum SearchResultType { directory, application, archive, image, video, other }

class SearchResult {
  SearchResult({
    required this.path,
    required this.name,
    required this.type,
  });

  final String path;
  final String name;
  final SearchResultType type;
}

