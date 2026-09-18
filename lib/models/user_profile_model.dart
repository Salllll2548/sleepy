class UserProfile {
  final String name;
  final bool faceVerified;
  final bool bluetoothConnected;
  final bool alarmThroughCarSpeaker;
  final bool systemNotificationsOn;
  final bool nightDrivingMode;

  const UserProfile({
    required this.name,
    this.faceVerified = false,
    this.bluetoothConnected = false,
    this.alarmThroughCarSpeaker = true,
    this.systemNotificationsOn = true,
    this.nightDrivingMode = false,
  });

  UserProfile copyWith({
    bool? faceVerified,
    bool? bluetoothConnected,
    bool? alarmThroughCarSpeaker,
    bool? systemNotificationsOn,
    bool? nightDrivingMode,
  }) {
    return UserProfile(
      name: name,
      faceVerified: faceVerified ?? this.faceVerified,
      bluetoothConnected: bluetoothConnected ?? this.bluetoothConnected,
      alarmThroughCarSpeaker:
          alarmThroughCarSpeaker ?? this.alarmThroughCarSpeaker,
      systemNotificationsOn:
          systemNotificationsOn ?? this.systemNotificationsOn,
      nightDrivingMode: nightDrivingMode ?? this.nightDrivingMode,
    );
  }
}
