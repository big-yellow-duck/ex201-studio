import '../domain/models.dart';

abstract class BoardTransport {
  bool get connected;
  bool get isDemo;
  String? get address;
  String get name;
  Stream<bool> get connectionChanges;
  Future<List<DiscoveredBoard>> scan();
  Future<void> connect(String address);
  Future<List<int>> exchange(
    List<int> command, {
    int? selector,
    bool ack = false,
    Duration timeout = const Duration(seconds: 3),
  });
  Future<void> send(List<int> command);
  Future<void> close();
}
