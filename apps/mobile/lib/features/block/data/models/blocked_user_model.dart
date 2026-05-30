import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/blocked_user.dart';
import 'timestamp_converter.dart';

part 'blocked_user_model.freezed.dart';
part 'blocked_user_model.g.dart';

@freezed
abstract class BlockedUserModel with _$BlockedUserModel {
  const factory BlockedUserModel({
    required String blockedUid,
    String? displayName,
    @TimestampConverter() required DateTime blockedAt,
  }) = _BlockedUserModel;

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) =>
      _$BlockedUserModelFromJson(json);
}

extension BlockedUserModelX on BlockedUserModel {
  BlockedUser toEntity() => BlockedUser(
    uid: blockedUid,
    displayName: displayName,
    blockedAt: blockedAt,
  );
}
