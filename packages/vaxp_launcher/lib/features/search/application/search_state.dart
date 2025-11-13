import 'package:equatable/equatable.dart';

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.isSearching = false,
  });

  final String query;
  final bool isSearching;

  SearchState copyWith({
    String? query,
    bool? isSearching,
  }) {
    return SearchState(
      query: query ?? this.query,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  @override
  List<Object> get props => [query, isSearching];
}

