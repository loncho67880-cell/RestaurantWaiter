import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:restaurantwaiter/core/utils/geo_utils.dart';
import 'package:restaurantwaiter/domain/models/branch.dart';
import 'package:restaurantwaiter/domain/repositories/branch_repository.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/auth_state.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/auth_navigation.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';
import 'package:restaurantwaiter/presentation/blocs/branch_selection/branch_selection_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/branch_selection/branch_selection_state.dart';

class BranchSelectionScreen extends StatelessWidget {
  const BranchSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appConfig = context.read<AppConfigCubit>().state;

    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated ||
        appConfig.restaurantId.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (authState is! AuthAuthenticated) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
          return;
        }
        Navigator.pushReplacementNamed(context, '/restaurant-select');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return BlocProvider(
      create: (_) => BranchSelectionCubit(
        branchRepository: context.read<BranchRepository>(),
        restaurantId: appConfig.restaurantId,
      )..load(),
      child: const _BranchSelectionView(),
    );
  }
}

class _BranchSelectionView extends StatefulWidget {
  const _BranchSelectionView();

  @override
  State<_BranchSelectionView> createState() => _BranchSelectionViewState();
}

class _BranchSelectionViewState extends State<_BranchSelectionView> {
  final MapController _mapController = MapController();
  bool _initialBranchSet = false;
  bool _mapReady = false;
  bool _mapVisible = false;
  LatLng? _userLocation;
  Future<LatLng?>? _userLocationFuture;
  Branch? _pendingBranchFocus;
  String? _lastFocusKey;
  int _focusRequestId = 0;
  LatLng? _pendingCenter;
  double _pendingZoom = 15;

