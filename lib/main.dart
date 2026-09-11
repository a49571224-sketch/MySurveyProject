import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const ElectricalSurveyApp());
}

class ElectricalSurveyApp extends StatelessWidget {
  const ElectricalSurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تطبيق مسح الشبكات أوفلاين',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: const MapHomePage(),
    );
  }
}

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  final MapController _mapController = MapController();
  
  LatLng _currentCenter = const LatLng(14.7978, 42.9545);
  final double _currentZoom = 15.0;

  final List<MapMarker> _markers = [
    MapMarker(
      point: const LatLng(14.7980, 42.9550),
      title: 'عمود كهرباء #101',
      type: 'pole',
    ),
    MapMarker(
      point: const LatLng(14.7965, 42.9530),
      title: 'طبلون عَدادات #402',
      type: 'panel',
    ),
  ];

  bool _showPoles = true;
  bool _showPanels = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentCenter = LatLng(position.latitude, position.longitude);
      _mapController.move(_currentCenter, _currentZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تطبيق مسح الشبكات (أوفلاين)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _determinePosition,
            tooltip: 'تحديد موقعي الحالي',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text('مهندس مسح الشبكات'),
              accountEmail: Text('الحديدة، اليمن'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.electrical_services, size: 40, color: Colors.blueGrey),
              ),
            ),
            SwitchListTile(
              title: const Text('عرض الأعمدة الكهربائية'),
              value: _showPoles,
              onChanged: (val) => setState(() => _showPoles = val),
            ),
            SwitchListTile(
              title: const Text('عرض طبلونات العدادات'),
              value: _showPanels,
              onChanged: (val) => setState(() => _showPanels = val),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_location_alt),
              title: const Text('إضافة نقطة جديدة'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('البيانات المحفوظة أوفلاين'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentCenter,
          initialZoom: _currentZoom,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'br.com.devoz.OZsurvey',
          ),
          MarkerLayer(
            markers: _markers.where((m) {
              if (m.type == 'pole' && !_showPoles) return false;
              if (m.type == 'panel' && !_showPanels) return false;
              return true;
            }).map((m) {
              return Marker(
                point: m.point,
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(m.title),
                        content: Text('الإحداثيات: ${m.point.latitude}, ${m.point.longitude}'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('إغلاق'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Icon(
                    m.type == 'pole' ? Icons.location_pin : Icons.account_balance_wallet,
                    color: m.type == 'pole' ? Colors.red : Colors.orange,
                    size: 35,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم النقر لإضافة عنصر ميداني جديد')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class MapMarker {
  final LatLng point;
  final String title;
  final String type;

  MapMarker({required this.point, required this.title, required this.type});
}
