import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:xml/xml.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const NabawiMapsApp());
}

class NabawiMapsApp extends StatelessWidget {
  const NabawiMapsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nabawi Maps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0B5D3B),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const NabawiMapsHome(),
    );
  }
}

class Place {
  final String name;
  final String description; // Arabic description (default)
  final String descEn;
  final String descTr;
  final String descId;
  final String category;
  final String? mapsUrl;
  final LatLng location;
  String nameEn;

  Place({
    required this.name,
    required this.description,
    this.descEn = '',
    this.descTr = '',
    this.descId = '',
    required this.category,
    required this.location,
    this.mapsUrl,
    this.nameEn = '',
  });
}

class NabawiMapsHome extends StatefulWidget {
  const NabawiMapsHome({super.key});

  @override
  State<NabawiMapsHome> createState() => _NabawiMapsHomeState();
}

class _NabawiMapsHomeState extends State<NabawiMapsHome>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController searchController = TextEditingController();

  List<Place> places = [];
  List<Place> filteredPlaces = [];

  String selectedCategory = 'الكل';
  bool isLoading = true;
  String? errorMessage;

  Set<String> favoriteNames = {};
  Place? selectedPlace;
  LatLng? _previousCenter;
  double? _previousZoom;
  LatLng _initialCenter = const LatLng(24.4672, 39.6111);
  double _initialZoom = 11;

  // ── اللغة الحالية: ar / en / tr / id ──
  String _currentLang = 'ar';

  final List<String> categories = const [
    'الكل',
    '⭐ المفضلة',
    'مساجد',
    'معارك',
    'آبار',
    'جبال',
    'حرات',
    'حصون',
    'أسواق',
    'قصور',
    'أخرى',
  ];

  // ── ترجمة التصنيفات ──
  static const Map<String, Map<String, String>> _categoryLocale = {
    'الكل': {'en': 'All', 'tr': 'Tümü', 'id': 'Semua'},
    '⭐ المفضلة': {'en': '⭐ Favorites', 'tr': '⭐ Favoriler', 'id': '⭐ Favorit'},
    'مساجد': {'en': 'Mosques', 'tr': 'Camiler', 'id': 'Masjid'},
    'معارك': {'en': 'Battles', 'tr': 'Savaşlar', 'id': 'Pertempuran'},
    'آبار': {'en': 'Wells', 'tr': 'Kuyular', 'id': 'Sumur'},
    'جبال': {'en': 'Mountains', 'tr': 'Dağlar', 'id': 'Gunung'},
    'حرات': {'en': 'Lava Fields', 'tr': 'Lav Alanları', 'id': 'Ladang Lava'},
    'حصون وآطام': {'en': 'Forts', 'tr': 'Kaleler', 'id': 'Benteng'},
    'حصون': {'en': 'Forts', 'tr': 'Kaleler', 'id': 'Benteng'},
    'أسواق': {'en': 'Markets', 'tr': 'Çarşılar', 'id': 'Pasar'},
    'قصور': {'en': 'Palaces', 'tr': 'Saraylar', 'id': 'Istana'},
    'مسار الهجرة': {'en': 'Hijra Route', 'tr': 'Hicret Güzergahı', 'id': 'Rute Hijrah'},
    'أخرى': {'en': 'Other', 'tr': 'Diğer', 'id': 'Lainnya'},
  };

  // ── ترجمة أسماء المواقع (إنجليزي — يُستخدم للتركي والإندونيسي أيضاً) ──
  static const Map<String, String> _nameEnMap = {
    'مسجد القبلتين': 'Mosque of the Two Qiblas',
    'مسجد قباء': 'Quba Mosque',
    'مسجد الغمامة': 'Al-Ghamama Mosque',
    'مسجد الفسح': 'Al-Fusha Mosque',
    'مسجد بني دينار الأدنى': 'Banu Dinar Mosque (Lower)',
    'مسجد بني دينار الأعلى': 'Banu Dinar Mosque (Upper)',
    'موقع مسجد بني معاوية(الإجابة)': 'Banu Muawiya Mosque Site (Al-Ijaba)',
    'مسجد أول جمعة صلاها النبي صلى الله عليه وسلم':
        'Mosque of the First Friday Prayer',
    'مسجد المستراح': 'Al-Mustarah Mosque',
    'مسجد سجدة الشكر': 'Mosque of Gratitude Prostration',
    'مسجد الفتح': 'Al-Fath Mosque',
    'مسجد الدرع': 'Al-Dir Mosque',
    'مسجد بني أنيف': 'Banu Anif Mosque',
    'مسجد الخليفة عمر بن الخطاب': 'Mosque of Caliph Umar ibn Al-Khattab',
    'مسجد الخليفة أبي بكر': 'Mosque of Caliph Abu Bakr',
    'مسجد سلمان الفارسي': 'Salman Al-Farsi Mosque',
    'مسجد الخليفة علي بن أبي طالب': 'Mosque of Caliph Ali ibn Abi Talib',
    'مسجد سعد بن معاذ': "Sa'd ibn Mu'adh Mosque",
    'جبل ذباب': 'Dhubab Mountain',
    'جبل سلع': "Sala' Mountain",
    'جبل وعيرة': 'Wuayra Mountain',
    'جبل أحد': 'Mount Uhud',
    'جبل الرماة': "Archers' Mountain",
    'جبل الملائكة': "Angels' Mountain",
    'جبل بني عبيد': 'Banu Ubayd Mountain',
    'جبل قرين الصريحة': 'Qurain Al-Sariha',
    'بئر رومة': 'Ruma Well',
    'بئر العهن أو اليسيرة': 'Al-Ahn Well',
    'بئر الأعواف': "Al-A'waf Well",
    'بئر غرس': 'Ghars Well',
    'حصن الضحيان': 'Al-Dahyan Fort',
    'حصن راتج': 'Ratij Fort',
    'أطم صرار': 'Sirar Tower',
    'حصن بني واقف': 'Banu Waqif Fort',
    'حرة الوبرة': 'Al-Wabara Lava Field',
    'حرة واقم': 'Waqim Lava Field',
    'حرة بني بياضة': 'Banu Bayadha Lava Field',
    'حرة شوران': 'Shawran Lava Field',
    'غزوة أحد': 'Battle of Uhud',
    'غزوة بدر': 'Battle of Badr',
    'غزوة الخندق': 'Battle of the Trench',
    'قصر عروة بن الزبير': 'Palace of Urwa ibn Al-Zubayr',
    'سوق المناخة': 'Al-Manakha Market',
    'سقيفة بني ساعدة': "Saqifa of Banu Sa'ida",
    'ثنية الوداع': "Thaniyyat Al-Wada'",
    'ذات الجيش': 'Dhat Al-Jaysh',
    'روضة خاخ': 'Rawdat Khakh',
    'زغابة': 'Zaghabah',
    'الغابة أرض الزبير بن العوام': 'Al-Ghaba — Land of Al-Zubayr ibn Al-Awwam',
    'غار السجدة': 'Cave of Prostration',
    'بقيع الغرقد': "Al-Baqi' Cemetery",
    'مشربة أم إبراهيم': 'Mashrabat Umm Ibrahim',
    'مزرعة سلمان الفارسي رضي الله عنه': 'Farm of Salman Al-Farsi',
    'مزارع برقة': 'Barqa Farms',
    'مقبرة شهداء الخندق': 'Cemetery of the Trench Martyrs',
    'مقبرة شهداء بدر': 'Cemetery of Badr Martyrs',
    'وادي العقيق المبارك': 'Al-Aqiq Blessed Valley',
    'وادي قناة': 'Qanat Valley',
  };

  @override
  void initState() {
    super.initState();
    loadFavorites();
    _loadMapPosition();
    loadKml();
  }

  // ════════════════════════════════════════
  //  FAVORITES
  // ════════════════════════════════════════

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favoriteNames = prefs.getStringList('favorites')?.toSet() ?? {};
    });
  }

  Future<void> saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', favoriteNames.toList());
  }

  void toggleFavorite(String name) {
    setState(() {
      if (favoriteNames.contains(name)) {
        favoriteNames.remove(name);
      } else {
        favoriteNames.add(name);
      }
    });
    saveFavorites();
    applyFilters();
  }

  bool isFavorite(String name) => favoriteNames.contains(name);

  // ════════════════════════════════════════
  //  MAP POSITION
  // ════════════════════════════════════════

  Future<void> _loadMapPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('map_lat');
    final lng = prefs.getDouble('map_lng');
    final zoom = prefs.getDouble('map_zoom');
    if (lat != null && lng != null && zoom != null) {
      setState(() {
        _initialCenter = LatLng(lat, lng);
        _initialZoom = zoom;
      });
    }
  }

  Future<void> _saveMapPosition(LatLng center, double zoom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('map_lat', center.latitude);
    await prefs.setDouble('map_lng', center.longitude);
    await prefs.setDouble('map_zoom', zoom);
  }

  // ════════════════════════════════════════
  //  ANIMATED MOVE
  // ════════════════════════════════════════

  void _animatedMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );
    final controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );
    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });
    controller.forward();
  }

  // ════════════════════════════════════════
  //  SELECT PLACE
  // ════════════════════════════════════════

  void selectPlace(Place place) {
    _previousCenter = _mapController.camera.center;
    _previousZoom = _mapController.camera.zoom;
    setState(() => selectedPlace = place);
    _animatedMove(place.location, 16);
    showPlaceInfo(place);
  }

  // ════════════════════════════════════════
  //  CURRENT LOCATION
  // ════════════════════════════════════════

  Future<void> _goToMyLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'خدمة الموقع غير مفعّلة',
              'Location service disabled',
              'Konum servisi devre dışı',
              'Layanan lokasi dinonaktifkan',
            ),
          ),
        ),
      );
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'لم يتم منح إذن الموقع',
                'Location permission denied',
                'Konum izni reddedildi',
                'Izin lokasi ditolak',
              ),
            ),
          ),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'إذن الموقع مرفوض. فعّله من الإعدادات.',
              'Enable location in device settings.',
              'Ayarlardan konumu etkinleştirin.',
              'Aktifkan lokasi di pengaturan.',
            ),
          ),
        ),
      );
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    setState(() => selectedPlace = null);
    _animatedMove(LatLng(position.latitude, position.longitude), 15);
  }

  // ════════════════════════════════════════
  //  LANGUAGE — 4 لغات
  // ════════════════════════════════════════

  /// يعيد النص بحسب اللغة الحالية.
  String _t(String ar, String en, [String tr = '', String id = '']) {
    switch (_currentLang) {
      case 'en':
        return en.isNotEmpty ? en : ar;
      case 'tr':
        return tr.isNotEmpty
            ? tr
            : en.isNotEmpty
            ? en
            : ar;
      case 'id':
        return id.isNotEmpty
            ? id
            : en.isNotEmpty
            ? en
            : ar;
      default:
        return ar;
    }
  }

  /// يعيد الاسم المعروض للموقع بحسب اللغة.
  String _getDisplayName(Place place) {
    if (_currentLang == 'ar') return place.name;
    return place.nameEn.isNotEmpty ? place.nameEn : place.name;
  }

  /// يعيد الوصف المعروض للموقع بحسب اللغة.
  String _getDesc(Place place) {
    switch (_currentLang) {
      case 'en':
        return place.descEn.isNotEmpty ? place.descEn : place.description;
      case 'tr':
        return place.descTr.isNotEmpty ? place.descTr : place.description;
      case 'id':
        return place.descId.isNotEmpty ? place.descId : place.description;
      default:
        return place.description; // Arabic
    }
  }

  /// يعيد اسم التصنيف بحسب اللغة.
  String _getCategoryLabel(String category) {
    if (_currentLang == 'ar') return category;
    return _categoryLocale[category]?[_currentLang] ??
        _categoryLocale[category]?['en'] ??
        category;
  }

  void _setLanguage(String lang) {
    setState(() => _currentLang = lang);
    applyFilters();
  }

  // ════════════════════════════════════════
  //  DISPOSE
  // ════════════════════════════════════════

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════
  //  KML & HELPERS
  // ════════════════════════════════════════

  String cleanDescription(String raw) {
    var text = raw;
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('للوصول إلى الموقع', '');
    text = text.replaceAll(RegExp(r'(https?://|maps\.app\.goo\.gl/)\S+'), '');
    text = text.replaceAll(RegExp(r'\n\s*\n+'), '\n');
    text = text.trim();
    return text;
  }

  String? extractMapsUrl(String raw) {
    final match = RegExp(r'https?://[^\s"<]+').firstMatch(raw);
    return match?.group(0);
  }

  static const Map<String, String> _categoryMap = {
    'مسجد القبلتين': 'مساجد',
    'مسجد قُباء': 'مساجد',
    'مسجد الغمامة': 'مساجد',
    'مسجد الفسح': 'مساجد',
    'مسجد بني دينار الأدنى': 'مساجد',
    'مسجد بني دينار الأعلى': 'مساجد',
    'موقع مسجد بني معاوية(الإجابة)': 'مساجد',
    'مسجد أول جمعة صلاها النبي صلى الله عليه وسلم': 'مساجد',
    'مسجد المستراح': 'مساجد',
    'مسجد سجدة الشكر': 'مساجد',
    'مسجد الفتح': 'مساجد',
    'مسجد الدرع': 'مساجد',
    'مسجد بني أنيف': 'مساجد',
    'مسجد الخليفة عمر بن الخطاب': 'مساجد',
    'مسجد الخليفة أبي بكر': 'مساجد',
    'مسجد سلمان الفارسي': 'مساجد',
    'مسجد الخليفة علي بن أبي طالب': 'مساجد',
    'مسجد سعد بن معاذ': 'مساجد',
    'جبل ذباب': 'جبال',
    'جبل سلع': 'جبال',
    'جبل وعيرة': 'جبال',
    'جبل أحد': 'جبال',
    'جبل الرماة': 'جبال',
    'جبل الملائكة': 'جبال',
    'جبل بني عبيد': 'جبال',
    'جبل قرين الصريحة': 'جبال',
    'بئر رومة': 'آبار',
    'بئر العهن أو اليسيرة': 'آبار',
    'بئر الأعواف': 'آبار',
    'بئر غرس': 'آبار',
    'حصن الضحيان': 'حصون وآطام',
    'حصن راتج': 'حصون وآطام',
    'أطم صرار': 'حصون وآطام',
    'حصن بني واقف': 'حصون وآطام',
    'حرة الوبرة': 'حرات',
    'حرة واقم': 'حرات',
    'حرة بني بياضة': 'حرات',
    'حرة شوران': 'حرات',
    'غزوة أحد': 'معارك',
    'غزوة بدر': 'معارك',
    'غزوة الخندق': 'معارك',
    'غزوة تبوك': 'معارك',
    'غزوة الطائف': 'معارك',
    'غزوة حنين': 'معارك',
    'غزوة خيبر': 'معارك',
    'غزوة الأبواء': 'معارك',
    'قصر عروة بن الزبير': 'قصور',
    'سوق المناخة': 'أسواق',
    'مسجد السقيا': 'مساجد',
    'مسجد بني حرام': 'مساجد',
    'مسجد البيعة (العقبة)': 'مساجد',
    'مسجد الحديبية': 'مساجد',
    'مسجد الجعرانة': 'مساجد',
    'بئر سلمان الفارسي رضي الله عنه': 'آبار',
    'بئر خاتم النبي ﷺ (أريس)': 'آبار',
    'بئر طوى': 'آبار',
    'بئر الروحاء': 'آبار',
    'بئر أهاب': 'آبار',
    'حصن كعب الأشراف': 'حصون وآطام',
    'سقيفة بني ساعدة': 'أخرى',
    'ثنية الوداع': 'أخرى',
    'ذات الجيش': 'أخرى',
    'روضة خاخ': 'أخرى',
    'زغابة': 'أخرى',
    'الغابة أرض الزبير بن العوام': 'أخرى',
    'غار السجدة': 'أخرى',
    'بقيع الغرقد': 'أخرى',
    'مشربة أم إبراهيم': 'أخرى',
    'مزرعة سلمان الفارسي رضي الله عنه': 'أخرى',
    'مزارع برقة': 'أخرى',
    'مقبرة شهداء الخندق': 'أخرى',
    'مقبرة شهداء بدر': 'أخرى',
    'وادي العقيق المبارك': 'أخرى',
    'وادي قناة': 'أخرى',
    'غار حراء': 'أخرى',
    'بادية بني سعد': 'أخرى',
    'شعب بني هاشم مولد النبي صلى الله عليه وسلم': 'أخرى',
    'شهداء غزوة الطائف': 'أخرى',
    'غار ثور': 'أخرى',
    'بَحْرَة الرُّغاء': 'أخرى',
    'غدير خم': 'أخرى',
  };

  String _normalize(String s) => s.trim().replaceAll(RegExp(r'[ً-ٰٟ]'), '');

  String detectCategory(
    String name,
    String description, [
    String styleUrl = '',
  ]) {
    final normalizedName = _normalize(name);
    for (final entry in _categoryMap.entries) {
      if (_normalize(entry.key) == normalizedName) return entry.value;
    }
    final text = '$name $description';
    if (text.contains('مسجد')) return 'مساجد';
    if (text.contains('حرة')) return 'حرات';
    if (text.contains('بئر') || text.contains('آبار')) return 'آبار';
    if (text.contains('جبل')) return 'جبال';
    if (text.contains('آطم') || text.contains('أطم') || text.contains('حصن')) {
      return 'حصون وآطام';
      }
    if (text.contains('سوق')) return 'أسواق';
    if (text.contains('قصر')) return 'قصور';
    if (text.contains('غزوة') || text.contains('معركة')) return 'معارك';
    return 'أخرى';
  }

  IconData iconForCategory(String category) {
    switch (category) {
      case 'مساجد':
        return Icons.mosque;
      case 'معارك':
        return Icons.shield;
      case 'آبار':
        return Icons.water_drop;
      case 'جبال':
        return Icons.terrain;
      case 'حرات':
        return Icons.landscape;
      case 'حصون وآطام':
        return Icons.fort;
      case 'أسواق':
        return Icons.storefront;
      case 'قصور':
        return Icons.account_balance;
      default:
        return Icons.location_pin;
    }
  }

  Future<void> loadKml() async {
    try {
      final kmlText = await rootBundle.loadString('assets/kml/locations.kml');
      final document = XmlDocument.parse(kmlText);
      final placemarks = document.findAllElements('Placemark');
      final loadedPlaces = <Place>[];

      for (final placemark in placemarks) {
        final nameElement = placemark.findElements('name').firstOrNull;
        final coordinatesElement = placemark
            .findAllElements('coordinates')
            .firstOrNull;
        final descriptionElement = placemark
            .findElements('description')
            .firstOrNull;
        if (nameElement == null || coordinatesElement == null) continue;

        final name = nameElement.innerText.trim();
        final rawDescription = descriptionElement?.innerText.trim() ?? '';

        // Parse multilingual format: AR::...||EN::...||TR::...||ID::...||MAPS::...
        String descAr = '', descEn = '', descTr = '', descId = '', mapsUrl = '';
        if (rawDescription.contains('AR::') && rawDescription.contains('||EN::')) {
          final parts2 = rawDescription.split('||');
          for (final p in parts2) {
            if (p.startsWith('AR::')) { descAr = p.substring(4).trim(); }
            else if (p.startsWith('EN::')) { descEn = p.substring(4).trim(); }
            else if (p.startsWith('TR::')) { descTr = p.substring(4).trim(); }
            else if (p.startsWith('ID::')) { descId = p.substring(4).trim(); }
            else if (p.startsWith('MAPS::')) { mapsUrl = p.substring(6).trim(); }
          }
        } else {
          // Legacy format fallback
          descAr = cleanDescription(rawDescription);
          mapsUrl = extractMapsUrl(rawDescription) ?? '';
        }

        final styleUrl =
            placemark.findElements('styleUrl').firstOrNull?.innerText.trim() ??
            '';
        final category = detectCategory(name, descAr, styleUrl);

        final coordinatesText = coordinatesElement.innerText.trim();
        final firstCoordinate = coordinatesText.split(RegExp(r'\s+')).first;
        final parts = firstCoordinate.split(',');
        if (parts.length < 2) continue;

        final longitude = double.tryParse(parts[0]);
        final latitude = double.tryParse(parts[1]);
        if (latitude == null || longitude == null) continue;

        // الاسم الإنجليزي من الجدول الثابت
        final normalizedN = _normalize(name);
        final nameEn = _nameEnMap.entries
            .firstWhere(
              (e) => _normalize(e.key) == normalizedN,
              orElse: () => const MapEntry('', ''),
            )
            .value;

        loadedPlaces.add(
          Place(
            name: name,
            description: descAr,
            descEn: descEn,
            descTr: descTr,
            descId: descId,
            category: category,
            mapsUrl: mapsUrl.isEmpty ? null : mapsUrl,
            location: LatLng(latitude, longitude),
            nameEn: nameEn,
          ),
        );
      }

      setState(() {
        places = loadedPlaces;
        filteredPlaces = loadedPlaces;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // ════════════════════════════════════════
  //  FILTERS
  // ════════════════════════════════════════

  void applyFilters() {
    final query = searchController.text.trim().toLowerCase();
    setState(() {
      filteredPlaces = places.where((place) {
        final matchesSearch =
            query.isEmpty ||
            place.name.contains(query) ||
            place.description.contains(query) ||
            (_currentLang != 'ar' &&
                place.nameEn.toLowerCase().contains(query)) ||
            (_currentLang != 'ar' &&
                _getDesc(place).toLowerCase().contains(query));
        final matchesCategory =
            selectedCategory == 'الكل' ||
            place.category == selectedCategory ||
            (selectedCategory == '⭐ المفضلة' &&
                favoriteNames.contains(place.name));
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void selectCategory(String category) {
    selectedCategory = category;
    applyFilters();
  }

  void goToPlace(Place place) {
    FocusScope.of(context).unfocus();
    selectPlace(place);
  }

  // ════════════════════════════════════════
  //  OPEN MAPS / COPY
  // ════════════════════════════════════════

  Future<void> openMaps(String url, {LatLng? location}) async {
    // Build reliable URLs from coordinates when available
    final double? lat = location?.latitude;
    final double? lng = location?.longitude;

    final googleUrl = (lat != null && lng != null)
        ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
        : url;
    final appleUrl = (lat != null && lng != null)
        ? 'maps://?q=$lat,$lng'
        : 'https://maps.apple.com/?q=$lat,$lng';

    if (Platform.isIOS) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_t('افتح بـ', 'Open with', 'Aç', 'Buka dengan')),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await launchUrl(
                  Uri.parse(appleUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('Apple Maps'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await launchUrl(
                  Uri.parse(googleUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('Google Maps'),
            ),
          ],
        ),
      );
    } else {
      // Android: open Google Maps directly with coordinates
      final uri = Uri.parse(googleUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'تعذر فتح الرابط',
                'Could not open link',
                'Bağlantı açılamadı',
                'Tautan tidak dapat dibuka',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> copyText(
    String text,
    String ar,
    String en,
    String tr,
    String id,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_t(ar, en, tr, id))));
  }

  // ════════════════════════════════════════
  //  PLACE INFO SHEET
  // ════════════════════════════════════════

  void showPlaceInfo(Place place) {
    final displayName = _getDisplayName(place);
    final displayDesc = _getDesc(place);
    final displayCategory = _getCategoryLabel(place.category);
    final isRtl = _currentLang == 'ar';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    iconForCategory(place.category),
                    color: const Color(0xFF0B5D3B),
                    size: 42,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B5D3B),
                    ),
                  ),
                  if (_currentLang != 'ar') ...[
                    const SizedBox(height: 4),
                    Text(
                      place.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Center(
                    child: Chip(
                      label: Text(displayCategory),
                      backgroundColor: const Color(0xFFEAF4EF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayDesc.isEmpty
                        ? _t(
                            'لا يوجد وصف.',
                            'No description available.',
                            'Açıklama mevcut değil.',
                            'Deskripsi tidak tersedia.',
                          )
                        : displayDesc,
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(fontSize: 17, height: 1.8),
                  ),
                  const SizedBox(height: 20),
                  StatefulBuilder(
                    builder: (context, setSheetState) {
                      return OutlinedButton.icon(
                        onPressed: () {
                          toggleFavorite(place.name);
                          setSheetState(() {});
                        },
                        icon: Icon(
                          isFavorite(place.name)
                              ? Icons.star
                              : Icons.star_border,
                        ),
                        label: Text(
                          isFavorite(place.name)
                              ? _t(
                                  'إزالة من المفضلة',
                                  'Remove from Favorites',
                                  'Favorilerden Kaldır',
                                  'Hapus dari Favorit',
                                )
                              : _t(
                                  'إضافة إلى المفضلة',
                                  'Add to Favorites',
                                  'Favorilere Ekle',
                                  'Tambah ke Favorit',
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (place.mapsUrl != null)
                    FilledButton.icon(
                      onPressed: () => openMaps(place.mapsUrl!, location: place.location),
                      icon: const Icon(Icons.navigation),
                      label: Text(
                        _t(
                          'الانتقال إلى الموقع',
                          'Navigate to Location',
                          'Konuma Git',
                          'Navigasi ke Lokasi',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => selectedPlace = null);
      if (_previousCenter != null && _previousZoom != null) {
        _animatedMove(_previousCenter!, _previousZoom!);
        _previousCenter = null;
        _previousZoom = null;
      }
    });
  }

  // ════════════════════════════════════════
  //  SEARCH RESULTS
  // ════════════════════════════════════════

  Widget buildSearchResults() {
    final query = searchController.text.trim();
    if (query.isEmpty || filteredPlaces.isEmpty) return const SizedBox.shrink();
    final results = filteredPlaces.take(6).toList();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
      ),
      child: Column(
        children: results.map((place) {
          return ListTile(
            dense: true,
            leading: Icon(
              iconForCategory(place.category),
              color: const Color(0xFF0B5D3B),
            ),
            title: Text(_getDisplayName(place)),
            subtitle: Text(_getCategoryLabel(place.category)),
            onTap: () => goToPlace(place),
          );
        }).toList(),
      ),
    );
  }

  // ════════════════════════════════════════
  //  CATEGORY CHIPS
  // ════════════════════════════════════════

  Widget buildCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category;

          String label;
          if (category == '⭐ المفضلة') {
            final favLabel = _currentLang == 'ar'
                ? 'المفضلة'
                : _currentLang == 'tr'
                ? 'Favoriler'
                : _currentLang == 'id'
                ? 'Favorit'
                : 'Favorites';
            label = '⭐ $favLabel (${favoriteNames.length})';
          } else {
            label = _getCategoryLabel(category);
          }

          return ChoiceChip(
            label: Directionality(
              textDirection: _currentLang == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Text(label),
            ),
            selected: isSelected,
            onSelected: (_) => selectCategory(category),
            selectedColor: const Color(0xFF0B5D3B),
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF0B5D3B),
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: Colors.white,
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════
  //  HAMBURGER MENU
  // ════════════════════════════════════════

  Widget _buildHamburgerButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: IconButton(
        onPressed: _showCategoryMenu,
        icon: const Icon(Icons.menu, color: Color(0xFF0B5D3B)),
        tooltip: _t('التصنيفات', 'Categories', 'Kategoriler', 'Kategori'),
      ),
    );
  }

  void _showCategoryMenu() {
    // Build inverted map: category → list of location names
    final Map<String, List<String>> categoryPlaces = {};
    for (final entry in _categoryMap.entries) {
      categoryPlaces.putIfAbsent(entry.value, () => []).add(entry.key);
    }
    // Order categories logically
    final orderedCategories = [
      'مساجد', 'جبال', 'آبار', 'حصون وآطام', 'حرات', 'معارك', 'قصور', 'أسواق', 'أخرى',
    ].where((c) => categoryPlaces.containsKey(c)).toList();
    // Add any categories not in the ordered list
    for (final c in categoryPlaces.keys) {
      if (!orderedCategories.contains(c)) orderedCategories.add(c);
    }
    // Add special "coming soon" category at the end
    orderedCategories.add('مسار الهجرة');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _CategoryMenuSheet(
          categoryPlaces: categoryPlaces,
          orderedCategories: orderedCategories,
          currentLang: _currentLang,
          getCategoryLabel: _getCategoryLabel,
          getDisplayName: _getDisplayName,
          allPlaces: places,
          onPlaceSelected: (place) {
            Navigator.pop(ctx);
            selectPlace(place);
            _mapController.move(place.location, 16);
          },
        );
      },
    );
  }

  // ════════════════════════════════════════
  //  LANGUAGE TOGGLE — 4 أزرار
  // ════════════════════════════════════════

  Widget _buildLangToggle() {
    const langs = ['AR', 'EN', 'TR', 'ID'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: langs.map((label) {
          final isActive = _currentLang == label.toLowerCase();
          return GestureDetector(
            onTap: () => _setLanguage(label.toLowerCase()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF0B5D3B) : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF0B5D3B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ════════════════════════════════════════
  //  TOP PANEL
  // ════════════════════════════════════════

  Widget buildTopPanel() {
    return Positioned(
      top: 40,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHamburgerButton(),
              _buildLangToggle(),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(blurRadius: 12, color: Colors.black26),
              ],
            ),
            child: TextField(
              controller: searchController,
              textAlign: _currentLang == 'ar'
                  ? TextAlign.right
                  : TextAlign.left,
              textDirection: _currentLang == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              decoration: InputDecoration(
                hintText: _t(
                  'ابحث عن موقع...',
                  'Search for a location...',
                  'Konum ara...',
                  'Cari lokasi...',
                ),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => applyFilters(),
            ),
          ),
          buildSearchResults(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  //  MAP CONTROLS
  // ════════════════════════════════════════

  void _changeZoom(double delta) {
    final newZoom = (_mapController.camera.zoom + delta).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
  }

  Widget buildMapControls() {
    return Positioned(
      bottom: 24,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _changeZoom(1),
              icon: const Icon(Icons.add),
              color: const Color(0xFF0B5D3B),
            ),
            Container(height: 1, color: const Color(0xFFEEEEEE)),
            IconButton(
              onPressed: () => _changeZoom(-1),
              icon: const Icon(Icons.remove),
              color: const Color(0xFF0B5D3B),
            ),
            Container(height: 1, color: const Color(0xFFEEEEEE)),
            IconButton(
              onPressed: _goToMyLocation,
              icon: const Icon(Icons.my_location),
              color: const Color(0xFF0B5D3B),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              )
            : isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _initialCenter,
                      initialZoom: _initialZoom,
                      onMapEvent: (MapEvent event) {
                        if (event is MapEventMoveEnd) {
                          _saveMapPosition(
                            event.camera.center,
                            event.camera.zoom,
                          );
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.nabawi.maps',
                      ),
                      MarkerLayer(
                        markers: filteredPlaces.map((place) {
                          final isSelected = selectedPlace?.name == place.name;
                          return Marker(
                            point: place.location,
                            width: isSelected ? 62 : 54,
                            height: isSelected ? 62 : 54,
                            child: GestureDetector(
                              onTap: () => selectPlace(place),
                              child: Container(
                                decoration: isSelected
                                    ? BoxDecoration(
                                        color: const Color(
                                          0xFFD4AF37,
                                        ).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFD4AF37),
                                          width: 2,
                                        ),
                                      )
                                    : null,
                                child: Icon(
                                  iconForCategory(place.category),
                                  color: isSelected
                                      ? const Color(0xFFD4AF37)
                                      : const Color(0xFF0B5D3B),
                                  size: isSelected ? 44 : 38,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  buildTopPanel(),
                  buildMapControls(),
                ],
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  CATEGORY MENU SHEET — bottom sheet with categories
// ══════════════════════════════════════════════════════

class _CategoryMenuSheet extends StatefulWidget {
  final Map<String, List<String>> categoryPlaces;
  final List<String> orderedCategories;
  final String currentLang;
  final String Function(String) getCategoryLabel;
  final String Function(Place) getDisplayName;
  final List<Place> allPlaces;
  final void Function(Place) onPlaceSelected;

  const _CategoryMenuSheet({
    required this.categoryPlaces,
    required this.orderedCategories,
    required this.currentLang,
    required this.getCategoryLabel,
    required this.getDisplayName,
    required this.allPlaces,
    required this.onPlaceSelected,
  });

  @override
  State<_CategoryMenuSheet> createState() => _CategoryMenuSheetState();
}

class _CategoryMenuSheetState extends State<_CategoryMenuSheet> {
  String? _expandedCategory;

  @override
  Widget build(BuildContext context) {
    final isRtl = widget.currentLang == 'ar';
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  widget.currentLang == 'ar'
                      ? 'التصنيفات'
                      : widget.currentLang == 'tr'
                      ? 'Kategoriler'
                      : widget.currentLang == 'id'
                      ? 'Kategori'
                      : 'Categories',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B5D3B),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: widget.orderedCategories.map((category) {
                    final places = widget.categoryPlaces[category] ?? [];
                    final isExpanded = _expandedCategory == category;
                    final label = widget.getCategoryLabel(category);

                    // Special "coming soon" category
                    final isComingSoon = category == 'مسار الهجرة';

                    return Column(
                      children: [
                        InkWell(
                          onTap: () {
                            if (isComingSoon) {
                              setState(() { _expandedCategory = isExpanded ? null : category; });
                            } else {
                              setState(() { _expandedCategory = isExpanded ? null : category; });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isExpanded
                                  ? const Color(0xFFEAF4EF)
                                  : Colors.white,
                              border: const Border(
                                bottom: BorderSide(color: Color(0xFFEEEEEE)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _categoryIcon(category),
                                  color: const Color(0xFF0B5D3B),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '$label  (${places.length})',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0B5D3B),
                                    ),
                                  ),
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: const Color(0xFF0B5D3B),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded && isComingSoon)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FCF9),
                              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                            ),
                            child: Text(
                              widget.currentLang == 'ar' ? 'قريباً' :
                              widget.currentLang == 'tr' ? 'Yakında' :
                              widget.currentLang == 'id' ? 'Segera' : 'Coming Soon',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF0B5D3B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (isExpanded && !isComingSoon)
                          ...places.map((name) {
                            final place = widget.allPlaces.firstWhere(
                              (p) => p.name == name,
                              orElse: () => Place(
                                name: name,
                                description: '',
                                location: const LatLng(0, 0),
                                category: category,
                              ),
                            );
                            final displayName = place.location.latitude != 0
                                ? widget.getDisplayName(place)
                                : name;
                            return InkWell(
                              onTap: () {
                                if (place.location.latitude != 0) {
                                  widget.onPlaceSelected(place);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 52,
                                  vertical: 11,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FCF9),
                                  border: Border(
                                    bottom: BorderSide(color: Color(0xFFEEEEEE)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Color(0xFF0B5D3B),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'مساجد': return Icons.mosque;
      case 'جبال': return Icons.terrain;
      case 'آبار': return Icons.water_drop;
      case 'حصون وآطام': return Icons.fort;
      case 'حرات': return Icons.local_fire_department;
      case 'معارك': return Icons.shield;
      case 'قصور': return Icons.castle;
      case 'أسواق': return Icons.storefront;
      case 'مسار الهجرة': return Icons.route;
      default: return Icons.place;
    }
  }
}
