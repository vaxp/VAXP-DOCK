/// Enum representing the different view modes for displaying apps
enum ViewMode {
  /// Grid view with continuous scrolling (default)
  grid,

  /// Paged view with page indicators
  paged,
}

extension ViewModeExtension on ViewMode {
  /// Convert ViewMode to string for storage
  String toStorageString() {
    switch (this) {
      case ViewMode.grid:
        return 'grid';
      case ViewMode.paged:
        return 'paged';
    }
  }

  /// Create ViewMode from string
  static ViewMode fromString(String value) {
    switch (value) {
      case 'paged':
        return ViewMode.paged;
      case 'grid':
      default:
        return ViewMode.grid;
    }
  }
}