  static const _tileUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
  static const _tileFallbackUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() => _mapVisible = true);
        final selected = context.read<BranchSelectionCubit>().state.selectedBranch;
        if (selected != null) {
          _lastFocusKey = null;
          _focusOnBranch(selected);
        }
      });
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    if (_pendingBranchFocus != null) {
      _focusOnBranch(_pendingBranchFocus!);
      return;
    }
    if (_pendingCenter != null) {
      final center = _pendingCenter!;
      final zoom = _pendingZoom;
      _pendingCenter = null;
      _scheduleMapMove(center, zoom: zoom);
      return;
    }

    final selected = context.read<BranchSelectionCubit>().state.selectedBranch;
    if (selected?.hasLocation == true) {
      _focusOnBranch(selected!);
    }
  }

  void _scheduleMapMove(LatLng center, {double zoom = 15}) {
    void move() {
      if (!mounted || !_mapReady) {
        _pendingCenter = center;
        _pendingZoom = zoom;
        return;
      }
      _mapController.move(center, zoom);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      move();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _mapReady) {
          _mapController.move(center, zoom);
        }
      });
    });
  }

  Future<LatLng?> _fetchUserLocation() {
    return _userLocationFuture ??= _fetchUserLocationImpl();
  }

  Future<LatLng?> _fetchUserLocationImpl() async {
    if (_userLocation != null) return _userLocation;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      if (!await Geolocator.isLocationServiceEnabled()) return null;

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _applyUserLocation(LatLng(lastKnown.latitude, lastKnown.longitude));
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      _applyUserLocation(LatLng(position.latitude, position.longitude));
      return _userLocation;
    } catch (_) {
      return _userLocation;
    }
  }

  void _applyUserLocation(LatLng latLng) {
    if (!mounted || _userLocation == latLng) return;
    setState(() {
      _userLocation = latLng;
      _lastFocusKey = null;
    });
    final selected = context.read<BranchSelectionCubit>().state.selectedBranch;
    if (selected != null) {
      _focusOnBranch(selected);
    }
  }

  void _focusOnBranch(Branch branch) {
    if (!branch.hasLocation) return;

    final branchPoint = LatLng(branch.latitude!, branch.longitude!);
    final focusKey =
        '${branch.id}|${_userLocation?.latitude}|${_userLocation?.longitude}';
    if (focusKey == _lastFocusKey) return;

    if (!_mapReady || !_mapVisible) {
      _pendingBranchFocus = branch;
      return;
    }
    _pendingBranchFocus = null;

    final requestId = ++_focusRequestId;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || !_mapReady || requestId != _focusRequestId) return;

      final size = MediaQuery.sizeOf(context);
      if (size.width < 1 || size.height < 1) return;

      _lastFocusKey = focusKey;

      if (_userLocation != null) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: [_userLocation!, branchPoint],
            padding: const EdgeInsets.fromLTRB(56, 72, 56, 48),
          ),
        );
      } else {
        _mapController.move(branchPoint, 14);
      }
    });
  }

  Future<void> _pickInitialBranch(List<Branch> branches) async {
    if (_initialBranchSet || branches.isEmpty) return;

    Branch? initial;

    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      final defaultId = authState.waiter.defaultBranchId?.trim();
      if (defaultId != null && defaultId.isNotEmpty) {
        for (final branch in branches) {
          if (branch.id == defaultId) {
            initial = branch;
            break;
          }
        }
      }
    }

    if (initial == null) {
      final userLatLng = await _fetchUserLocation();
      if (userLatLng != null) {
        initial = findClosestBranch(
          branches,
          latitude: userLatLng.latitude,
          longitude: userLatLng.longitude,
        );
      }
    }

    initial ??= firstBranchWithLocation(branches);
    if (initial == null || !mounted) return;

    _initialBranchSet = true;
    context.read<BranchSelectionCubit>().selectBranch(initial);
  }

  void _continue(BuildContext context, Branch branch) {
    navigateToHomeAfterBranch(context, branch);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: Text(
          t('selectBranchTitle'),
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: BlocConsumer<BranchSelectionCubit, BranchSelectionState>(
        listenWhen: (prev, curr) =>
            prev.branches != curr.branches ||
            prev.selectedBranch?.id != curr.selectedBranch?.id,
        listener: (context, state) {
          if (!_initialBranchSet && state.branches.isNotEmpty) {
            _pickInitialBranch(state.branches);
          }
          if (state.selectedBranch != null) {
            _focusOnBranch(state.selectedBranch!);
          }
        },
        builder: (context, state) {
          if (state.status == BranchSelectionStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == BranchSelectionStatus.error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      t('branchLoadError'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<BranchSelectionCubit>().load(),
                      child: Text(t('waiterRetry')),
                    ),
                  ],
                ),
              ),
            );
          }

          final mapBranches =
              state.branches.where((b) => b.hasLocation).toList();
          final selected = state.selectedBranch;
          final mapCenter = selected?.hasLocation == true
              ? LatLng(selected!.latitude!, selected.longitude!)
              : mapBranches.isNotEmpty
                  ? LatLng(
                      mapBranches.first.latitude!,
                      mapBranches.first.longitude!,
                    )
                  : const LatLng(5.068, -75.517);

          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _mapVisible
                          ? FlutterMap(
                              key: const ValueKey('branch-map'),
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: mapCenter,
                                initialZoom: 14,
                                onMapReady: _onMapReady,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: _tileUrlTemplate,
                                  fallbackUrl: _tileFallbackUrl,
                                  subdomains: const ['a', 'b', 'c', 'd'],
                                  userAgentPackageName:
                                      'com.example.restaurantwaiter',
                                  retinaMode: RetinaMode.isHighDensity(context),
                                  maxNativeZoom: 19,
                                ),
                                MarkerLayer(
                                  key: ValueKey(
                                    'markers-${_userLocation?.latitude}-'
                                    '${_userLocation?.longitude}-'
                                    '${selected?.id}',
                                  ),
                                  markers: [
                                    for (final branch in mapBranches)
                                      Marker(
                                        point: LatLng(
                                          branch.latitude!,
                                          branch.longitude!,
                                        ),
                                        width: 44,
                                        height: 44,
                                        child: GestureDetector(
                                          onTap: () => context
                                              .read<BranchSelectionCubit>()
                                              .selectBranch(branch),
                                          child: Icon(
                                            Icons.location_on_rounded,
                                            size: 40,
                                            color: state.selectedBranch?.id ==
                                                    branch.id
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ),
                                    if (_userLocation != null)
                                      Marker(
                                        key: const ValueKey('user-location'),
                                        point: _userLocation!,
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.blue
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.person_rounded,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            )
                          : ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Material(
                        elevation: 4,
                        color: theme.colorScheme.surface.withValues(alpha: 0.95),
                        child: SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final branch in state.branches) ...[
                                  if (branch != state.branches.first)
                                    const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: Text(
                                      branch.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: state.selectedBranch?.id ==
                                                branch.id
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    selected:
                                        state.selectedBranch?.id == branch.id,
                                    onSelected: (_) => context
                                        .read<BranchSelectionCubit>()
                                        .selectBranch(branch),
                                    selectedColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.2),
                                    labelStyle: TextStyle(
                                      color: state.selectedBranch?.id ==
                                              branch.id
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final drivingMinutes = drivingMinutesToBranch(
                            userLatitude: _userLocation?.latitude,
                            userLongitude: _userLocation?.longitude,
                            branch: selected,
                          );
                          final address =
                              '${selected.address}, ${selected.city}';
                          final drivingLabel = drivingMinutes != null
                              ? t(
                                  'branchDrivingTime',
                                  replacements: {
                                    '{minutes}': drivingMinutes.toString(),
                                  },
                                )
                              : null;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  text: address,
                                  children: [
                                    if (drivingLabel != null) ...[
                                      TextSpan(
                                        text: ' · $drivingLabel',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.85),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t(
                                  'branchOperatingHours',
                                  replacements: {
                                    '{hours}': selected.operatingHoursLabel,
                                  },
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: state.canContinue && selected != null
                        ? () => _continue(context, selected)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor:
                          theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    child: Text(
                      t('continueBtn'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
