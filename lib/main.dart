import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const ElectricalSurveyApp());
}

class ElectricalSurveyApp extends StatelessWidget {
  const ElectricalSurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OZsurvey',
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
  String type; // 'common', 'csp', 'hub'
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
  
  LatLng _currentCenter = const LatLng(15.3694, 44.1910); // إحداثيات صنعاء الافتراضية
  final double _currentZoom = 14.0;

  final List<SurveyMarker> _markers = [];
  String _selectedTool = 'common'; // الأدوات: common, csp, hub
  bool _showMarkers = true;
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  Future<void> _exportToCSV() async {
    if (_markers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات لتصديرها بعد!')),
      );
      return;
    }

    try {
      StringBuffer csvContent = StringBuffer();
      csvContent.writeln('ID,Title,Type,Latitude,Longitude,Notes');

      for (var m in _markers) {
        csvContent.writeln('${m.id},"${m.title}",${m.type},${m.point.latitude},${m.point.longitude},"${m.notes}"');
      }

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/ozsurvey_data.csv';
      final file = File(path);
      await file.writeAsString(csvContent.toString());

      await Share.shareXFiles([XFile(path)], text: 'تقرير مسح الشبكة الكهربائية');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')),
      );
    }
  }

  void _showMarkerDialog({SurveyMarker? existingMarker, LatLng? tappedPoint}) {
    String title = existingMarker?.title ?? (_selectedTool.toUpperCase() + ' جديد');
    String type = existingMarker?.type ?? _selectedTool;
    String notes = existingMarker?.notes ?? '';
    String? imagePath = existingMarker?.imagePath;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingMarker == null ? 'إضافة نقطة [$type]' : 'تعديل أو حذف العنصر'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'اسم أو رقم العنصر'),
                      controller: TextEditingController(text: title),
                      onChanged: (val) => title = val,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'نوع العنصر'),
                      items: const [
                        DropdownMenuItem(value: 'common', child: Text('Common (عمود عادي)')),
                        DropdownMenuItem(value: 'csp', child: Text('CSP')),
                        DropdownMenuItem(value: 'hub', child: Text('HUB (طبلون/موزع)')),
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

  IconData _getIconForType(String type) {
    switch (type) {
      case 'csp':
        case Icons.storage;
        return Icons.settings_input_component;
      case 'hub':
        return Icons.account_balance_wallet;
      default:
        return Icons.location_pin;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'csp':
        return Colors.blue;
      case 'hub':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text('مهندس المسح الميداني'),
              accountEmail: Text('OZsurvey - نظام الخرائط'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.map, size: 40, color: Colors.blueGrey),
              ),
            ),
            SwitchListTile(
              title: const Text('عرض جميع العلامات على الخريطة'),
              value: _showMarkers,
              onChanged: (val) => setState(() => _showMarkers = val),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.green),
              title: const Text('تصدير البيانات إلى CSV'),
              onTap: () {
                Navigator.pop(context);
                _exportToCSV();
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 1. الخريطة الأساسية
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: _currentZoom,
              onTap: (tapPosition, point) {
                // النقر على الخريطة يضيف العنصر المحدد حالياً مباشرة
                _showMarkerDialog(tappedPoint: point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ozmap.survey',
              ),
              if (_showMarkers)
                MarkerLayer(
                  markers: _markers.map((m) {
                    return Marker(
                      point: m.point,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showMarkerDialog(existingMarker: m),
                        child: Icon(
                          _getIconForType(m.type),
                          color: _getColorForType(m.type),
                          size: 38,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          // 2. الشريط العلوي (OZsurvey Header)
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Container(
              height: 55,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.black87),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const Text(
                    'OZsurvey',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.location_on, color: Colors.green, size: 20),
                      SizedBox(width: 4),
                      Text('OZmap', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  )
                ],
              ),
            ),
          ),

          // 3. شريط الأدوات الجانبي الأيسر (اختيار نوع العنصر السريع)
          Positioned(
            top: 110,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.location_pin),
                    color: _selectedTool == 'common' ? Colors.red : Colors.grey,
                    onPressed: () => setState(() => _selectedTool = 'common'),
                    tooltip: 'Common',
                  ),
                  const Divider(height: 1),
                  IconButton(
                    icon: const Icon(Icons.settings_input_component),
                    color: _selectedTool == 'csp' ? Colors.blue : Colors.grey,
                    onPressed: () => setState(() => _selectedTool = 'csp'),
                    tooltip: 'CSP',
                  ),
                  const Divider(height: 1),
                  IconButton(
                    icon: const Icon(Icons.account_balance_wallet),
                    color: _selectedTool == 'hub' ? Colors.orange : Colors.grey,
                    onPressed: () => setState(() => _selectedTool = 'hub'),
                    tooltip: 'HUB',
                  ),
                ],
              ),
            ),
          ),

          // 4. الأزرار العائمة اليمنى (الطبقات وتحديد الموقع)
          Positioned(
            top: 110,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'layerBtn',
                  backgroundColor: Colors.green[200],
                  child: const Icon(Icons.map, color: Colors.black87),
                  onPressed: () {
                    setState(() => _showMarkers = !_showMarkers);
                  },
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'gpsBtn',
                  backgroundColor: Colors.green[200],
                  child: const Icon(Icons.my_location, color: Colors.black87),
                  onPressed: _determinePosition,
                ),
              ],
            ),
          ),

          // 5. الشريط السفلي للأزرار الكبيرة (Common, CSP, HUB)
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBottomToolCard('Common', 'common', Icons.location_pin, Colors.red),
                _buildBottomToolCard('CSP', 'csp', Icons.settings_input_component, Colors.blue),
                _buildBottomToolCard('HUB', 'hub', Icons.account_balance_wallet, Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolCard(String label, String toolKey, IconData icon, Color color) {
    bool isSelected = _selectedTool == toolKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedTool = toolKey),
      child: Container(
        width: 105,
        height: 75,
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[50] : Colors.white,
          border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.green[800] : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
