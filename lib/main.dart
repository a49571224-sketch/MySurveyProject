import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const ElectricalSurveyApp());
}

class ElectricalSurveyApp extends StatelessWidget {
  const ElectricalSurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تطبيق مسح الشبكات الميداني',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: const MapHomePage(),
    );
  }
}

class SurveyMarker {
  final String id;
  final LatLng point;
  String title;
  String type; // 'pole' أو 'panel'
  String notes;
  String? imagePath;

  SurveyMarker({
    required this.id,
    required this.point,
    required this.title,
    required this.type,
    this.notes = '',
    this.imagePath,
  });
}

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  final MapController _mapController = MapController();
  
  LatLng _currentCenter = const LatLng(14.7979, 42.9545);
  final double _currentZoom = 15.0;

  final List<SurveyMarker> _markers = [];
  bool _showPoles = true;
  bool _showPanels = true;
  final ImagePicker _picker = ImagePicker();

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

  void _showMarkerDialog({SurveyMarker? existingMarker, LatLng? tappedPoint}) {
    String title = existingMarker?.title ?? 'عنصر جديد';
    String type = existingMarker?.type ?? 'pole';
    String notes = existingMarker?.notes ?? '';
    String? imagePath = existingMarker?.imagePath;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingMarker == null ? 'إضافة نقطة ميدانية جديدة' : 'تعديل أو حذف العنصر'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'اسم العنصر أو رقمه'),
                      controller: TextEditingController(text: title),
                      onChanged: (val) => title = val,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'نوع العنصر'),
                      items: const [
                        DropdownMenuItem(value: 'pole', child: Text('عمود كهرباء')),
                        DropdownMenuItem(value: 'panel', child: Text('طبلون عدادات')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => type = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(labelText: 'ملاحظات ميدانية'),
                      controller: TextEditingController(text: notes),
                      onChanged: (val) => notes = val,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    if (imagePath != null)
                      Image.file(File(imagePath!), height: 100, width: 100, fit: BoxFit.cover),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                        if (image != null) {
                          setDialogState(() {
                            imagePath = image.path;
                          });
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('التقاط صورة'),
                    ),
                  ],
                ),
              ),
              actions: [
                if (existingMarker != null)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () {
                      setState(() {
                        _markers.removeWhere((m) => m.id == existingMarker.id);
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('حذف العنصر'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (existingMarker == null && tappedPoint != null) {
                        _markers.add(SurveyMarker(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          point: tappedPoint,
                          title: title,
                          type: type,
                          notes: notes,
                          imagePath: imagePath,
                        ));
                      } else if (existingMarker != null) {
                        existingMarker.title = title;
                        existingMarker.type = type;
                        existingMarker.notes = notes;
                        existingMarker.imagePath = imagePath;
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تطبيق مسح الشبكات الميداني'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _determinePosition,
            tooltip: 'موقعي الحالي',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text('مهندس المسح الميداني'),
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
          ],
        ),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentCenter,
          initialZoom: _currentZoom,
          onTap: (tapPosition, point) {
            _showMarkerDialog(tappedPoint: point);
          },
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
                  onTap: () => _showMarkerDialog(existingMarker: m),
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
    );
  }
}
