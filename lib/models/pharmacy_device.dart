class PharmacyDevice {
  PharmacyDevice({
    required this.id,
    required this.hardwareUid,
    required this.deviceName,
    required this.deviceModel,
    required this.deviceDisplayName,
    required this.lastLoginAt,
    required this.isActiveSeller,
    this.activatedAt,
    required this.isCurrentDevice,
  });

  final String id;
  final String hardwareUid;
  final String? deviceName;
  final String? deviceModel;
  final String deviceDisplayName;
  final String? lastLoginAt;
  final bool isActiveSeller;
  final String? activatedAt;
  final bool isCurrentDevice;

  factory PharmacyDevice.fromJson(Map<String, dynamic> json) {
    return PharmacyDevice(
      id: (json['id'] ?? '').toString(),
      hardwareUid: (json['hardware_uid'] ?? '').toString(),
      deviceName: json['device_name']?.toString(),
      deviceModel: json['device_model']?.toString(),
      deviceDisplayName:
          (json['device_display_name'] ?? json['device_name'] ?? 'POS Device')
              .toString(),
      lastLoginAt: json['last_login_at']?.toString(),
      isActiveSeller: json['is_active_seller'] == true,
      activatedAt: json['activated_at']?.toString(),
      isCurrentDevice: json['is_current_device'] == true,
    );
  }
}
