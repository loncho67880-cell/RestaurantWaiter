import 'dart:math';

import 'package:restaurantwaiter/domain/models/branch.dart';

double haversineDistanceKm(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusKm = 6371.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _toRadians(double degrees) => degrees * pi / 180;

Branch? findClosestBranch(
  List<Branch> branches, {
  required double latitude,
  required double longitude,
}) {
  Branch? closest;
  var minDistance = double.infinity;

  for (final branch in branches) {
    if (!branch.hasLocation) continue;
    final distance = haversineDistanceKm(
      latitude,
      longitude,
      branch.latitude!,
      branch.longitude!,
    );
    if (distance < minDistance) {
      minDistance = distance;
      closest = branch;
    }
  }

  return closest;
}

Branch? firstBranchWithLocation(List<Branch> branches) {
  for (final branch in branches) {
    if (branch.hasLocation) return branch;
  }
  return branches.isNotEmpty ? branches.first : null;
}

int estimateDrivingMinutes(double straightLineKm) {
  const roadFactor = 1.35;
  const avgSpeedKmh = 35.0;
  final roadKm = straightLineKm * roadFactor;
  final minutes = (roadKm / avgSpeedKmh * 60).round();
  return minutes < 1 ? 1 : minutes;
}

int? drivingMinutesToBranch({
  required double? userLatitude,
  required double? userLongitude,
  required Branch branch,
}) {
  if (userLatitude == null ||
      userLongitude == null ||
      !branch.hasLocation) {
    return null;
  }
  final km = haversineDistanceKm(
    userLatitude,
    userLongitude,
    branch.latitude!,
    branch.longitude!,
  );
  return estimateDrivingMinutes(km);
}
