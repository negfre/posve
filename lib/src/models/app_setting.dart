class AppSetting {
  final String key;
  final String value;

  AppSetting({required this.key, required this.value});

  // No necesitamos toMap/fromMap si solo lo usamos para leer/escribir 
  // directamente en DatabaseHelper, pero pueden ser útiles.

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
    };
  }

  factory AppSetting.fromMap(Map<String, dynamic> map) {
    return AppSetting(
      key: map['key'] as String,
      value: map['value'] as String,
    );
  }

  @override
  String toString() => 'AppSetting(key: $key, value: $value)';
} 