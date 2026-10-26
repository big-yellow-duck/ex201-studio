class HelpBook {
  final Map<String, dynamic> data;
  const HelpBook(this.data);
  List<Map<String, dynamic>> list(String key) =>
      (data[key] as List).map((j) => Map<String, dynamic>.from(j)).toList();
  Map<String, dynamic> effect(int type) =>
      Map<String, dynamic>.from(data['effects']['$type'] ?? {});
  Map<String, dynamic> filter(int type) =>
      Map<String, dynamic>.from(data['filters'][type]);
  String field(int type, String key) {
    if (type == 5 && key == 'ratio') {
      return 'Higher expansion ratios push quiet material farther down. 1:1 leaves the dynamics unchanged.';
    }
    return data['fields'][key.replaceFirst(RegExp(r'_[0-3]$'), '')] ?? '';
  }
}
