import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluster/fluster.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'utils/map_marker.dart';
import 'utils/map_helper.dart';

import '../widgets/text_styles.dart';
import '../data/icon_loader.dart';
import '../data/marker_loader.dart';


class GoogleMapWidget extends StatefulWidget {
  @override
  _GoogleMapWidgetState createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {

  final Completer<GoogleMapController> _mapController = Completer();

  /// Set of displayed markers and cluster markers on the map
  final Set<Marker> _markers = Set();

  /// Minimum zoom at which the markers will cluster
  final int _minClusterZoom = 0;

  /// Maximum zoom at which the markers will cluster
  final int _maxClusterZoom = 19;

  /// [Fluster] instance used to manage the clusters
  Fluster<MapMarker> _clusterManager;

  /// Current map zoom. Initial zoom will be 15, street level
  double _currentZoom = 15;

  /// Map loading flag
  bool _isMapLoading = true;

  /// Markers loading flag
  bool _areMarkersLoading = true;

  /// Init [Fluster] and all the markers with network images and updates the loading state.
  void _initMarkers() async {
    final List<MapMarker> markers = [];

    MarkerLoader _markerLoader = MarkerLoader();
    _markerLoader.init();
    final List<Map> _tempMarkers = _markerLoader.getList();

    final IconLoader _iconLoader = IconLoader();

    for (Map markerMap in _tempMarkers) {
      final BitmapDescriptor markerImage =
          await MapHelper.getMarkerImageFromUrl(
              _iconLoader.dictionaryLocal[markerMap['icon']]
          );

      markers.add(
        MapMarker(
          id: _tempMarkers.indexOf(markerMap).toString(),
          position: markerMap['position'],
          icon: markerImage,
        ),
      );
    }

    _clusterManager = await MapHelper.initClusterManager(
      markers,
      _minClusterZoom,
      _maxClusterZoom,
      _iconLoader.dictionaryLocal['pointer_place'],
    );

    _updateMarkers();
  }

  // ===========================================================================
  // -------------------- GOOGLE MAPS WIDGET SECTION ---------------------------

  /// Called when the Google Map widget is created. Updates the map loading state
  /// and inits the markers.
  void _onMapCreated(GoogleMapController controller) {
    _mapController.complete(controller);

    setState(() {
      _isMapLoading = false;
    });

    _initMarkers();
  }

  /// Gets the markers and clusters to be displayed on the map for the current zoom level and
  /// updates state.
  void _updateMarkers([double updatedZoom]) {
    if (_clusterManager == null || updatedZoom == _currentZoom) return;

    if (updatedZoom != null) {
      _currentZoom = updatedZoom;
    }

    setState(() {
      _areMarkersLoading = true;
    });

    _markers
      ..clear()
      ..addAll(MapHelper.getClusterMarkers(_clusterManager, _currentZoom));

    setState(() {
      _areMarkersLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // Google Map widget
        Opacity(
          opacity: _isMapLoading ? 0 : 1,
          child: GoogleMap(
            mapToolbarEnabled: false,
            initialCameraPosition: CameraPosition(
              target: LatLng(41.143029, -8.611274),
              zoom: _currentZoom,
            ),
            markers: _markers,
            onMapCreated: (controller) => _onMapCreated(controller),
            onCameraMove: (position) => _updateMarkers(position.zoom),
          ),
        ),

        // Map loading indicator
        Opacity(
          opacity: _isMapLoading ? 1 : 0,
          child: Center(child: CircularProgressIndicator()),
        ),

        // Map markers loading indicator
        if (_areMarkersLoading)
          textInfo('Loading')
      ],
    );
  }
}