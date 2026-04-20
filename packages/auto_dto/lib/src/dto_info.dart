class DtoInfo {
  final String name;
  final List<FieldInfo> fields;

  DtoInfo({required this.name, required this.fields});
}

class FieldInfo {
  final String name;
  final String type;

  FieldInfo({required this.name, required this.type});
}
