class License {
  final String deviceId;
  final String activationToken;
  final String licenseKey;
  final DateTime? activatedAt;
  final bool isActive;
  final String? deviceInfo;

  License({
    required this.deviceId,
    required this.activationToken,
    required this.licenseKey,
    this.activatedAt,
    required this.isActive,
    this.deviceInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'activation_token': activationToken,
      'license_key': licenseKey,
      'activated_at': activatedAt?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'device_info': deviceInfo,
    };
  }

  factory License.fromMap(Map<String, dynamic> map) {
    return License(
      deviceId: map['device_id'],
      activationToken: map['activation_token'],
      licenseKey: map['license_key'],
      activatedAt: map['activated_at'] != null ? DateTime.parse(map['activated_at']) : null,
      isActive: map['is_active'] == 1,
      deviceInfo: map['device_info'],
    );
  }
} 