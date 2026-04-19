import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/nearby_bookstore.dart';
import '../../services/places_service.dart';
import '../../utils/geolocation_helper.dart';
import '../../widgets/constrained_content.dart';

class NearbyBookstoresPage extends StatefulWidget {
  const NearbyBookstoresPage({super.key});

  @override
  State<NearbyBookstoresPage> createState() => _NearbyBookstoresPageState();
}

class _NearbyBookstoresPageState extends State<NearbyBookstoresPage> {
  final PlacesService _placesService = PlacesService();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<NearbyBookstore> _bookstores = [];
  LatLng? _userPosition;
  GoogleMapController? _mapController;
  int? _selectedIndex;
  String? _nextPageToken;

  @override
  void initState() {
    super.initState();
    _loadBookstores();
  }

  Future<void> _loadBookstores() async {
    final position = await GeolocationHelper.getCurrentPosition(
      onError: (message) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        String text;
        switch (message) {
          case 'enableLocationSettings':
            text = l10n.enableLocationSettings;
          case 'locationAccessRequired':
            text = l10n.locationAccessRequired;
          default:
            text = l10n.locationAccessRequired;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text)),
        );
      },
    );

    if (position == null) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    final userLatLng = LatLng(position.latitude, position.longitude);
    setState(() => _userPosition = userLatLng);

    if (!mounted) return;
    final locale = Localizations.localeOf(context).languageCode;
    final result = await _placesService.searchNearbyBookstores(
      latitude: position.latitude,
      longitude: position.longitude,
      languageCode: locale,
    );

    if (!mounted) return;
    setState(() {
      _bookstores = result.bookstores;
      _nextPageToken = result.nextPageToken;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextPageToken == null || _userPosition == null) {
      return;
    }

    setState(() => _isLoadingMore = true);

    final locale = Localizations.localeOf(context).languageCode;
    final result = await _placesService.searchNearbyBookstores(
      latitude: _userPosition!.latitude,
      longitude: _userPosition!.longitude,
      languageCode: locale,
      pageToken: _nextPageToken,
    );

    if (!mounted) return;

    // Dédupliquer par coordonnées pour éviter les doublons
    final existingKeys = _bookstores
        .map((b) => '${b.latitude},${b.longitude}')
        .toSet();

    final newBookstores = result.bookstores
        .where((b) => !existingKeys.contains('${b.latitude},${b.longitude}'))
        .toList();

    setState(() {
      _bookstores = [..._bookstores, ...newBookstores]
        ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      _nextPageToken = result.nextPageToken;
      _isLoadingMore = false;
    });
  }

  Set<Marker> _buildMarkers() {
    return _bookstores.asMap().entries.map((entry) {
      final index = entry.key;
      final store = entry.value;
      return Marker(
        markerId: MarkerId('bookstore_$index'),
        position: LatLng(store.latitude, store.longitude),
        infoWindow: InfoWindow(
          title: store.name,
          snippet: store.formattedDistance,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _selectedIndex == index
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueOrange,
        ),
        onTap: () => _selectBookstore(index),
      );
    }).toSet();
  }

  void _selectBookstore(int index) {
    setState(() => _selectedIndex = index);
    final store = _bookstores[index];
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(store.latitude, store.longitude),
        16,
      ),
    );
  }

  Future<void> _navigateToBookstore(NearbyBookstore store) async {
    final url = store.googleMapsUri ??
        'https://www.google.com/maps/dir/?api=1&destination=${store.latitude},${store.longitude}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.nearbyBookstores)),
      body: ConstrainedContent(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(l10n.searchingBookstores),
                  ],
                ),
              )
            : Column(
                children: [
                  // Map
                  SizedBox(
                    height: 300,
                    child: _userPosition != null
                        ? GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _userPosition!,
                              zoom: 14,
                            ),
                            markers: _buildMarkers(),
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            zoomControlsEnabled: false,
                            onMapCreated: (controller) {
                              _mapController = controller;
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                  // List
                  Expanded(
                    child: _bookstores.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                l10n.noBookstoresFound,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _bookstores.length +
                                (_nextPageToken != null ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              // Bouton "Voir plus" en dernier élément
                              if (index == _bookstores.length) {
                                return _buildLoadMoreButton(l10n, theme);
                              }

                              final store = _bookstores[index];
                              final isSelected = _selectedIndex == index;

                              return ListTile(
                                selected: isSelected,
                                leading: CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    color:
                                        theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                title: Text(
                                  store.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      store.address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          store.formattedDistance,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (store.rating != null) ...[
                                          const SizedBox(width: 12),
                                          Icon(
                                            Icons.star_rounded,
                                            size: 16,
                                            color: Colors.amber.shade700,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            store.rating!
                                                .toStringAsFixed(1),
                                            style:
                                                theme.textTheme.bodySmall,
                                          ),
                                        ],
                                        if (store.isOpenNow != null) ...[
                                          const SizedBox(width: 12),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: store.isOpenNow!
                                                  ? Colors.green.shade50
                                                  : Colors.red.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              store.isOpenNow!
                                                  ? l10n.openNow
                                                  : l10n.closed,
                                              style: theme
                                                  .textTheme.labelSmall
                                                  ?.copyWith(
                                                color: store.isOpenNow!
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon:
                                      const Icon(Icons.directions_rounded),
                                  tooltip: l10n.navigate,
                                  onPressed: () =>
                                      _navigateToBookstore(store),
                                ),
                                onTap: () => _selectBookstore(index),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoadMoreButton(AppLocalizations l10n, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: _isLoadingMore
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: _loadMore,
              icon: const Icon(Icons.expand_more_rounded),
              label: Text(l10n.loadMoreBookstores),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
