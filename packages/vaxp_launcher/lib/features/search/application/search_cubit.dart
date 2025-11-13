import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vaxp_launcher/features/search/application/search_state.dart';
import 'package:vaxp_launcher/features/search/data/repositories/search_repository.dart';
import 'package:vaxp_launcher/features/search/domain/models/search_result.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._searchRepository) : super(const SearchState());

  final SearchRepository _searchRepository;

  void updateQuery(String query) {
    emit(state.copyWith(query: query));
  }

  void clearQuery() {
    emit(state.copyWith(query: ''));
  }

  Future<List<SearchResult>> performFileSearch(String term) async {
    emit(state.copyWith(isSearching: true));
    try {
      final results = await _searchRepository.searchFileSystem(term);
      emit(state.copyWith(isSearching: false));
      return results;
    } catch (e) {
      emit(state.copyWith(isSearching: false));
      rethrow;
    }
  }
}

