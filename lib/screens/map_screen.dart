import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import '../widgets/location_marker.dart';
import '../widgets/route_painter.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool showCampusMap = true; // Toggle flag
  bool isFullscreen = false; // Fullscreen flag
  Offset? startPoint;
  Offset? endPoint;

  LocationData? _currentLocation;
  late MapController _mapController;
  List<LatLng> routePoints = []; // For route drawing
  LatLng draggableMarkerPosition = LatLng(11.0210, 77.0025); // Initial draggable marker position

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
  }

  void _getCurrentLocation() async {
    Location location = Location();

    bool _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) return;
    }

    PermissionStatus _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) return;
    }

    _currentLocation = await location.getLocation();
    setState(() {});
  }

  void _toggleFullscreenByGesture() {
    setState(() {
      isFullscreen = !isFullscreen;
    });
  }

  void _addGPSRoute() {
    if (_currentLocation == null) return;
    LatLng current = LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);
    LatLng destination = LatLng(11.0204, 77.0019); // Fixed college location

    // In real use, add polyline points from directions API
    setState(() {
      routePoints = [current, destination];
    });
  }

  Widget buildCampusMap() {
    return InteractiveViewer(
      maxScale: 5.0,
      child: Stack(
        children: [
          Image.asset('assets/images/ngp_campus_map.png'),
          CustomPaint(
            painter: (startPoint != null && endPoint != null)
                ? RoutePainter(start: startPoint!, end: endPoint!)
                : null,
            child: Container(),
          ),
          LocationMarker(
            left: 120,
            top: 150,
            onTap: () => _showLocationInfo(context, 'Block A', 'Computer Science Dept', Offset(120, 150)),
          ),
          LocationMarker(
            left: 180,
            top: 300,
            onTap: () => _showLocationInfo(context, 'Library', 'Main Library', Offset(180, 300)),
          ),
        ],
      ),
    );
  }

  Widget buildLiveMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: LatLng(11.0204, 77.0019),
        zoom: 15.0,
        maxZoom: 18.0,
        minZoom: 12.0,
        onTap: (_, __) => FocusScope.of(context).unfocus(),
        onPositionChanged: (pos, _) => setState(() {}),
      ),
      children: [
        TileLayer(
          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: ['a', 'b', 'c'],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(11.0204, 77.0019),
              builder: (ctx) => Icon(Icons.school, color: Colors.blue, size: 50),
            ),
            if (_currentLocation != null)
              Marker(
                point: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                builder: (ctx) => Icon(Icons.my_location, color: Colors.red, size: 40),
              ),
            Marker(
              point: draggableMarkerPosition,
              width: 80,
              height: 80,
              builder: (ctx) => GestureDetector(
                onPanUpdate: (details) {
                  final lat = draggableMarkerPosition.latitude + details.delta.dy * -0.0001;
                  final lng = draggableMarkerPosition.longitude + details.delta.dx * 0.0001;
                  setState(() {
                    draggableMarkerPosition = LatLng(lat, lng);
                  });
                },
                child: Icon(Icons.place, size: 40, color: Colors.orange),
              ),
            ),
          ],
        ),
        if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                strokeWidth: 5.0,
                color: Colors.purple,
              ),
            ],
          ),
      ],
    );
  }

  void _showLocationInfo(BuildContext context, String title, String description, Offset position) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                startPoint = Offset(50, 100); // Assume fixed user start
                endPoint = position;
              });
              Navigator.pop(context);
            },
            child: Text('Show Route'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(showCampusMap ? 'Campus Map View' : 'Live Map View'),
        backgroundColor: showCampusMap ? Colors.green : Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.swap_horiz),
            tooltip: 'Switch Map',
            onPressed: () {
              setState(() {
                showCampusMap = !showCampusMap;
              });
            },
          ),
          IconButton(
            icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: _toggleFullscreenByGesture,
          ),
        ],
      ),
      body: GestureDetector(
        onLongPress: _toggleFullscreenByGesture,
        child: showCampusMap ? buildCampusMap() : buildLiveMap(),
      ),
      floatingActionButton: showCampusMap
          ? null
          : Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "zoomIn",
            onPressed: () => _mapController.move(_mapController.center, _mapController.zoom + 1),
            child: Icon(Icons.zoom_in),
            backgroundColor: Colors.blue,
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "zoomOut",
            onPressed: () => _mapController.move(_mapController.center, _mapController.zoom - 1),
            child: Icon(Icons.zoom_out),
            backgroundColor: Colors.blue,
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "routeBtn",
            onPressed: _addGPSRoute,
            child: Icon(Icons.alt_route),
            backgroundColor: Colors.green,
            tooltip: 'Show Route to College',
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "qrScanBtn",
            onPressed: () {
              // Add QR scan logic here later
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('QR Scanner placeholder'),
              ));
            },
            child: Icon(Icons.qr_code_scanner),
            backgroundColor: Colors.deepPurple,
            tooltip: 'Scan QR Code',
          ),
        ],
      ),
    );
  }
}
