class SystemStats {
  final double cpuUsage;
  final double memoryUsage;
  final double totalMemory;
  final double networkUpload;
  final double networkDownload;
  final double diskRead;
  final double diskWrite;

  SystemStats({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.totalMemory,
    required this.networkUpload,
    required this.networkDownload,
    required this.diskRead,
    required this.diskWrite,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemStats &&
          runtimeType == other.runtimeType &&
          cpuUsage == other.cpuUsage &&
          memoryUsage == other.memoryUsage &&
          totalMemory == other.totalMemory &&
          networkUpload == other.networkUpload &&
          networkDownload == other.networkDownload &&
          diskRead == other.diskRead &&
          diskWrite == other.diskWrite;

  @override
  int get hashCode =>
      cpuUsage.hashCode ^
      memoryUsage.hashCode ^
      totalMemory.hashCode ^
      networkUpload.hashCode ^
      networkDownload.hashCode ^
      diskRead.hashCode ^
      diskWrite.hashCode;
}