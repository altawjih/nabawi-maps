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
  final String description;
  final String category;
  final String? mapsUrl;
  final LatLng location;
  String nameEn;

  Place({
    required this.name,
    required this.description,
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

  // ── أوصاف مدمجة بالإنجليزية والتركية والإندونيسية ──
  static const Map<String, Map<String, String>> _descriptionMap = {
    'مسجد القبلتين': {
      'en':
          'Qiblatain Mosque is one of the prominent historic mosques in Al-Madinah Al-Munawwarah. It is located in the Banu Salamah area, northwest of the Prophet\'s Mosque, near Wadi Al-Aqiq. Its name derives from the momentous event associated with it: the change of the qiblah from Jerusalem (Bayt al-Maqdis) to the Holy Kaaba while the Muslims were praying there. Since then, it has become known as the Mosque of the Two Qiblahs (Qiblatain Mosque). It is among the mosques in which the Prophet Muhammad ﷺ prayed. Throughout its history, it has undergone several stages of restoration and renovation, beginning with its simple structure in the early Islamic period and culminating in its reconstruction and expansion in the modern era, making it a fully equipped mosque capable of accommodating large numbers of worshippers. Its significance stems from its association with the event of the change of the qiblah, one of the most important events in the history of Islamic legislation and the Prophetic biography.',
      'tr':
          'Mescidü\'l-Kıbleteyn, Medine-i Münevvere\'nin öne çıkan tarihî mescitlerinden biridir. Nebevî Mescid\'in kuzeybatısında, Benî Seleme bölgesinde, Vadi el-Akik yakınında yer alır. Adını, burada meydana gelen büyük olaydan almıştır: Müslümanlar namaz kılarken kıblenin Beytülmakdis\'ten Kâbe-i Muazzama\'ya çevrilmesi. Bu olaydan sonra mescit, "İki Kıbleli Mescid" (Mescidü\'l-Kıbleteyn) olarak tanınmıştır. Hz. Peygamber ﷺ\'in namaz kıldığı mescitlerden biridir. Tarihi boyunca birçok onarım ve yenileme aşamasından geçmiş; ilk dönemlerdeki sade yapısından başlayarak modern dönemde yeniden inşa edilip genişletilmiş, böylece çok sayıda ibadet edeni ağırlayabilecek tüm donanıma sahip bir mescit hâline gelmiştir. Önemi, kıblenin değiştirilmesi olayına bağlı olmasından kaynaklanır. Bu olay, İslam teşri tarihinin ve Siyer-i Nebeviyye\'nin en önemli hadiselerinden biridir.',
      'id':
          'Masjid Qiblatain merupakan salah satu masjid bersejarah yang paling menonjol di Madinah. Masjid ini terletak di kawasan Bani Salamah, di sebelah barat laut Masjid Nabawi, dekat Wadi Al-Aqiq. Namanya berasal dari peristiwa agung yang terjadi di tempat ini, yaitu perubahan arah kiblat dari Baitul Maqdis ke Ka\'bah ketika kaum Muslimin sedang melaksanakan salat di dalamnya. Sejak saat itu masjid ini dikenal sebagai Masjid Qiblatain (Masjid Dua Kiblat). Masjid ini termasuk salah satu masjid tempat Nabi Muhammad ﷺ pernah melaksanakan salat. Sepanjang sejarahnya, masjid ini telah mengalami beberapa tahap pemugaran dan renovasi, dimulai dari bangunannya yang sederhana pada masa-masa awal Islam hingga dibangun kembali dan diperluas pada era modern sehingga menjadi masjid yang lengkap dengan berbagai fasilitas dan mampu menampung banyak jamaah. Keistimewaannya bersumber dari keterkaitannya dengan peristiwa perubahan arah kiblat, yang merupakan salah satu peristiwa terpenting dalam sejarah pensyariatan Islam dan sirah Nabi.',
    },
    'سقيفة بني ساعدة': {
      'en':
          'The Saqifah of Banu Sa\'idah is a well-known historical landmark in Al-Madinah Al-Munawwarah. It was a shaded shelter or roofed meeting place located in the settlement of Banu Sa\'idah from among the Ansar, northwest of the Prophet\'s Mosque, near Bi\'r Buda\'ah. It served as a gathering place where members of the tribe met to consult one another and manage their affairs, and its form resembled a shaded open pavilion or assembly place. The Saqifah gained its historical significance through its association with several major events, most notably the gathering of the Companions, may Allah be pleased with them, following the death of the Prophet ﷺ, where Abu Bakr al-Siddiq was pledged allegiance as the first Caliph of the Muslims. It is also reported that the Prophet ﷺ sat there on some occasions. Over time, the Saqifah disappeared in its original form because of urban development and changing conditions. Today, its location forms part of the historical area surrounding the Prophet\'s Mosque as part of the efforts to preserve the historic Islamic sites of Al-Madinah Al-Munawwarah.',
      'tr':
          'Benî Sâide Sakîfesi, Medine-i Münevvere\'nin tanınmış tarihî yapılarından biridir. Ensardan Benî Sâide yurdunun içinde, Nebevî Mescid\'in kuzeybatısında ve Bi\'r Budâa yakınında bulunan üstü örtülü bir gölgelik veya toplantı yeriydi. Kabile mensuplarının bir araya gelerek istişare ettiği ve işlerini görüştüğü bir mekân olarak kullanılırdı. Yapısı, gölgelikli açık bir çardak veya toplantı alanına benziyordu. Sakîfe, tarihî önemini birçok önemli olayla olan bağlantısından kazanmıştır. Bunların en önemlisi, Hz. Peygamber ﷺ\'in vefatının ardından sahâbelerin burada toplanarak Hz. Ebû Bekir es-Sıddîk\'a Müslümanların halifesi olarak biat etmeleridir. Ayrıca Hz. Peygamber ﷺ\'in bazı vesilelerle burada oturduğu da rivayet edilmiştir. Zaman içinde şehirleşme ve imar faaliyetleri nedeniyle Sakîfe özgün hâlini kaybetmiş, bulunduğu yer ise Nebevî Mescid\'i çevreleyen tarihî bölgenin bir parçası hâline gelmiş ve Medine\'deki tarihî İslamî mekânların korunmasına yönelik çalışmalar kapsamında muhafaza edilmektedir.',
      'id':
          'Saqifah Bani Sa\'idah merupakan salah satu situs bersejarah yang terkenal di Madinah. Saqifah ini berupa tempat berteduh atau balai beratap yang terletak di perkampungan Bani Sa\'idah dari kalangan Ansar, di sebelah barat laut Masjid Nabawi, dekat Sumur Buda\'ah. Tempat ini digunakan sebagai lokasi berkumpulnya anggota kabilah untuk bermusyawarah dan mengurus berbagai urusan mereka, dengan bentuk yang menyerupai balai terbuka yang beratap atau tempat pertemuan yang teduh. Saqifah memperoleh kedudukan sejarah yang sangat penting karena berkaitan dengan sejumlah peristiwa besar, terutama berkumpulnya para sahabat radhiyallahu \'anhum setelah wafatnya Nabi ﷺ, lalu membaiat Abu Bakar Ash-Shiddiq sebagai khalifah kaum Muslimin. Disebutkan pula bahwa Nabi ﷺ pernah duduk di tempat ini pada beberapa kesempatan. Seiring berjalannya waktu dan perubahan tata kota, Saqifah tidak lagi tersisa dalam bentuk aslinya. Kini lokasinya menjadi bagian dari kawasan bersejarah di sekitar Masjid Nabawi dalam rangka upaya pelestarian situs-situs bersejarah Islam di Madinah.',
    },
    'ثنية الوداع': {
      'en':
          'Thaniyat Al-Wada\' is one of the most famous historical landmarks in Al-Madinah Al-Munawwarah. It was an elevated mountain pass located on the northern side of the city near Mount Sala\', close to the roads leading out of Al-Madinah. Its name is associated with bidding farewell and welcoming, as it was the place where travelers and military expeditions departing from Al-Madinah were bid farewell, and where those returning were welcomed. For this reason, it became known since ancient times as Thaniyat Al-Wada\'. The site witnessed a number of important events in the Prophetic biography, including the Prophet Muhammad ﷺ bidding farewell to some military expeditions and welcoming those returning from battles. The pass consisted of a small rocky elevation overlooking the surrounding area. However, its original features disappeared as a result of modern urban expansion, and it was completely removed during the fourteenth century AH as part of regional development projects. Nevertheless, its significance remains rooted in its close association with the history of Al-Madinah Al-Munawwarah and the events of the Prophetic biography that took place there.',
      'tr':
          'Seniyyetü\'l-Vedâ, Medine-i Münevvere\'nin en meşhur tarihî simgelerinden biridir. Şehrin kuzey tarafında, Sel\' Dağı\'nın yakınında ve Medine dışına çıkan yolların civarında bulunan yüksek bir dağ geçidiydi. Adını uğurlama ve karşılama geleneğinden almıştır. Medine\'den ayrılan yolcular ve askerî birlikler burada uğurlanır, geri dönenler ise burada karşılanırdı. Bu sebeple çok eski dönemlerden beri "Seniyyetü\'l-Vedâ" adıyla tanınmıştır. Siyer-i Nebeviyye\'de önemli olaylara sahne olmuş; Hz. Peygamber ﷺ bazı seriyyeleri ve orduları buradan uğurlamış, gazvelerden dönenleri de burada karşılamıştır. Seniyye, çevresine hâkim küçük kayalık bir yükseltiden oluşuyordu. Ancak modern şehirleşme ve imar faaliyetleri sebebiyle özgün yapısı tamamen ortadan kalkmış ve hicrî on dördüncü yüzyılda bölgenin geliştirilmesine yönelik projeler kapsamında bütünüyle kaldırılmıştır. Buna rağmen önemi, Medine tarihine ve burada gerçekleşen Siyer-i Nebeviyye olaylarına olan güçlü bağlantısından kaynaklanmaya devam etmektedir.',
      'id':
          'Tsaniyatul Wada\' merupakan salah satu situs bersejarah yang paling terkenal di Madinah. Tempat ini adalah sebuah jalur pegunungan yang tinggi di bagian utara kota, dekat Gunung Sala\', tidak jauh dari jalan-jalan yang menuju ke luar Madinah. Namanya berkaitan dengan tradisi melepas dan menyambut, karena tempat ini digunakan untuk mengantar para musafir dan pasukan yang berangkat dari Madinah serta menyambut mereka ketika kembali. Oleh sebab itu, sejak dahulu tempat ini dikenal dengan nama Tsaniyatul Wada\'. Lokasi ini menjadi saksi sejumlah peristiwa penting dalam sirah Nabi, di antaranya Rasulullah ﷺ melepas beberapa sariyyah dan pasukan serta menyambut mereka yang kembali dari berbagai peperangan. Tsaniyah ini berupa sebuah ketinggian berbatu kecil yang menghadap ke wilayah sekitarnya. Akan tetapi, bentuk aslinya telah hilang akibat perluasan kawasan perkotaan modern, dan seluruh sisa-sisanya dihapuskan pada abad keempat belas Hijriah dalam rangka proyek pengembangan wilayah. Meskipun demikian, nilai sejarahnya tetap terjaga karena keterkaitannya yang erat dengan sejarah Madinah dan berbagai peristiwa dalam sirah Nabi yang terjadi di tempat tersebut.',
    },
    'بئر رومة': {
      'en':
          'Bi\'r Rumah, also known as the Well of Uthman, is one of the most famous historical landmarks in Al-Madinah Al-Munawwarah. It is located northwest of the Prophet\'s Mosque, near Wadi Al-Aqiq, in the Bi\'r Uthman district. It is considered one of the oldest wells in Al-Madinah and was among its sweetest sources of water during the time of the Prophet ﷺ. The Prophet ﷺ appreciated the quality of its water and drank from it. The well attained its historical significance when Uthman ibn Affan purchased it and dedicated it as a charitable endowment (waqf) for the Muslims in response to the Prophet\'s ﷺ encouragement to provide water for the people of Al-Madinah. It subsequently became one of the most renowned and enduring Islamic endowments. Throughout the centuries, the well experienced periods of neglect as well as restoration, and it remained a destination for historians and travelers, who described the sweetness of its water and its importance. Today, the well still stands as a historical witness to the role of the Islamic waqf in serving society and as one of the greatest virtues of Uthman ibn Affan, may Allah be pleased with him, in Al-Madinah Al-Munawwarah.',
      'tr':
          'Bi\'r Rûme, Osman Kuyusu adıyla da bilinen, Medine-i Münevvere\'nin en meşhur tarihî simgelerinden biridir. Nebevî Mescid\'in kuzeybatısında, Vadi el-Akik yakınındaki Bi\'r Osman mahallesinde yer alır. Medine\'nin en eski kuyularından biri olup, nübüvvet döneminde şehrin en tatlı su kaynaklarından biri olarak bilinirdi. Hz. Peygamber ﷺ bu kuyunun suyunu beğenir ve ondan içerdi. Kuyu, Hz. Osman bin Affân\'ın onu satın alarak, Hz. Peygamber ﷺ\'in Medine halkına su temin edilmesini teşvik etmesine uyarak Müslümanlara vakfetmesiyle tarihî önem kazanmıştır. Böylece İslam tarihinin en meşhur ve en etkili vakıflarından biri hâline gelmiştir. Asırlar boyunca kuyu zaman zaman ihmal edilmiş, zaman zaman da onarılmıştır. Bununla birlikte, suyunun tatlılığı ve önemi sebebiyle tarihçilerin ve seyyahların ziyaret ettiği bir yer olmaya devam etmiştir. Günümüzde de kuyu, İslam vakıf geleneğinin topluma hizmetteki rolünü ve Hz. Osman bin Affân\'ın Medine-i Münevvere\'deki en büyük faziletlerinden birini yansıtan tarihî bir şahit olarak varlığını sürdürmektedir.',
      'id':
          'Bi\'r Rumah, yang juga dikenal sebagai Sumur Utsman, merupakan salah satu situs bersejarah paling terkenal di Madinah. Sumur ini terletak di sebelah barat laut Masjid Nabawi, dekat Wadi Al-Aqiq, di kawasan Bi\'r Utsman. Sumur ini termasuk salah satu sumur tertua di Madinah dan merupakan salah satu sumber air paling jernih dan paling manis pada masa kenabian. Rasulullah ﷺ menyukai airnya dan meminum darinya. Sumur ini memperoleh kedudukan sejarah yang istimewa ketika Utsman bin Affan membelinya dan menjadikannya sebagai wakaf untuk kaum Muslimin sebagai tanggapan atas anjuran Rasulullah ﷺ agar menyediakan air bagi penduduk Madinah. Sejak saat itu, sumur ini menjadi salah satu wakaf Islam yang paling terkenal dan paling besar manfaatnya. Sepanjang berabad-abad, sumur ini mengalami masa-masa terbengkalai dan juga beberapa kali dipugar. Namun demikian, sumur ini tetap menjadi tujuan para sejarawan dan musafir yang menggambarkan kejernihan serta kemanisan airnya dan menjelaskan pentingnya. Hingga kini, sumur tersebut masih berdiri sebagai saksi sejarah atas peranan wakaf Islam dalam melayani masyarakat serta sebagai salah satu keutamaan terbesar Utsman bin Affan radhiyallahu \'anhu di Madinah.',
    },
    'مسجد قباء': {
      'en':
          'Quba Mosque is one of the most prominent Islamic landmarks in Al-Madinah Al-Munawwarah. It is located in the Quba district, southwest of the Prophet\'s Mosque. It is regarded as the first mosque established in Islam, having been built by the Prophet Muhammad ﷺ upon his arrival in Al-Madinah as a migrant. The Prophet ﷺ personally participated in determining its location and laying its first foundation stones. The mosque attained an eminent status in Islamic history because of its direct association with the beginning of the Madinan era, and the Prophet ﷺ regularly visited it and performed prayer there. Throughout the centuries, the mosque underwent numerous restoration and expansion projects, beginning in the early Islamic periods and continuing through the modern Saudi expansions, which transformed it into one of the largest historical mosques in Al-Madinah while preserving its original location. Today, the mosque continues to fulfill its religious and cultural role, and it is currently undergoing a comprehensive development and expansion project aimed at accommodating larger numbers of worshippers and revitalizing the surrounding historical sites, making it one of the most significant religious and historical destinations in Al-Madinah Al-Munawwarah.',
      'tr':
          'Kubâ Mescidi, Medine-i Münevvere\'nin en önemli İslâmî simgelerinden biridir. Nebevî Mescid\'in güneybatısındaki Kubâ semtinde yer alır. İslâm\'da kurulan ilk mescit kabul edilir. Hz. Peygamber ﷺ hicret sırasında Medine\'ye ulaştığında bu mescidi inşa etmiş, yerinin belirlenmesine ve ilk kerpiçlerinin konulmasına bizzat katılmıştır. Mescit, Medine döneminin başlangıcıyla doğrudan bağlantılı olması sebebiyle İslâm tarihinde büyük bir konuma sahiptir. Hz. Peygamber ﷺ burayı düzenli olarak ziyaret eder ve burada namaz kılardı. Asırlar boyunca mescit, ilk İslâm dönemlerinden başlayıp Suudi dönemindeki modern genişletmelere kadar birçok onarım ve büyütme çalışmasına sahne olmuş; böylece özgün konumu korunurken Medine\'nin en büyük tarihî mescitlerinden biri hâline gelmiştir. Günümüzde de dinî ve medenî görevini sürdürmekte olup, daha fazla ibadet edenin ağırlanmasını ve çevresindeki tarihî alanların ihyasını hedefleyen kapsamlı bir geliştirme ve genişletme projesi devam etmektedir. Bu yönüyle Medine-i Münevvere\'nin en önemli dinî ve tarihî ziyaret merkezlerinden biri olmayı sürdürmektedir.',
      'id':
          'Masjid Quba merupakan salah satu landmark Islam yang paling penting di Madinah. Masjid ini terletak di kawasan Quba, di sebelah barat daya Masjid Nabawi. Masjid ini dianggap sebagai masjid pertama yang didirikan dalam Islam, karena dibangun oleh Nabi Muhammad ﷺ ketika beliau tiba di Madinah setelah berhijrah. Rasulullah ﷺ sendiri turut menentukan lokasi masjid serta meletakkan batu-batu pertama pembangunannya. Masjid ini memiliki kedudukan yang sangat tinggi dalam sejarah Islam karena berkaitan langsung dengan awal periode Madinah, dan Rasulullah ﷺ senantiasa mengunjunginya serta melaksanakan salat di dalamnya secara rutin. Sepanjang sejarahnya, masjid ini telah mengalami berbagai tahap renovasi dan perluasan, mulai dari masa-masa awal Islam hingga proyek-proyek perluasan modern pada masa Kerajaan Arab Saudi, yang menjadikannya salah satu masjid bersejarah terbesar di Madinah dengan tetap mempertahankan lokasi aslinya. Hingga saat ini, Masjid Quba terus menjalankan perannya sebagai pusat ibadah dan peradaban, serta sedang mengalami proyek pengembangan dan perluasan menyeluruh yang bertujuan menampung jumlah jamaah yang lebih besar dan menghidupkan kembali situs-situs bersejarah di sekitarnya. Oleh karena itu, masjid ini tetap menjadi salah satu tujuan keagamaan dan sejarah terpenting di Madinah.',
    },
    'بئر العهن أو اليسيرة': {
      'en':
          'Bi\'r Al-\'Ahn, also known as Bi\'r Al-Yasirah, is one of the ancient historical wells of Al-Madinah Al-Munawwarah. It is located in the Al-\'Aliyah area, southeast of the Prophet\'s Mosque, near the Quba district. In earlier times, it was known as the Well of Banu Umayyah ibn Zayd of the Ansar, and it is believed that its name was derived either from al-\'ahn (colored wool) or from an orchard in the area that bore the same name. The well was renowned in the past for the abundance and sweetness of its water and was situated in the middle of a flourishing orchard. It is also associated with historical reports stating that the Prophet ﷺ passed by it, blessed its water, and named it "Al-Yasirah." Ownership of the well was transferred among several families and charitable endowments throughout the centuries, and it remained well known to the historians of Al-Madinah, although its location nearly disappeared for a period of time. Today, the well is abandoned and no longer in use. Only some of its ancient remains survive, yet it continues to represent one of the historical testimonies to the heritage of wells in Al-Madinah Al-Munawwarah.',
      'tr':
          'Bi\'rü\'l-\'Ahn veya Bi\'rü\'l-Yesîrah, Medine-i Münevvere\'nin eski tarihî kuyularından biridir. Nebevî Mescid\'in güneydoğusunda, Âliye bölgesinde, Kubâ Mahallesi\'nin yakınında yer alır. Eski dönemlerde Ensardan Benî Ümeyye b. Zeyd Kuyusu olarak bilinirdi. Adının, el-\'ahn (renkli yün) kelimesinden veya bölgede aynı adı taşıyan bir bahçeden geldiği rivayet edilmektedir. Geçmişte bol ve tatlı suyuyla tanınan kuyu, yemyeşil bir bahçenin ortasında bulunuyordu. Tarihî rivayetlerde Hz. Peygamber ﷺ\'in buradan geçtiği, suyunu bereketlendirdiği ve ona "el-Yesîrah" adını verdiği nakledilmektedir. Kuyu, yüzyıllar boyunca çeşitli ailelerin ve vakıfların mülkiyetine geçmiş; bir dönem yeri neredeyse unutulmuş olsa da Medine tarihçileri tarafından bilinmeye devam etmiştir. Günümüzde kuyu terk edilmiş ve kullanılmaz durumdadır. Eski yapısından yalnızca bazı kalıntılar günümüze ulaşmış olmakla birlikte, Medine-i Münevvere\'deki tarihî kuyular mirasının önemli tanıklarından biri olmayı sürdürmektedir.',
      'id':
          'Bi\'r Al-\'Ahn, yang juga dikenal sebagai Bi\'r Al-Yasirah, merupakan salah satu sumur bersejarah tertua di Madinah. Sumur ini terletak di kawasan Al-\'Aliyah, di sebelah tenggara Masjid Nabawi, dekat kawasan Quba. Pada masa dahulu, sumur ini dikenal sebagai Sumur Bani Umayyah bin Zaid dari kalangan Ansar. Diperkirakan namanya berasal dari kata al-\'ahn yang berarti wol berwarna, atau dari sebuah kebun di kawasan tersebut yang memiliki nama yang sama. Pada masa lalu, sumur ini terkenal karena airnya yang melimpah dan sangat jernih serta berada di tengah sebuah kebun yang subur. Sumur ini juga dikaitkan dengan beberapa riwayat sejarah yang menyebutkan bahwa Rasulullah ﷺ pernah melewatinya, memberkahi airnya, dan menamakannya "Al-Yasirah." Kepemilikan sumur ini berpindah di antara beberapa keluarga dan wakaf sepanjang berabad-abad. Meskipun lokasinya hampir terlupakan untuk beberapa waktu, sumur ini tetap dikenal oleh para sejarawan Madinah. Saat ini sumur tersebut telah ditinggalkan dan tidak lagi digunakan. Hanya sebagian kecil peninggalan lamanya yang masih tersisa, namun sumur ini tetap menjadi salah satu saksi sejarah penting atas warisan sumur-sumur bersejarah di Madinah.',
    },
    'جبل ذباب': {
      'en':
          'Mount Dhubab, also known as Jabal Al-Rayah (Banner Mountain), is a historical landmark located northwest of the Prophet\'s Mosque, close to Mount Sala\'. It is a small, circular rocky hill composed of black volcanic rocks and forms part of the geological formation of the Sala\' area. The mountain derives its historical importance from its close association with the Battle of the Trench (Al-Khandaq), during which the Prophet ﷺ used it as a vantage point to supervise the excavation of the trench. A tent was erected for him on its summit during the battle, and historical sources mention that the trench passed alongside the mountain. In later periods, Masjid Al-Rayah was built on its summit to commemorate these events, and the mosque remained standing throughout the centuries while undergoing several restorations and renovations. Today, urban development surrounds both the mountain and the mosque from most directions; nevertheless, they continue to be among the historical landmarks closely connected with the Prophetic biography and the history of Al-Madinah Al-Munawwarah.',
      'tr':
          'Cebelü Zübâb, diğer adıyla Cebelü\'r-Râye (Sancak Dağı), Nebevî Mescid\'in kuzeybatısında, Sel\' Dağı\'nın yakınında bulunan tarihî bir simgedir. Siyah volkanik kayalardan oluşan küçük, dairesel biçimli kayalık bir yükseltidir ve Sel\' bölgesinin jeolojik yapısının bir parçasını oluşturur. Dağ, tarihî önemini Hendek Gazvesi ile olan yakın ilişkisinden almıştır. Hz. Peygamber ﷺ hendek kazı çalışmalarını buradan takip etmiş, savaş sırasında kendisi için zirvesine bir çadır kurulmuş, ayrıca tarihî kaynaklarda hendeğin dağın yanından geçtiği belirtilmiştir. Daha sonraki dönemlerde bu olayların hatırasını yaşatmak amacıyla zirvesine Mescidü\'r-Râye inşa edilmiş, mescit asırlar boyunca çeşitli onarım ve yenilemeler görerek varlığını sürdürmüştür. Günümüzde dağ ve mescit büyük ölçüde şehirleşme ile çevrilmiş olmakla birlikte, her ikisi de Siyer-i Nebeviyye ve Medine-i Münevvere tarihiyle bağlantılı önemli tarihî eserler arasında yer almaya devam etmektedir.',
      'id':
          'Jabal Dhubab, yang juga dikenal sebagai Jabal Ar-Rayah (Gunung Panji), merupakan salah satu situs bersejarah yang terletak di sebelah barat laut Masjid Nabawi, dekat Gunung Sala\'. Gunung ini berupa bukit batu kecil berbentuk bulat yang tersusun dari batuan vulkanik hitam dan menjadi bagian dari formasi geologi kawasan Sala\'. Gunung ini memperoleh kedudukan sejarah karena kaitannya yang erat dengan Perang Khandaq, ketika Rasulullah ﷺ menjadikannya sebagai tempat untuk mengawasi pekerjaan penggalian parit. Sebuah kemah didirikan untuk beliau di atas puncaknya selama peperangan, dan sumber-sumber sejarah juga menyebutkan bahwa parit membentang di sepanjang sisi gunung tersebut. Pada masa-masa berikutnya, Masjid Ar-Rayah dibangun di puncaknya untuk mengenang peristiwa tersebut, dan masjid itu tetap berdiri selama berabad-abad meskipun telah beberapa kali dipugar dan direnovasi. Pada masa kini, kawasan perkotaan telah mengelilingi gunung dan masjid dari hampir semua sisi. Meskipun demikian, keduanya tetap menjadi salah satu situs bersejarah yang erat kaitannya dengan sirah Nabi Muhammad ﷺ dan sejarah Madinah.',
    },
    'جبل سلع': {
      'en':
          'Mount Sala\' is one of the most prominent natural and historical landmarks in Al-Madinah Al-Munawwarah. It is located northwest of the Prophet\'s Mosque, only a short distance away. The mountain is a large rocky formation composed of ancient granite outcrops and numerous ravines, and throughout history it has served as an important natural defensive barrier for the city. Its historical significance stems from its close association with the Battle of the Trench (Al-Khandaq), during which the Prophet Muhammad ﷺ chose it as a strategic position for leading the Muslim army, placing the mountain behind the Muslim forces and the trench in front of them, thereby taking advantage of its elevated position for observation and defense. The mountain also served as the location of the Muslim encampment and the place where the Prophet ﷺ stayed during the battle, contributing significantly to the defense of Al-Madinah against the Confederates (Al-Ahzab). Mount Sala\' contains several historical sites associated with the Prophetic biography, most notably the Mosques of Al-Fath, the cave traditionally associated with the Prophet\'s ﷺ stay during the battle, and its connection with the site of Thaniyat Al-Wada\'. Today, the mountain remains one of the most important historical landmarks in Al-Madinah and stands as a lasting witness to one of the greatest military events in Islamic history.',
      'tr':
          'Sel\' Dağı, Medine-i Münevvere\'nin en önemli doğal ve tarihî simgelerinden biridir. Nebevî Mescid\'in kuzeybatısında, ona kısa bir mesafede yer alır. Eski granit kaya oluşumlarından ve çok sayıda vadicikten meydana gelen büyük kayalık bir dağ olup, tarih boyunca Medine için önemli bir doğal savunma engeli oluşturmuştur. Dağın tarihî önemi, Hendek Gazvesi ile olan yakın bağlantısından kaynaklanmaktadır. Hz. Peygamber ﷺ Müslüman ordusunu yönetirken burayı stratejik bir merkez olarak seçmiş; dağı ordunun arkasına, hendeği ise önüne alarak yüksek konumundan gözetleme ve savunma amacıyla faydalanmıştır. Ayrıca dağ, savaş sırasında Müslümanların karargâhı ve Hz. Peygamber ﷺ\'in konakladığı yer olmuş, böylece Ahzâb ordularına karşı Medine\'nin savunulmasına önemli katkı sağlamıştır. Sel\' Dağı üzerinde Siyer-i Nebeviyye ile bağlantılı birçok tarihî eser bulunmaktadır. Bunların en önemlileri Fetih Mescitleri, Hz. Peygamber ﷺ\'in kaldığına nispet edilen mağara ve Seniyyetü\'l-Vedâ ile olan tarihî bağlantısıdır. Günümüzde Sel\' Dağı, İslâm tarihinin en önemli askerî olaylarından birine tanıklık eden ve Medine-i Münevvere\'nin en seçkin tarihî simgelerinden biri olmayı sürdürmektedir.',
      'id':
          'Jabal Sala\' merupakan salah satu landmark alam dan sejarah yang paling menonjol di Madinah. Gunung ini terletak di sebelah barat laut Masjid Nabawi dengan jarak yang tidak jauh darinya. Gunung ini berupa pegunungan batu besar yang tersusun dari formasi granit kuno dengan banyak lembah kecil, dan sepanjang sejarah menjadi benteng pertahanan alami yang sangat penting bagi kota Madinah. Nilai sejarahnya berasal dari keterkaitannya yang sangat erat dengan Perang Khandaq, ketika Rasulullah ﷺ menjadikannya sebagai posisi strategis untuk memimpin pasukan kaum Muslimin. Beliau menempatkan gunung di belakang pasukan dan parit di hadapan mereka, sehingga memanfaatkan posisinya yang tinggi untuk mengawasi keadaan serta mempertahankan kota. Gunung ini juga menjadi lokasi perkemahan kaum Muslimin dan tempat Rasulullah ﷺ bermalam selama peperangan, serta berperan besar dalam melindungi Madinah dari serangan pasukan Ahzab. Jabal Sala\' mencakup sejumlah situs bersejarah yang berkaitan dengan sirah Nabi, di antaranya Masjid-Masjid Al-Fath, gua yang dinisbatkan sebagai tempat Rasulullah ﷺ bermalam, serta keterkaitannya dengan lokasi Tsaniyatul Wada\'. Hingga kini, gunung ini tetap menjadi salah satu situs sejarah paling penting di Madinah dan menjadi saksi abadi atas salah satu peristiwa militer terbesar dalam sejarah Islam.',
    },
    'مسجد الغمامة': {
      'en':
          'Al-Ghamamah Mosque is located on the southwestern side of the Prophet\'s Mosque, near the Al-Manakhah area. It is one of the prominent historical sites where the Prophet Muhammad ﷺ performed the Eid prayers and the prayer for rain (Salat al-Istisqa\'). Originally, the site was an open prayer ground where these prayers were held before a mosque was later constructed on the location. The mosque derives its name from the event of the prayer for rain, during which it is reported that a cloud (ghamamah) shaded the Prophet ﷺ while he was praying. Thereafter, the site became widely known as Al-Ghamamah Mosque. The mosque was first built during the Umayyad period and subsequently underwent numerous restoration and renovation projects throughout the centuries, including during the Saudi era. Today, it remains a historical mosque with a rectangular architectural design, crowned with domes and a minaret, while preserving its original historical location as part of the network of Islamic landmarks surrounding the Prophet\'s Mosque.',
      'tr':
          'Mescidü\'l-Gamâme, Nebevî Mescid\'in güneybatısında, Menâha bölgesinin yakınında yer almaktadır. Hz. Peygamber ﷺ\'in bayram namazlarını ve yağmur duası namazını (İstiskâ) kıldığı önemli tarihî mekânlardan biridir. Burası başlangıçta açık bir namazgâh olup, daha sonra aynı yere bir mescit inşa edilmiştir. Mescit, yağmur duası sırasında Hz. Peygamber ﷺ namaz kılarken bir bulutun (gamâme) kendisini gölgelendirdiğinin rivayet edilmesi sebebiyle Mescidü\'l-Gamâme adıyla tanınmıştır. Mescit ilk defa Emevîler döneminde inşa edilmiş, ardından yüzyıllar boyunca çeşitli yenileme ve restorasyon çalışmaları görmüş, Suudi döneminde de kapsamlı şekilde korunmuştur. Günümüzde dikdörtgen planlı, kubbeleri ve minaresi bulunan tarihî bir mescit olarak varlığını sürdürmekte ve Nebevî Mescid çevresindeki İslâmî tarihî eserler bütününün önemli bir parçasını oluşturmaktadır.',
      'id':
          'Masjid Al-Ghamamah terletak di sebelah barat daya Masjid Nabawi, dekat kawasan Al-Manakhah. Masjid ini merupakan salah satu situs bersejarah terpenting tempat Rasulullah ﷺ melaksanakan salat Id dan salat istisqa\' (memohon hujan). Pada awalnya, lokasi ini hanyalah sebuah tanah lapang yang digunakan sebagai tempat pelaksanaan salat sebelum kemudian dibangun sebuah masjid di atasnya. Nama masjid ini berasal dari peristiwa salat istisqa\', ketika diriwayatkan bahwa sebuah awan (ghamamah) menaungi Rasulullah ﷺ saat beliau sedang melaksanakan salat. Sejak saat itu, tempat ini dikenal dengan nama Masjid Al-Ghamamah. Masjid ini pertama kali dibangun pada masa Dinasti Umayyah, kemudian mengalami berbagai tahap renovasi dan pemugaran sepanjang sejarah hingga masa Kerajaan Arab Saudi. Kini masjid tersebut tetap berdiri sebagai masjid bersejarah dengan bangunan berbentuk persegi panjang yang dilengkapi kubah-kubah dan sebuah menara, sambil tetap mempertahankan lokasi historisnya sebagai bagian dari rangkaian situs Islam bersejarah di sekitar Masjid Nabawi.',
    },
    'مسجد الفسح': {
      'en':
          'Al-Fasḥ Mosque is one of the small historical mosques in Al-Madinah Al-Munawwarah. It is situated at the foot of Mount Uhud, near Shiʿb Al-Jarrar, beneath the cave traditionally associated with the events of the Battle of Uhud. It did not have a specific name in the early historical sources; later it became known as Al-Fasḥ Mosque, and this name became widespread from the ninth century AH onward. It is also sometimes referred to as Uhud Mosque. The mosque is distinguished by its small size, its direct attachment to the mountain, its lack of a roof, and its square-shaped structure. Most of its original construction has collapsed, leaving only parts of its walls and the mihrab, and it is now enclosed by a protective fence to preserve it. It is believed to have been built during the early Islamic period, possibly during the governorship of ʿUmar ibn ʿAbd al-ʿAziz. Today, it remains an archaeological landmark closely associated with the biography of the Prophet ﷺ and the Battle of Uhud, serving as one of the historical monuments of Al-Madinah Al-Munawwarah.',
      'tr':
          'Mescidü\'l-Fasḥ, Medine-i Münevvere\'deki küçük tarihî mescitlerden biridir. Uhud Dağı\'nın eteğinde, Şiʿbü\'l-Cerrâr\'ın yakınında ve Uhud Gazvesi olaylarıyla ilişkilendirilen mağaranın altında yer almaktadır. İlk dönem kaynaklarında belirli bir adı bulunmamaktadır. Daha sonraki dönemlerde Mescidü\'l-Fasḥ adıyla tanınmış, bu isim hicrî dokuzuncu yüzyıldan itibaren yaygınlaşmıştır. Bazen Uhud Mescidi olarak da adlandırılır. Dağa bitişik olması, üzerinin açık bulunması ve kare planlı yapısıyla dikkat çeken küçük bir mescittir. Yapının büyük bölümü zamanla yıkılmış, günümüze yalnızca duvarlarının bir kısmı ile mihrabı ulaşmıştır. Tarihî yapıyı korumak amacıyla etrafı bir çitle çevrilmiştir. Erken İslâm döneminde, muhtemelen Ömer b. Abdülaziz devrinde inşa edildiği kabul edilmektedir. Günümüzde Hz. Peygamber ﷺ\'in sireti ve Uhud Gazvesi ile bağlantılı önemli bir tarihî eser olarak varlığını sürdürmekte ve Medine-i Münevvere\'nin tarihî mirasının önemli parçalarından biri kabul edilmektedir.',
      'id':
          'Masjid Al-Fasḥ merupakan salah satu masjid bersejarah berukuran kecil di Madinah. Masjid ini terletak di kaki Gunung Uhud, dekat Syiʿb Al-Jarrar, tepat di bawah gua yang dinisbatkan dengan peristiwa Perang Uhud. Pada sumber-sumber sejarah awal, masjid ini tidak memiliki nama tertentu. Kemudian pada masa berikutnya masjid ini dikenal dengan nama Masjid Al-Fasḥ, dan nama tersebut mulai tersebar luas sejak abad kesembilan Hijriah. Masjid ini juga terkadang disebut Masjid Uhud. Masjid ini memiliki ukuran yang kecil, menempel langsung pada lereng gunung, tidak beratap, dan berbentuk persegi. Sebagian besar bangunannya telah runtuh, sehingga yang tersisa hanyalah sebagian dinding serta mihrabnya. Kini lokasi tersebut dikelilingi pagar pelindung untuk menjaga sisa-sisa bangunan bersejarah itu. Diperkirakan masjid ini dibangun pada masa awal Islam, kemungkinan pada masa pemerintahan Umar bin Abdul Aziz. Hingga sekarang, masjid ini tetap menjadi salah satu situs arkeologi yang berkaitan erat dengan sirah Nabi Muhammad ﷺ dan Perang Uhud, serta menjadi salah satu peninggalan sejarah penting di Madinah.',
    },
    'جبل وعيرة': {
      'en':
          'Mount Wa\'irah is a rugged mountain range consisting of two sections, the Greater Wa\'irah and the Lesser Wa\'irah. It is located northeast of Mount Uhud and west of Al-Madinah Airport. The mountain is historically associated with the Prophetic biography because it lies behind the famous battlefield of the Battle of Uhud and forms part of the protected sanctuary (Haram) and inviolable boundary (Hima) of Al-Madinah Al-Munawwarah, whose sanctity was affirmed by the Prophet Muhammad ﷺ.',
      'tr':
          'Cebelü Vaʿîrah, biri büyük diğeri küçük olmak üzere iki bölümden oluşan sarp bir dağ silsilesidir. Uhud Dağı\'nın kuzeydoğusunda ve Medine Havalimanı\'nın batısında yer almaktadır. Bu dağ, meşhur Uhud Gazvesi meydanının arkasında bulunması ve Hz. Peygamber ﷺ tarafından kutsallığı belirtilen Medine-i Münevvere\'nin harem ve himâ sınırları içinde yer alması sebebiyle Siyer-i Nebeviyye ile tarihî bakımdan yakından ilişkilidir.',
      'id':
          'Jabal Wa\'irah merupakan rangkaian pegunungan yang terjal dan terdiri atas dua bagian, yaitu Wa\'irah Besar dan Wa\'irah Kecil. Gunung ini terletak di sebelah timur laut Gunung Uhud dan di sebelah barat Bandara Madinah. Gunung ini memiliki kaitan sejarah dengan sirah Nabi Muhammad ﷺ karena terletak di belakang medan Perang Uhud yang terkenal serta termasuk dalam kawasan hima dan haram Madinah yang disucikan oleh Rasulullah ﷺ.',
    },
    'حصن الضحيان': {
      'en':
          'Al-Duhayyan Fortress (the Black Utum) is a pre-Islamic fortress built of black stones by Uhayhah ibn Al-Julah in the Al-\'Usbah area, west of Quba Mosque, southwest of Al-Madinah Al-Munawwarah. It could be seen from great distances because of its height and its prominent position on the volcanic lava field (Harrah). It was rebuilt after its first structure had collapsed, this time using white stones. The fortress was distinguished by its elevated location and its commanding view over the surrounding area, making it an integral part of the ancient defensive system of Al-Madinah during the pre-Islamic period. It served as a defensive stronghold and as the residence of the chief of Banu Jahjaba. The fortress played a role in their conflicts with the tribes of Aws and Khazraj and became associated with several military incidents and historical accounts that illustrate its defensive function, including repelling attacks and providing refuge during times of conflict. Over the centuries, historians continued to mention the fortress in their writings. Some described it as a relatively large structure, measuring approximately 27 meters in length and 12 meters in width. However, it gradually deteriorated due to natural factors and urban expansion until today only its simple foundations and the mound on which it stood remain. Some associated features, such as an ancient adjacent well, have also survived. This fortress remains an important historical witness to the defensive system of Al-Madinah before Islam and to the tribal way of life and conflicts that characterized that period.',
      'tr':
          'Ed-Duhayyân (Kara Âtım), cahiliye dönemine ait siyah taşlardan yapılmış bir kaledir. Uhayha b. el-Cülâh tarafından, Medine-i Münevvere\'nin güneybatısında, Kubâ Mescidi\'nin batısındaki el-Usbe bölgesinde inşa edilmiştir. Yüksekliği ve volkanik lav arazisi (Harre) üzerindeki belirgin konumu sebebiyle uzak mesafelerden görülebiliyordu. İlk yapısı yıkıldıktan sonra bu kez beyaz taşlarla yeniden inşa edilmiştir. Kale, yüksek konumu ve çevreye hâkim olması sayesinde cahiliye döneminde Medine\'nin eski savunma sisteminin önemli bir parçasını oluşturmuştur. Benî Cahcebâ kabilesinin reisinin ikametgâhı ve savunma kalesi olarak kullanılmıştır. Evs ve Hazrec kabileleriyle yaşanan çatışmalarda önemli rol oynamış; saldırıların püskürtülmesi ve çatışmalar sırasında sığınılacak güvenli bir yer olması gibi askerî işlevlerini gösteren birçok tarihî olaya konu olmuştur. Tarihçiler yüzyıllar boyunca bu kaleden söz etmeye devam etmişlerdir. Bazıları yapının yaklaşık 27 metre uzunluğunda ve 12 metre genişliğinde büyükçe bir kale olduğunu belirtmiştir. Ancak doğal etkenler ve şehirleşme sebebiyle zamanla büyük ölçüde harap olmuş, günümüzde yalnızca temel kalıntıları ve bulunduğu tepecik kalmıştır. Yakınındaki eski kuyu gibi bazı tarihî izler ise günümüze ulaşmıştır. Bu âtım, İslam öncesi Medine\'nin savunma sistemi ile o dönemin kabile hayatı ve mücadelelerini yansıtan önemli tarihî şahitlerden biridir.',
      'id':
          'Benteng Ad-Duhayyan (Al-Atum Al-Aswad) merupakan sebuah benteng zaman jahiliah yang dibangun dari batu-batu hitam oleh Uhayhah bin Al-Julah di kawasan Al-\'Usbah, sebelah barat Masjid Quba, di barat daya Madinah. Benteng ini dapat terlihat dari kejauhan karena ketinggiannya dan posisinya yang menonjol di atas kawasan lava vulkanik (harrah). Setelah bangunan pertamanya runtuh, benteng ini dibangun kembali menggunakan batu-batu berwarna putih. Benteng ini memiliki posisi yang tinggi dan mengawasi wilayah di sekitarnya, sehingga menjadi bagian penting dari sistem pertahanan kuno Madinah pada masa jahiliah. Benteng ini digunakan sebagai benteng pertahanan sekaligus tempat tinggal pemimpin Bani Jahjaba. Benteng tersebut berperan dalam berbagai konflik mereka dengan suku Aus dan Khazraj, serta dikaitkan dengan sejumlah peperangan dan kisah sejarah yang menunjukkan fungsi militernya, termasuk menahan serangan musuh dan menjadi tempat berlindung ketika terjadi peperangan. Sepanjang sejarah, para sejarawan terus menyebut benteng ini dalam karya-karya mereka. Sebagian menggambarkannya sebagai bangunan yang cukup besar, dengan ukuran sekitar 27 meter panjang dan 12 meter lebar. Namun, benteng ini mengalami kerusakan secara bertahap akibat faktor alam dan perluasan kawasan perkotaan hingga saat ini yang tersisa hanyalah pondasi sederhana serta gundukan tempat benteng itu berdiri. Beberapa peninggalan lain, seperti sebuah sumur tua di dekatnya, masih tetap ada. Benteng ini menjadi salah satu saksi sejarah penting atas sistem pertahanan Madinah sebelum Islam serta kehidupan kesukuan dan berbagai konflik yang terjadi pada masa tersebut.',
    },
    'حصن راتج': {
      'en':
          'Ratij was an utum (ancient fortress) and one of the fortresses of Al-Madinah Al-Munawwarah. It was located northeast of Mount Dhubab, approximately in the Al-Masana\' area, and was among the defensive fortifications used by the tribes in ancient times to protect their settlements. Historical reports differ regarding its origin and ownership; however, it was associated with groups that inhabited the area during different periods, and it is believed to predate the complete Arab settlement there. Ratij played a role in the military events surrounding Al-Madinah, particularly during the Battle of the Trench (Al-Khandaq), as it lay within the area through which the trench passed. It was also later connected with the events of the Battle of Al-Harrah during the Umayyad period. Today, the fortress has completely disappeared, and no visible remains survive. Only its name has been preserved in historical sources as a testimony to the ancient defensive system of Al-Madinah Al-Munawwarah.',
      'tr':
          'Râtic, Medine-i Münevvere\'nin eski âtımlarından (kalelerinden) biriydi. Yaklaşık olarak Mesâniʿ bölgesinde, Cebelü Zübâb\'ın kuzeydoğusunda bulunuyordu ve eski dönemlerde kabilelerin yerleşimlerini savunmak amacıyla kullandıkları tahkimat yapılarından biriydi. Tarihî rivayetler, kalenin kökeni ve mülkiyeti konusunda farklı bilgiler vermektedir. Bununla birlikte, çeşitli dönemlerde bölgede yaşayan topluluklarla ilişkilendirilmiş olup, Arap yerleşiminin tam olarak gerçekleşmesinden daha eski olduğu düşünülmektedir. Râtic, Medine çevresindeki askerî olaylarda önemli bir rol oynamıştır. Özellikle Hendek Gazvesi sırasında hendeğin geçtiği bölgenin içinde yer almış, daha sonra ise Emevî dönemindeki Harre Vak\'ası ile ilişkilendirilmiştir. Günümüzde âtımdan hiçbir görünür iz kalmamıştır. Yalnızca adı, Medine-i Münevvere\'nin eski savunma sistemine tanıklık eden tarihî kaynaklarda yaşamaya devam etmektedir.',
      'id':
          'Ratij merupakan sebuah atum (benteng kuno) dan termasuk salah satu benteng bersejarah di Madinah. Benteng ini dahulu terletak di sebelah timur laut Jabal Dhubab, kira-kira di kawasan Al-Masana\', dan menjadi salah satu benteng pertahanan yang digunakan oleh berbagai kabilah pada masa lampau untuk melindungi permukiman mereka. Riwayat-riwayat sejarah berbeda pendapat mengenai asal-usul dan kepemilikannya. Namun demikian, benteng ini dikaitkan dengan kelompok-kelompok yang mendiami kawasan tersebut pada berbagai masa, dan diperkirakan usianya lebih tua daripada masa pemukiman Arab secara menyeluruh di wilayah itu. Ratij memiliki peranan dalam berbagai peristiwa militer di sekitar Madinah, terutama pada Perang Khandaq, karena berada dalam kawasan yang dilalui parit pertahanan. Benteng ini juga kemudian dikaitkan dengan peristiwa Perang Al-Harrah pada masa Dinasti Umayyah. Kini benteng tersebut telah hilang sepenuhnya dan tidak ada lagi sisa bangunan yang tampak. Yang tersisa hanyalah namanya dalam sumber-sumber sejarah sebagai saksi atas sistem pertahanan kuno Madinah.',
    },
    'حرة الوبرة': {
      'en':
          'Harrah Al-Wabarah is one of the black volcanic lava fields surrounding Al-Madinah Al-Munawwarah. It lies on the western side of the city, approximately three miles from the Prophet\'s Mosque, extending from the southern part of Al-Madinah near Quba to its northern side near Qiblatain Mosque. It forms one of the two volcanic lava fields (al-labatayn) that surround Al-Madinah. The Harrah is characterized by volcanic terrain consisting of hills, depressions, fissures, and valleys where rainwater collects, making some of its areas suitable for settlement in ancient times. Today, most of its land has been reclaimed and incorporated into the urban area of the city. This Harrah derives its historical and religious significance from being one of the boundaries of the sacred precinct (Haram) of Al-Madinah Al-Munawwarah and from its association with a number of events in the Prophetic biography. It also contains several prominent landmarks, including Qiblatain Mosque, the area of Banu Salamah, and a number of historic wells and sites, making it one of the most important geographical and historical landmarks of Al-Madinah Al-Munawwarah.',
      'tr':
          'Harretü\'l-Vebere, Medine-i Münevvere\'yi çevreleyen siyah volkanik lav sahalarından biridir. Şehrin batısında, Nebevî Mescid\'e yaklaşık üç mil uzaklıkta yer almakta olup, güneyde Kubâ\'dan başlayarak kuzeyde Mescidü\'l-Kıbleteyn\'e kadar uzanır. Medine\'yi çevreleyen iki büyük lav sahasından (el-Lâbeteyn) birini oluşturur. Harre; volkanik tepeler, çöküntüler, yarıklar ve yağmur sularının toplandığı vadilerden oluşan engebeli bir araziye sahiptir. Bu özellikleri sayesinde bazı bölgeleri eski dönemlerde yerleşime elverişli olmuş, günümüzde ise arazisinin büyük bölümü ıslah edilerek şehirleşme alanına dâhil edilmiştir. Bu harre, Medine-i Münevvere Harem sınırlarının bir parçasını oluşturması ve Siyer-i Nebeviyye\'deki birçok olayla bağlantılı olması sebebiyle tarihî ve dinî önem taşımaktadır. Ayrıca Mescidü\'l-Kıbleteyn, Benî Seleme bölgesi ile birçok tarihî kuyu ve önemli mekânı bünyesinde barındırması sayesinde Medine-i Münevvere\'nin en önemli coğrafî ve tarihî simgelerinden biri kabul edilmektedir.',
      'id':
          'Harrah Al-Wabarah merupakan salah satu hamparan lava vulkanik hitam yang mengelilingi Madinah. Harrah ini terletak di sebelah barat kota, sekitar tiga mil dari Masjid Nabawi, membentang dari kawasan Quba di bagian selatan hingga Masjid Qiblatain di bagian utara, serta menjadi salah satu dari dua kawasan lava (al-labatayn) yang mengelilingi Madinah. Harrah ini memiliki bentang alam vulkanik yang terdiri atas bukit-bukit, cekungan, retakan, dan lembah-lembah tempat berkumpulnya air hujan, sehingga sebagian kawasannya layak dihuni sejak masa lampau. Pada masa kini, sebagian besar lahannya telah direklamasi dan menjadi bagian dari kawasan perkotaan Madinah. Harrah ini memiliki nilai sejarah dan keagamaan karena merupakan salah satu batas Tanah Haram Madinah, serta berkaitan dengan sejumlah peristiwa dalam sirah Nabi Muhammad ﷺ. Selain itu, kawasan ini mencakup sejumlah situs penting seperti Masjid Qiblatain, wilayah Bani Salamah, serta berbagai sumur dan lokasi bersejarah lainnya, sehingga menjadikannya salah satu landmark geografis dan historis terpenting di Madinah.',
    },
    'أطم صرار': {
      'en':
          'Sirar is an ancient fortress located to the east of Al-Madinah Al-Munawwarah. The fortress was built from the black volcanic stones of the Harrah on a prominent elevation rising above the surrounding land. It was one of the fortresses of Banu Abd al-Ashhal during the pre-Islamic period. After the Prophet\'s migration (Hijrah), it became associated with several important historical events. The Prophet Muhammad ﷺ stayed there during some of his military expeditions, and historical reports also mention events connected with the Companions, including Umar ibn Al-Khattab, may Allah be pleased with him, during the preparation of Muslim armies, in addition to other events that took place during the early Islamic period.',
      'tr':
          'Sırâr, Medine-i Münevvere\'nin doğusunda bulunan eski bir kaledir. Bu âtım, Harre\'nin siyah volkanik taşlarından, çevresine hâkim yüksek bir tepe üzerine inşa edilmiştir. Cahiliye döneminde Benî Abdüleşhel kabilesinin kalelerinden biriydi. Hicretten sonra ise birçok önemli tarihî olayla ilişkilendirilmiştir. Hz. Peygamber ﷺ bazı gazveleri sırasında burada konaklamış, ayrıca Hz. Ömer b. Hattâb\'ın, Allah ondan razı olsun, orduların hazırlanmasıyla ilgili bazı faaliyetleri de dâhil olmak üzere sahâbelerle ilgili çeşitli olaylar burada meydana gelmiştir. Bunun yanında, İslâm\'ın ilk dönemlerine ait başka tarihî hadiseler de bu kale ile ilişkilendirilmektedir.',
      'id':
          'Sirar merupakan sebuah benteng kuno yang terletak di sebelah timur Madinah. Benteng ini dibangun dari batu-batu lava hitam kawasan Harrah di atas sebuah dataran tinggi yang menonjol dari wilayah sekitarnya. Benteng ini merupakan salah satu benteng milik Bani Abd al-Ashhal pada masa jahiliah. Setelah hijrah Nabi Muhammad ﷺ, benteng ini dikaitkan dengan sejumlah peristiwa penting dalam sejarah Islam. Rasulullah ﷺ pernah singgah di tempat ini dalam beberapa peperangan beliau. Selain itu, terdapat riwayat mengenai berbagai peristiwa yang berkaitan dengan para sahabat, di antaranya Umar bin Al-Khattab radhiyallahu \'anhu ketika mempersiapkan pasukan kaum Muslimin, serta beberapa peristiwa lain yang terjadi pada masa awal Islam.',
    },
    'ذات الجيش': {
      'en':
          'Dhat Al-Jaysh is a historical site located southwest of Al-Madinah Al-Munawwarah, beyond Dhu Al-Hulayfah on the old road leading to Makkah. It is a broad valley and open plain through which caravans used to pass. It is regarded as one of the well-known ancient stopping places on the travel route between Makkah and Al-Madinah. The site is mentioned in a number of historical accounts connected with the Prophetic biography, and it also served as one of the stations and resting places for caravans and travelers along the route.',
      'tr':
          'Zâtü\'l-Ceyş, Medine-i Münevvere\'nin güneybatısında, Zülhuleyfe\'den sonra eski Mekke yolu üzerinde bulunan tarihî bir mevkidir. Kervanların geçtiği geniş bir vadi ve düz ovadan oluşmaktadır. Mekke ile Medine arasındaki eski yol üzerindeki tanınmış konak yerlerinden biri kabul edilmektedir. Bu yer, Siyer-i Nebeviyye ile bağlantılı birçok tarihî rivayette zikredilmiş olup, aynı zamanda kervanlar ve yolcular için yol üzerindeki konaklama ve dinlenme duraklarından biri olarak kullanılmıştır.',
      'id':
          'Dzat Al-Jaisy merupakan sebuah lokasi bersejarah yang terletak di sebelah barat daya Madinah, setelah Dzul Hulaifah di jalur lama menuju Makkah. Tempat ini berupa sebuah lembah yang luas dan dataran terbuka yang dahulu dilalui oleh kafilah-kafilah. Lokasi ini termasuk salah satu tempat persinggahan kuno yang terkenal di jalur perjalanan antara Makkah dan Madinah. Tempat ini disebutkan dalam sejumlah riwayat sejarah yang berkaitan dengan sirah Nabi Muhammad ﷺ, serta menjadi salah satu titik persinggahan dan tempat beristirahat bagi para kafilah dan musafir yang menempuh perjalanan di jalur tersebut.',
    },
    'حرة واقم': {
      'en':
          'Harrah Waqim (the Eastern Harrah) is a vast volcanic lava field located to the east of Al-Madinah Al-Munawwarah. It extends from the area of Wadi Buthan in the north to the outskirts of Mount Uhud and the eastern approaches of the city. It was named Waqim after Utum Waqim, one of the ancient fortresses in the area, and is also known by several local names associated with the tribes that inhabited its surroundings. The Harrah consists of black volcanic rocks and lava flows that give its surface a rugged and harsh character. It is one of the two great lava fields surrounding Al-Madinah and forms a natural defensive barrier on its eastern side. The area includes several valleys and mountains, such as Wadi Buthan, Wadi Al-Aqiq, and Mount Uhud, and was inhabited in ancient times by tribes of Aws, Khazraj, and several Jewish tribes. Harrah Waqim is closely associated with important historical events, as it forms part of the sacred boundary (Haram) of Al-Madinah Al-Munawwarah and witnessed significant events in Islamic history. It was also known for its volcanic activity during various historical periods. Today, much of the Harrah has become integrated into the urban expansion of Al-Madinah Al-Munawwarah.',
      'tr':
          'Harretü Vâkım (Doğu Harresi), Medine-i Münevvere\'nin doğusunda yer alan geniş bir volkanik lav sahasıdır. Kuzeyde Vadi Buthân\'dan başlayarak Uhud Dağı eteklerine ve şehrin doğu kesimlerine kadar uzanır. Harre, adını bölgedeki eski kalelerden biri olan Âtım Vâkım\'dan almıştır. Ayrıca çevresinde yaşayan kabilelere nispetle farklı adlarla da anılmıştır. Bölge, yüzeyini sert ve engebeli hâle getiren siyah volkanik kayaçlar ve lav akıntılarından oluşur. Medine\'yi çevreleyen iki büyük lav sahasından biri olup şehrin doğu tarafında doğal bir savunma hattı meydana getirir. Harre içerisinde Vadi Buthân, Vadi Akīk ve Uhud Dağı gibi önemli vadiler ve dağlar yer almakta; eski dönemlerde Evs, Hazrec ve bazı Yahudi kabileleri burada yaşamıştır. Harretü Vâkım, Medine-i Münevvere Harem sınırlarının bir parçasını oluşturması ve İslam tarihindeki önemli olaylara sahne olması sebebiyle büyük tarihî öneme sahiptir. Ayrıca çeşitli dönemlerde meydana gelen volkanik faaliyetleriyle de tanınmıştır. Günümüzde ise şehrin genişlemesiyle birlikte büyük ölçüde Medine\'nin yerleşim alanı içine dâhil olmuştur.',
      'id':
          'Harrah Waqim (Harrah Timur) merupakan kawasan lava vulkanik yang sangat luas di sebelah timur Madinah. Kawasan ini membentang dari Wadi Buthan di bagian utara hingga kaki Gunung Uhud dan wilayah timur kota. Harrah ini dinamai Waqim karena dinisbatkan kepada Atum Waqim, salah satu benteng kuno yang berada di kawasan tersebut. Kawasan ini juga dikenal dengan beberapa nama lain sesuai dengan suku-suku yang dahulu mendiami daerah sekitarnya. Harrah ini tersusun dari batuan dan aliran lava vulkanik berwarna hitam yang menjadikan permukaannya keras dan terjal. Kawasan ini merupakan salah satu dari dua hamparan lava besar yang mengelilingi Madinah dan berfungsi sebagai benteng pertahanan alami di sisi timur kota. Di dalamnya terdapat sejumlah lembah dan gunung, seperti Wadi Buthan, Wadi Al-Aqiq, dan Gunung Uhud. Pada masa lampau kawasan ini dihuni oleh suku Aus, Khazraj, dan beberapa kabilah Yahudi. Harrah Waqim memiliki nilai sejarah yang sangat penting karena termasuk dalam batas Tanah Haram Madinah serta menjadi saksi berbagai peristiwa penting dalam sejarah Islam. Kawasan ini juga dikenal pernah mengalami aktivitas vulkanik pada beberapa periode sejarah. Pada masa kini, sebagian besar wilayahnya telah menjadi bagian dari perluasan kawasan perkotaan Madinah.',
    },
    'روضة خاخ': {
      'en':
          'Khakh (Rawdat Khakh) is a site located between Makkah and Al-Madinah, near Wadi Al-Aqiq and Hamra\' Al-Asad. It is a well-known meadow distinguished by its abundant water and lush vegetation, and it was one of the stopping places along the travel route between the two cities. The most notable event associated with it in the Prophetic biography is that the Prophet ﷺ sent Ali ibn Abi Talib, Al-Zubayr ibn Al-Awwam, and Al-Miqdad ibn Al-Aswad to this location, where they found a woman carrying a concealed letter. They seized the letter and brought it to the Prophet ﷺ. It proved to be a message from Hatib ibn Abi Balta\'ah to the people of Makkah informing them of some of the Prophet\'s ﷺ plans. This incident is well known in the books of Hadith and the Prophetic biography as the Incident of Hatib\'s Letter.',
      'tr':
          'Hâh (Ravzatü Hâh), Mekke ile Medine arasında, Vadi Akīk ve Hamrâü\'l-Esed yakınlarında bulunan bir yerdir. Bol suyu ve yeşilliğiyle tanınan meşhur bir çayırlık olup, iki şehir arasındaki yolculuk güzergâhındaki konak yerlerinden biriydi. Siyer-i Nebeviyye\'de bu yerle ilgili en önemli olay, Hz. Peygamber ﷺ\'in Ali b. Ebû Tâlib, Zübeyr b. Avvâm ve Mikdâd b. Esved\'i buraya göndermesidir. Onlar burada yanında gizlenmiş bir mektup bulunan bir kadınla karşılaşmış, mektubu alarak Hz. Peygamber ﷺ\'e getirmişlerdir. Mektubun, Hâtıb b. Ebû Beltea tarafından Mekkelilere yazıldığı ve onlara Hz. Peygamber ﷺ\'in bazı hazırlıkları hakkında bilgi verdiği anlaşılmıştır. Bu olay hadis ve siyer kaynaklarında Hâtıb b. Ebû Beltea\'nın Mektubu Olayı olarak meşhur olmuştur.',
      'id':
          'Khakh (Raudhat Khakh) merupakan sebuah lokasi yang terletak di antara Makkah dan Madinah, dekat Wadi Al-Aqiq dan Hamra\' Al-Asad. Tempat ini adalah sebuah padang rumput yang terkenal karena kelimpahan air dan kehijauannya, serta menjadi salah satu persinggahan di jalur perjalanan antara kedua kota tersebut. Peristiwa paling terkenal yang berkaitan dengannya dalam sirah Nabi adalah ketika Rasulullah ﷺ mengutus Ali bin Abi Thalib, Az-Zubair bin Al-Awwam, dan Al-Miqdad bin Al-Aswad ke tempat ini. Mereka menemukan seorang wanita yang membawa sebuah surat yang disembunyikan, lalu mengambil surat tersebut dan membawanya kepada Rasulullah ﷺ. Ternyata surat itu berasal dari Hatib bin Abi Balta\'ah yang ditujukan kepada penduduk Makkah untuk memberitahukan sebagian rencana Rasulullah ﷺ. Peristiwa ini dikenal dalam kitab-kitab hadis dan sirah dengan nama Peristiwa Surat Hatib bin Abi Balta\'ah.',
    },
    'مسجد بني دينار الأدنى': {
      'en':
          'Banu Dinar Mosque is one of the historical mosques in the southern part of Al-Madinah Al-Munawwarah. It is located west of Wadi Buthan in the Al-Mughaysilah (Al-Malihah) area, approximately one kilometer from the Prophet\'s Mosque. The mosque is attributed to Banu Dinar of the Khazraj tribe, who lived in that area, where it served as the location of their dwellings and one of their ancient mosques. The mosque is associated with the Prophetic biography because it is one of the places where the Prophet ﷺ performed prayer. It was therefore built on the site where he prayed, and it continued to be known throughout the centuries. It was rebuilt during the governorship of Caliph Umar ibn Abd al-Aziz when he was governor of Al-Madinah. The mosque preserved its historical character through successive periods despite repeated renovations, until it was eventually removed and a modern mosque was built beside it at the same location. The new mosque was first known as Al-Mughaysilah Mosque and later as Al-Malihah Mosque. The mosque represents one of the landmarks associated with the history of Al-Madinah Al-Munawwarah and one of the locations where the Prophet ﷺ prayed, whose memory has remained preserved throughout history.',
      'tr':
          'Benî Dînâr Mescidi, Medine-i Münevvere\'nin güneyindeki tarihî mescitlerden biridir. Nebevî Mescid\'e yaklaşık bir kilometre uzaklıkta, Vadi Buthân\'ın batısında, el-Muğaysile (el-Mâliha) bölgesinde yer almaktadır. Mescit, bu bölgede yaşayan ve burada evleri ile eski mescitlerinden biri bulunan Hazrec kabilesine mensup Benî Dînâr\'a nispet edilmektedir. Mescit, Hz. Peygamber ﷺ\'in namaz kıldığı yerlerden biri olması sebebiyle Siyer-i Nebeviyye ile bağlantılıdır. Bu nedenle onun namaz kıldığı yerde inşa edilmiş, ardından asırlar boyunca bilinmeye devam etmiştir. Daha sonra Halife Ömer b. Abdülaziz\'in Medine valiliği sırasında yeniden inşa edilmiştir. Mescit, ardı ardına yapılan yenilemelere rağmen tarihî kimliğini uzun süre korumuş, daha sonra kaldırılarak aynı yerde yakınına modern bir mescit yapılmıştır. Bu mescit önce Mescidü\'l-Muğaysile, daha sonra ise Mescidü\'l-Mâliha adıyla tanınmıştır. Bu mescit, Medine tarihine bağlı önemli tarihî eserlerden biri ve Hz. Peygamber ﷺ\'in namaz kıldığı mekânlardan biri olarak tarihî hafızadaki yerini korumaktadır.',
      'id':
          'Masjid Bani Dinar merupakan salah satu masjid bersejarah di bagian selatan Madinah. Masjid ini terletak di sebelah barat Wadi Buthan, di kawasan Al-Mughaysilah (Al-Malihah), sekitar satu kilometer dari Masjid Nabawi. Masjid ini dinisbatkan kepada Bani Dinar dari kabilah Khazraj yang dahulu menetap di kawasan tersebut, yang menjadi lokasi permukiman mereka sekaligus salah satu masjid lama mereka. Masjid ini berkaitan dengan sirah Nabi Muhammad ﷺ karena merupakan salah satu tempat yang pernah digunakan Rasulullah ﷺ untuk melaksanakan salat. Oleh sebab itu, masjid ini dibangun di lokasi tempat beliau salat dan tetap dikenal sepanjang berbagai masa. Masjid ini kemudian dibangun kembali pada masa Khalifah Umar bin Abdul Aziz ketika beliau menjabat sebagai gubernur Madinah. Masjid tersebut mempertahankan karakter sejarahnya selama beberapa periode meskipun mengalami berbagai renovasi, hingga akhirnya dibongkar dan dibangun sebuah masjid modern di samping lokasi yang sama. Masjid baru itu mula-mula dikenal sebagai Masjid Al-Mughaysilah, kemudian dikenal dengan nama Masjid Al-Malihah. Masjid ini merupakan salah satu situs yang berkaitan dengan sejarah Madinah serta salah satu tempat salat Rasulullah ﷺ yang tetap terpelihara dalam ingatan sejarah.',
    },
    'زغابة': {
      'en':
          'Zughabah is a historical site near Al-Madinah Al-Munawwarah, located at the confluence of floodwaters at the end of Wadi Al-Aqiq to the west of the city, where the waters of Wadi Buthan, Wadi Qanat, and Wadi Al-Aqiq meet. It is regarded as one of the most prominent flood channels in the region. The site has retained the name Zughabah continuously since the time of the Prophet ﷺ.',
      'tr':
          'Zuğâbe, Medine-i Münevvere yakınlarında bulunan tarihî bir yerdir. Şehrin batısında, Vadi Akīk\'ın sonunda, sel sularının birleştiği noktada yer almakta olup, burada Vadi Buthân, Vadi Kanât ve Vadi Akīk\'ın suları birleşmektedir. Bölgenin en önemli sel yataklarından biri kabul edilmektedir. Bu yer, Hz. Peygamber ﷺ döneminden günümüze kadar Zuğâbe adını korumuştur.',
      'id':
          'Zughabah merupakan sebuah lokasi bersejarah yang terletak di dekat Madinah, pada pertemuan aliran banjir di ujung Wadi Al-Aqiq di sebelah barat kota, tempat bertemunya aliran Wadi Buthan, Wadi Qanat, dan Wadi Al-Aqiq. Lokasi ini termasuk salah satu jalur aliran banjir yang paling penting di kawasan tersebut. Tempat ini tetap mempertahankan nama Zughabah sejak masa Nabi Muhammad ﷺ hingga sekarang.',
    },
    'الغابة أرض الزبير بن العوام': {
      'en':
          'Al-Ghabah is a place located north of Al-Madinah Al-Munawwarah. It was given this name because of its abundance of trees and water. It extends through the Al-Khalil area, where some of the valleys of Al-Madinah converge. In the past, it was a fertile land rich in palm trees and agriculture, and it was among the properties of the Companion Al-Zubayr ibn Al-Awwam, who developed and cultivated it, thereby increasing its value. Over time, its agricultural activity declined, and it fell into neglect as floods carved channels through it and produced dense thickets. During the era of the Kingdom of Saudi Arabia, however, modern development revived the area, which now includes roads, farms, and residential neighborhoods, encompassing the Al-Khalil area and its surroundings. Al-Ghabah also holds historical significance during the Prophetic era. It served as one of the grazing grounds for the Prophet\'s ﷺ camels, and several horse races supervised by him started from there. It is also associated with the Expedition of Dhi Qard. In addition, a number of prominent Companions, including Al-Abbas ibn Abd al-Muttalib, may Allah be pleased with him, owned lands and farms there because of its abundant water resources and fertile soil.',
      'tr':
          'el-Gâbe, Medine-i Münevvere\'nin kuzeyinde bulunan bir bölgedir. Bol ağaçları ve suları sebebiyle bu isimle anılmıştır. Medine vadilerinden bazılarının birleştiği el-Halîl bölgesine kadar uzanır. Geçmişte hurma bahçeleri ve tarımıyla meşhur verimli bir araziydi. Sahâbî Zübeyr b. Avvâm\'ın mülklerinden biri olup, onu değerlendirip geliştirmesi sayesinde değeri daha da artmıştır. Zamanla tarımsal faaliyetler azalmış, sellerin açtığı yarıntılar ve sık çalılıkların oluşması sebebiyle bölge ihmal edilmiştir. Daha sonra Suudi Arabistan Krallığı döneminde yeniden canlandırılmış; yolları, çiftlikleri ve yerleşim alanlarıyla birlikte el-Halîl ve çevresini kapsayan gelişmiş bir bölge hâline gelmiştir. el-Gâbe\'nin Nebevî dönemde de tarihî önemi vardır. Burası Hz. Peygamber ﷺ\'in develerinin otlatıldığı yerlerden biriydi ve onun gözetiminde yapılan bazı at yarışları buradan başlamıştır. Ayrıca Zî Kard Gazvesi ile de ilişkilidir. Bunun yanında, suyun bolluğu ve toprağın verimliliği sebebiyle Abbâs b. Abdülmuttalib\'in, Allah ondan razı olsun, da aralarında bulunduğu bazı büyük sahâbîlerin burada arazileri ve çiftlikleri bulunuyordu.',
      'id':
          'Al-Ghabah merupakan sebuah kawasan yang terletak di sebelah utara Madinah. Kawasan ini dinamakan demikian karena banyaknya pepohonan dan sumber air yang dimilikinya. Wilayah ini membentang hingga kawasan Al-Khalil, tempat bertemunya beberapa lembah Madinah. Pada masa dahulu, Al-Ghabah merupakan tanah yang subur, kaya akan pohon kurma dan lahan pertanian. Kawasan ini termasuk salah satu milik sahabat Az-Zubair bin Al-Awwam, yang mengelola dan mengembangkannya sehingga nilainya semakin meningkat. Seiring berjalannya waktu, kegiatan pertaniannya menurun dan kawasan tersebut mengalami keterlantaran akibat banjir yang membentuk parit-parit serta semak belukar yang lebat. Namun, pada masa Kerajaan Arab Saudi, kawasan ini kembali berkembang dan kini mencakup jalan-jalan, lahan pertanian, serta permukiman, termasuk kawasan Al-Khalil dan sekitarnya. Al-Ghabah juga memiliki arti penting dalam masa kenabian. Tempat ini merupakan salah satu padang penggembalaan unta milik Rasulullah ﷺ, dan dari sinilah beberapa perlombaan kuda yang beliau awasi dimulai. Kawasan ini juga berkaitan dengan Perang Dzi Qard. Selain itu, beberapa sahabat terkemuka, di antaranya Al-Abbas bin Abdul Muththalib radhiyallahu \'anhu, memiliki tanah dan kebun di kawasan ini karena melimpahnya sumber air serta kesuburan tanahnya.',
    },
    'مسجد بني دينار الأعلى': {
      'en':
          'Upper Banu Dinar Mosque is one of the historical mosques in Al-Madinah Al-Munawwarah. It is located in the area of Banu Dinar to the south of the Prophet\'s Mosque and is distinguished from the Lower Banu Dinar Mosque by its location. The mosque is attributed to Banu Dinar, a branch of the Khazraj tribe whose dwellings were situated in this area. It is one of the mosques in which the Prophet Muhammad ﷺ prayed, and it was built on the site where he performed prayer. The mosque remained well known in historical sources and was rebuilt during the governorship of Umar ibn Abd al-Aziz over Al-Madinah. It underwent several restorations throughout the succeeding centuries while preserving its historical identity. Although the original structure has disappeared as a result of urban expansion, the site continues to be associated with the memory of one of the places where the Prophet ﷺ prayed, making it one of the historical landmarks connected with the Prophetic biography in Al-Madinah Al-Munawwarah.',
      'tr':
          'Yukarı Benî Dînâr Mescidi, Medine-i Münevvere\'nin tarihî mescitlerinden biridir. Nebevî Mescid\'in güneyindeki Benî Dînâr bölgesinde yer almakta olup, bulunduğu konum sebebiyle Aşağı Benî Dînâr Mescidi\'nden ayrılmaktadır. Mescit, Hazrec kabilesinin bir kolu olan ve bu bölgede yaşayan Benî Dînâr\'a nispet edilmektedir. Hz. Peygamber ﷺ\'in namaz kıldığı mescitlerden biri olup, onun namaz kıldığı yere inşa edilmiştir. Tarihî kaynaklarda varlığını koruyan mescit, Ömer b. Abdülaziz\'in Medine valiliği döneminde yeniden inşa edilmiş, sonraki yüzyıllarda da çeşitli onarımlar görerek tarihî kimliğini muhafaza etmiştir. Her ne kadar aslî yapısı şehirleşme sebebiyle ortadan kalkmış olsa da, bulunduğu yer Hz. Peygamber ﷺ\'in namaz kıldığı mekânlardan biri olarak hatırlanmaya devam etmekte ve Medine-i Münevvere\'deki Siyer-i Nebeviyye ile bağlantılı tarihî eserlerden biri sayılmaktadır.',
      'id':
          'Masjid Bani Dinar Atas merupakan salah satu masjid bersejarah di Madinah. Masjid ini terletak di kawasan Bani Dinar di sebelah selatan Masjid Nabawi, dan dibedakan dari Masjid Bani Dinar Bawah berdasarkan letaknya. Masjid ini dinisbatkan kepada Bani Dinar, salah satu cabang kabilah Khazraj yang dahulu menetap di kawasan tersebut. Masjid ini termasuk salah satu masjid tempat Rasulullah ﷺ pernah melaksanakan salat, dan dibangun di lokasi tempat beliau salat. Masjid ini tetap dikenal dalam berbagai sumber sejarah, kemudian dibangun kembali pada masa pemerintahan Umar bin Abdul Aziz sebagai gubernur Madinah. Selanjutnya masjid ini mengalami beberapa kali renovasi sepanjang abad-abad berikutnya dengan tetap mempertahankan identitas sejarahnya. Meskipun bangunan aslinya telah hilang akibat perluasan kawasan perkotaan, lokasinya tetap dikenang sebagai salah satu tempat Rasulullah ﷺ melaksanakan salat, sehingga menjadi salah satu situs bersejarah yang berkaitan dengan sirah Nabi Muhammad ﷺ di Madinah.',
    },
    'موقع مسجد بني معاوية(الإجابة)': {
      'en':
          'Site of Banu Mu\'awiyah Mosque This is the site of Banu Mu\'awiyah Mosque, one of the historic mosques in Al-Madinah Al-Munawwarah, located north of Al-Baqi\' Cemetery. The Prophet ﷺ prayed at this mosque and supplicated to his Lord there. The mosque fell into ruin during certain periods of its history, but it later received care and restoration until it was rebuilt and expanded during the reign of King Fahd bin Abdulaziz. With the expansion of the Prophet\'s Mosque, the historic mosque was removed and its site became part of the surrounding road network.',
      'tr':
          'Benî Muâviye Mescidi\'nin Bulunduğu Yer Burası Benî Muâviye Mescidi\'nin bulunduğu yerdir. Hz. Peygamber ﷺ burada namaz kılmış ve dua etmiştir. Mescit zamanla harap olmuş, daha sonra restore edilerek Kral Fahd döneminde yeniden inşa edilip genişletilmiştir. Mescid-i Nebevî\'nin genişletilmesi sırasında kaldırılmış ve yollara dâhil edilmiştir.',
      'id':
          'Lokasi Masjid Bani Mu\'awiyah Inilah lokasi Masjid Bani Mu\'awiyah. Nabi ﷺ pernah salat dan berdoa di tempat ini. Masjid ini kemudian dipugar dan diperluas pada masa Raja Fahd. Setelah perluasan Masjid Nabawi, bangunan masjid dibongkar dan lokasinya menjadi bagian dari jaringan jalan di sekitarnya.',
    },
    'غار السجدة': {
      'en':
          'Cave of the Prostration The Cave of the Prostration is located on Mount Sila\' near the valley of Banu Haram. It is also known as the Cave of Banu Haram. It is narrated that the Prophet ﷺ performed a prostration of gratitude there. The cave is associated with events of the Battle of the Trench, where the Prophet ﷺ and the Muslims stayed and fortified themselves. Narrations also mention that he supplicated there for his nation.',
      'tr':
          'Secde Mağarası Secde Mağarası Sel\' Dağı üzerinde Benî Harâm Vadisi yakınındadır. Hz. Peygamber ﷺ\'in burada şükür secdesi yaptığı rivayet edilir. Mağara Hendek Gazvesi sırasında Müslümanların konakladığı ve Hz. Peygamber ﷺ\'in ümmeti için dua ettiği yer olarak bilinmektedir.',
      'id':
          'Gua Sujud Gua Sujud terletak di Gunung Sila\' dekat lembah Bani Haram. Diriwayatkan bahwa Nabi ﷺ melakukan sujud syukur di sini. Gua ini berkaitan dengan Perang Khandaq dan menjadi tempat Nabi ﷺ bersama kaum Muslimin berlindung serta berdoa untuk umatnya.',
    },
    'مسجد أول جمعة صلاها النبي صلى الله عليه وسلم': {
      'en':
          'Mosque of the First Friday Prayer Performed by the Prophet ﷺ Jumu\'ah Mosque is regarded as the place where the Prophet ﷺ performed the first Friday prayer after the Hijrah. It was rebuilt and expanded during the Saudi era.',
      'tr':
          'Hz. Peygamber ﷺ\'in İlk Cuma Namazını Kıldığı Mescit Cuma Mescidi, Hz. Peygamber ﷺ\'in hicretten sonra ilk cuma namazını kıldığı yer kabul edilir. Suudi döneminde yeniden inşa edilip genişletilmiştir.',
      'id':
          'Masjid Tempat Nabi ﷺ Melaksanakan Salat Jumat Pertama Masjid Jumat merupakan tempat Nabi ﷺ melaksanakan salat Jumat pertama setelah hijrah. Masjid ini dibangun kembali dan diperluas pada masa Arab Saudi.',
    },
    'مسجد المستراح': {
      'en':
          'Al-Mustarah Mosque Also known as Banu Harithah Mosque. It is reported that the Prophet ﷺ rested and prayed here on his way to the Battle of Uhud. The mosque was rebuilt and developed during the Saudi era.',
      'tr':
          'Müsterâh Mescidi Benî Hârise Mescidi olarak da bilinir. Hz. Peygamber ﷺ\'in Uhud\'a giderken burada dinlenip namaz kıldığı rivayet edilir. Suudi döneminde yeniden inşa edilmiştir.',
      'id':
          'Masjid Al-Mustarah Masjid ini juga dikenal sebagai Masjid Bani Haritsah. Nabi ﷺ diriwayatkan beristirahat dan salat di sini ketika menuju Perang Uhud. Masjid ini dibangun kembali pada masa Arab Saudi.',
    },
    'جبل أحد': {
      'en':
          'Mount Uhud is one of the most famous historical and natural landmarks in Al-Madinah Al-Munawwarah. It is located north of the city, approximately five kilometers from the Prophet\'s Mosque. It is one of the most prominent mountains in the region, extending for about seven kilometers and distinguished by its rocky formation and diverse colors. The mountain is closely associated with the Prophetic biography, as the Battle of Uhud took place beside it, one of the most significant events in Islamic history. The mountain witnessed many events related to the Prophet ﷺ and his Companions. Well-known Prophetic hadiths have also been narrated concerning its virtue, giving it a special place in the hearts of Muslims.',
      'tr':
          'Uhud Dağı, Medine-i Münevvere\'nin en meşhur tarihî ve doğal simgelerinden biridir. Şehrin kuzeyinde, Mescid-i Nebevî\'ye yaklaşık beş kilometre uzaklıkta bulunmaktadır. Bölgenin en önemli dağlarından biri olup yaklaşık yedi kilometre boyunca uzanır ve kayalık yapısı ile farklı renkleriyle dikkat çeker. Dağ, Siyer-i Nebeviyye ile çok yakın bir şekilde ilişkilidir. Çünkü İslam tarihinin en önemli olaylarından biri olan Uhud Gazvesi burada gerçekleşmiştir. Dağ, Hz. Peygamber ﷺ ve sahâbeyle ilgili birçok olaya tanıklık etmiş; fazileti hakkında meşhur hadisler rivayet edilmiş, bu da ona Müslümanların gönlünde özel bir yer kazandırmıştır.',
      'id':
          'Gunung Uhud merupakan salah satu situs sejarah dan alam yang paling terkenal di Madinah. Gunung ini terletak di sebelah utara kota, sekitar lima kilometer dari Masjid Nabawi. Gunung ini termasuk salah satu gunung yang paling menonjol di kawasan tersebut, membentang sekitar tujuh kilometer serta memiliki formasi bebatuan dan warna yang beragam. Gunung ini memiliki keterkaitan yang sangat erat dengan Sirah Nabawiyah, karena di sinilah terjadi Perang Uhud, salah satu peristiwa terpenting dalam sejarah Islam. Gunung ini menyaksikan banyak peristiwa yang berkaitan dengan Nabi ﷺ dan para sahabat. Selain itu, sejumlah hadis Nabi yang masyhur juga diriwayatkan mengenai keutamaannya, sehingga gunung ini memiliki kedudukan yang istimewa di hati kaum Muslimin.',
    },
    'جبل الرماة': {
      'en':
          'Mount of the Archers, also known as Mount Aynayn, is a small hill located southwest of Mount Uhud in Al-Madinah Al-Munawwarah. The mountain gained its fame from the events of the Battle of Uhud, when the Prophet ﷺ stationed fifty archers upon it under the command of Abdullah ibn Jubayr al-Ansari to protect the rear of the Muslims and prevent the polytheists from encircling the army. He instructed them not to leave their positions regardless of the outcome of the battle. At the beginning of the battle, the Muslims achieved clear progress, but most of the archers descended from the mountain, thinking that the fighting had ended. Khalid ibn al-Walid took advantage of this gap and led an attack that encircled the Muslims, resulting in a reversal of the course of the battle and the martyrdom of a number of the Companions.',
      'tr':
          'Okçular Tepesi, Aynayn Dağı adıyla da bilinen, Medine-i Münevvere\'de Uhud Dağı\'nın güneybatısında bulunan küçük bir tepedir. Tepe, Uhud Gazvesi sırasında Hz. Peygamber ﷺ\'in Müslümanların arkasını korumaları ve müşriklerin orduyu kuşatmasını önlemeleri için Abdullah b. Cübeyr el-Ensârî komutasında elli okçuyu buraya yerleştirmesiyle ün kazanmıştır. Hz. Peygamber ﷺ, savaşın sonucu ne olursa olsun bulundukları yerden ayrılmamalarını emretmiştir. Savaşın başlangıcında Müslümanlar açık bir üstünlük sağlamışlardı. Ancak okçuların çoğu savaşın sona erdiğini zannederek tepeden indi. Bunun üzerine Hâlid b. Velîd bu boşluktan faydalanarak Müslümanları arkadan kuşatan bir saldırı düzenledi. Bu durum savaşın seyrinin değişmesine ve sahâbeden bir kısmının şehit olmasına yol açtı.',
      'id':
          'Gunung Pemanah, yang juga dikenal dengan nama Gunung Aynayn, adalah sebuah bukit kecil yang terletak di sebelah barat daya Gunung Uhud di Madinah. Gunung ini menjadi terkenal karena peristiwa Perang Uhud, ketika Nabi ﷺ menempatkan lima puluh pemanah di atasnya di bawah pimpinan Abdullah bin Jubair al-Anshari untuk melindungi bagian belakang kaum Muslimin dan mencegah kaum musyrik mengepung pasukan. Beliau memerintahkan mereka agar tidak meninggalkan posisi mereka apa pun hasil pertempuran. Pada awal pertempuran, kaum Muslimin memperoleh kemajuan yang jelas. Namun, sebagian besar pemanah turun dari bukit karena mengira peperangan telah selesai. Khalid bin al-Walid kemudian memanfaatkan celah tersebut dan memimpin serangan yang mengepung kaum Muslimin, sehingga jalannya pertempuran berubah dan sejumlah sahabat gugur sebagai syuhada.',
    },
    'قصر عروة بن الزبير': {
      'en':
          'The Palace of Urwah ibn al-Zubayr is one of the most famous historic palaces in Al-Madinah Al-Munawwarah. It is attributed to Urwah ibn al-Zubayr, one of the Seven Jurists of Al-Madinah. It is located on the banks of Wadi al-\'Aqiq, west of the city, at a distinguished site on the historic road leading to Makkah. The palace was a large structure built of volcanic stone. It included courtyards and numerous rooms. Archaeological studies have revealed the remains of a mosque adjacent to it, as well as archaeological artifacts dating back to the Umayyad and Abbasid periods, confirming its historical and architectural significance. The Saudi government has taken responsibility for preserving the site and restoring it.',
      'tr':
          'Urve b. Zübeyr Sarayı, Medine-i Münevvere\'nin en meşhur tarihî saraylarından biridir. Medine\'nin yedi fakihinden biri olan Urve b. Zübeyr\'e nispet edilmektedir. Saray, Medine\'nin batısında Akīk Vadisi\'nin kıyısında, Mekke\'ye uzanan tarihî yol üzerinde seçkin bir konumda yer almaktadır. Saray, volkanik taşlardan inşa edilmiş büyük bir yapıydı. Avlular ve çok sayıda odadan oluşuyordu. Arkeolojik araştırmalar, sarayın bitişiğinde bir mescidin kalıntılarını ve Emevî ile Abbâsî dönemlerine ait arkeolojik eserleri ortaya çıkarmıştır. Bu buluntular, sarayın tarihî ve mimarî önemini doğrulamaktadır. Suudi Arabistan hükümeti, sarayın korunması ve restorasyonuyla ilgilenmiştir.',
      'id':
          'Istana Urwah bin az-Zubair merupakan salah satu istana bersejarah yang paling terkenal di Madinah. Istana ini dinisbatkan kepada Urwah bin az-Zubair, salah seorang dari Tujuh Ahli Fikih Madinah. Istana ini terletak di tepi Wadi al-\'Aqiq, di sebelah barat Madinah, pada lokasi yang strategis di jalur bersejarah menuju Makkah. Istana ini merupakan bangunan besar yang dibangun menggunakan batu vulkanik. Bangunan tersebut memiliki halaman-halaman dan banyak ruangan. Penelitian arkeologi telah mengungkap sisa-sisa sebuah masjid yang berada di sampingnya serta artefak-artefak yang berasal dari masa Umayyah dan Abbasiyah, yang menegaskan pentingnya nilai sejarah dan arsitekturnya. Pemerintah Arab Saudi telah memberikan perhatian terhadap situs ini serta melakukan pemugarannya.',
    },
    'مسجد سجدة الشكر': {
      'en':
          'Mosque of the Prostration of Gratitude The mosque is associated with an event from the Prophetic biography. Historians mention that it was built at the place where the Prophet ﷺ performed a prostration of gratitude after the Angel Gabriel (peace be upon him) brought him the glad tidings of the virtue of invoking prayers and peace upon him ﷺ.',
      'tr':
          'Şükür Secdesi Mescidi Bu mescit, Siyer-i Nebeviyye\'den bir olayla ilişkilidir. Tarihçiler, mescidin, Cebrâil\'in (aleyhisselâm) Hz. Peygamber\'e ﷺ kendisine salât ve selâm getirmenin faziletini müjdelemesinin ardından Hz. Peygamber\'in ﷺ şükür secdesi yaptığı yerde inşa edildiğini zikretmektedir.',
      'id':
          'Masjid Sujud Syukur Masjid ini berkaitan dengan sebuah peristiwa dalam Sirah Nabawiyah. Para sejarawan menyebutkan bahwa masjid ini dibangun di tempat Nabi ﷺ melakukan sujud syukur setelah Malaikat Jibril \'alaihissalam menyampaikan kabar gembira kepada beliau tentang keutamaan membaca salawat dan salam kepada beliau ﷺ.',
    },
    'بقيع الغرقد': {
      'en':
          'Al-Baqi\' al-Gharqad is the principal historic cemetery in Al-Madinah Al-Munawwarah. It is located to the southeast of the Prophet\'s Mosque. It was given this name because of the al-Gharqad trees that used to grow at the site before it became the cemetery of the people of Al-Madinah. Al-Baqi\' is regarded as one of the most important Islamic sites, as a large number of the Companions, members of the Prophet\'s ﷺ family, and the Tābi\'ūn were buried there, giving it great religious and historical significance among Muslims. During the Saudi era, Al-Baqi\' underwent several architectural developments, including expansions, restoration works, and the construction of boundary walls. The cemetery was expanded, organized, and its facilities were developed, with walls, gates, pathways, and services related to burials and funeral preparations being established.',
      'tr':
          'Cennetü\'l-Bakî, Medine-i Münevvere\'nin başlıca tarihî mezarlığıdır. Mescid-i Nebevî\'nin güneydoğusunda yer almaktadır. Mezarlık hâline getirilmeden önce bu bölgede yetişen garkad ağaçlarından dolayı bu isimle anılmıştır. Cennetü\'l-Bakî, en önemli İslâmî mekânlardan biri kabul edilmektedir. Çünkü burada çok sayıda sahâbî, Hz. Peygamber\'in ﷺ Ehl-i Beyti ve tâbiînden kimseler defnedilmiştir. Bu durum ona Müslümanlar nezdinde büyük dinî ve tarihî bir değer kazandırmıştır. Suudi döneminde Cennetü\'l-Bakî\'de genişletme, restorasyon ve mezarlığın çevresinin duvarlarla çevrilmesi gibi birçok imar çalışması gerçekleştirilmiştir. Mezarlık genişletilmiş, düzenlenmiş ve geliştirilmiş; ayrıca duvarlar, kapılar, yollar ile defin ve cenaze hazırlıklarıyla ilgili hizmetler oluşturulmuştur.',
      'id':
          'Al-Baqi\' al-Gharqad merupakan pemakaman bersejarah utama di Madinah. Pemakaman ini terletak di sebelah tenggara Masjid Nabawi. Tempat ini dinamakan demikian karena pohon al-Gharqad yang dahulu tumbuh di lokasi tersebut sebelum dijadikan sebagai pemakaman bagi penduduk Madinah. Al-Baqi\' merupakan salah satu situs Islam yang paling penting, karena sejumlah besar sahabat, keluarga Nabi ﷺ, dan para tabi\'in dimakamkan di sana, sehingga menjadikannya memiliki kedudukan agama dan sejarah yang sangat besar di kalangan kaum Muslimin. Pada masa pemerintahan Arab Saudi, Al-Baqi\' mengalami berbagai pengembangan fisik, termasuk perluasan, pemugaran, dan pembangunan pagar di sekeliling area pemakaman. Area pemakaman diperluas, ditata, dan fasilitasnya dikembangkan, termasuk pembangunan pagar, gerbang, jalur pejalan kaki, serta berbagai layanan yang berkaitan dengan pemakaman dan penyelenggaraan jenazah.',
    },
    'مسجد الفتح': {
      'en':
          'Al-Fath Mosque, also known as the Mosque of the Confederates (Masjid al-Ahzab) or the Upper Mosque, is one of the most prominent historic mosques in Al-Madinah Al-Munawwarah. It is situated on an elevated part of Mount Sila\' within the area of the Seven Mosques, about three kilometers from the Prophet\'s Mosque. The importance of the mosque is connected with the events of the Battle of the Trench (Al-Khandaq), as it is attributed to the place where the Prophet ﷺ and some of his Companions camped during the battle. For this reason, it acquired a distinguished historical status in the Prophetic biography. The mosque passed through several phases of construction and renovation throughout history, beginning with its construction during the governorship of Umar ibn Abd al-Aziz over Al-Madinah, followed by its renewal in later periods. During the Saudi era, it received great attention through restoration, maintenance, and preservation of its historical character. It still stands today as one of the landmarks of Al-Madinah Al-Munawwarah associated with the Prophetic biography.',
      'tr':
          'Fetih Mescidi, Ahzâb Mescidi veya Yukarı Mescit olarak da bilinmektedir. Medine-i Münevvere\'deki en önemli tarihî mescitlerden biridir. Mescid, Yedi Mescit bölgesinde, Sel\' Dağı üzerinde yüksek bir noktada, Mescid-i Nebevî\'ye yaklaşık üç kilometre uzaklıkta yer almaktadır. Mescidin önemi, Hendek Gazvesi olaylarıyla bağlantılıdır. Çünkü buranın, Hz. Peygamber ﷺ\'in ve bazı sahâbîlerinin gazve sırasında karargâh kurdukları yer olduğu kabul edilmektedir. Bu sebeple Siyer-i Nebeviyye\'de seçkin bir tarihî konum kazanmıştır. Mescit, tarih boyunca birçok inşa ve yenileme aşamasından geçmiştir. İlk imarı, Ömer b. Abdülaziz\'in Medine valiliği döneminde yapılmış, daha sonra sonraki dönemlerde yenilenmiştir. Suudi döneminde ise restorasyon, bakım ve tarihî dokusunun korunması çalışmalarıyla büyük ilgi görmüştür. Günümüzde de Siyer-i Nebeviyye ile bağlantılı Medine-i Münevvere\'nin önemli tarihî eserlerinden biri olarak varlığını sürdürmektedir.',
      'id':
          'Masjid Al-Fath, yang juga dikenal sebagai Masjid Al-Ahzab atau Masjid Atas, merupakan salah satu masjid bersejarah yang paling menonjol di Madinah. Masjid ini terletak di tempat yang tinggi di Gunung Sila\', dalam kawasan Tujuh Masjid, sekitar tiga kilometer dari Masjid Nabawi. Pentingnya masjid ini berkaitan dengan peristiwa Perang Khandaq, karena tempat ini dinisbatkan sebagai lokasi Nabi ﷺ bersama sebagian sahabat beliau berkemah selama peperangan tersebut. Oleh karena itu, masjid ini memperoleh kedudukan sejarah yang menonjol dalam Sirah Nabawiyah. Masjid ini telah melalui beberapa tahap pembangunan dan renovasi sepanjang sejarah, dimulai dengan pembangunannya pada masa Umar bin Abdul Aziz ketika beliau menjabat sebagai gubernur Madinah, kemudian diperbarui pada masa-masa berikutnya. Pada masa pemerintahan Arab Saudi, masjid ini mendapat perhatian besar melalui pekerjaan restorasi, pemeliharaan, dan pelestarian karakter sejarahnya. Hingga kini, masjid ini tetap berdiri sebagai salah satu landmark Madinah yang berkaitan dengan Sirah Nabawiyah.',
    },
    'مشربة أم إبراهيم': {
      'en':
          'Mashrabat Umm Ibrahim was one of the well-known charitable endowments (ṣadaqāt) of the Prophet ﷺ in Al-Madinah Al-Munawwarah. However, over the course of time, the site was lost and became subject to encroachments. Urban expansion and changes in land use also contributed to the disappearance of its original features and the loss of many of its historical landmarks. As a result, the Mashrabah no longer has any visible remains that can be identified today. Knowledge of its location now depends primarily on what has been preserved in historical sources and specialized studies on the history of Al-Madinah Al-Munawwarah.',
      'tr':
          'Ümmü İbrahim Meşrebesi, Medine-i Münevvere\'de Hz. Peygamber ﷺ\'e ait meşhur sadakalardan biriydi. Ancak zamanla bu yer kaybolmuş ve çeşitli müdahalelere maruz kalmıştır. Ayrıca şehirleşmenin genişlemesi ve arazi kullanımındaki değişiklikler, aslî özelliklerinin silinmesine ve tarihî izlerinin büyük ölçüde ortadan kalkmasına sebep olmuştur. Bunun sonucunda meşrebenin günümüzde tespit edilebilecek görünür bir kalıntısı kalmamıştır. Bugün bu yer hakkındaki bilgiler, esas olarak tarihî kaynaklarda ve Medine-i Münevvere tarihi üzerine yapılmış uzmanlık çalışmalarında korunan bilgilere dayanmaktadır.',
      'id':
          'Mashrabat Umm Ibrahim merupakan salah satu sedekah Nabi ﷺ yang terkenal di Madinah. Namun, seiring berjalannya waktu, lokasi tersebut hilang dan mengalami berbagai bentuk perambahan. Perluasan kawasan perkotaan serta perubahan penggunaan lahan juga turut menyebabkan hilangnya ciri-ciri aslinya dan lenyapnya banyak jejak sejarahnya. Akibatnya, saat ini tidak lagi terdapat peninggalan yang tampak sehingga lokasinya dapat dikenali. Pengetahuan mengenai Mashrabah tersebut kini terutama bergantung pada informasi yang dipelihara dalam sumber-sumber sejarah serta kajian-kajian khusus mengenai sejarah Madinah.',
    },
    'مزرعة سلمان الفارسي رضي الله عنه': {
      'en':
          'Salman al-Farsi\'s Farm is attributed to the noble Companion Salman al-Farsi (may Allah be pleased with him). The Saudi government has taken care to preserve the landmarks associated with the Prophetic era.',
      'tr':
          'Selmân el-Fârisî\'nin Çiftliği, büyük sahâbî Selmân el-Fârisî\'ye (Allah ondan razı olsun) nispet edilmektedir. Suudi Arabistan hükümeti, Nebevî döneme ait tarihî eserlerin korunmasına özen göstermiştir.',
      'id':
          'Perkebunan Salman al-Farisi dinisbatkan kepada sahabat mulia Salman al-Farisi (semoga Allah meridhainya). Pemerintah Arab Saudi telah memberikan perhatian dalam menjaga situs-situs yang berkaitan dengan masa kenabian.',
    },
    'بئر الأعواف': {
      'en':
          'Al-A\'waf Well The Prophet ﷺ performed ablution from Al-A\'waf Well. The government of the Custodian of the Two Holy Mosques has taken care to preserve it.',
      'tr':
          'Aʿvâf Kuyusu Hz. Peygamber ﷺ Aʿvâf Kuyusu\'ndan abdest almıştır. Hâdimü\'l-Haremeyn eş-Şerîfeyn Hükûmeti bu kuyunun korunmasına özen göstermiştir.',
      'id':
          'Sumur Al-A\'waf Nabi ﷺ berwudu dari Sumur Al-A\'waf. Pemerintah Penjaga Dua Tanah Suci telah memberikan perhatian dalam menjaga sumur tersebut.',
    },
    'مزارع برقة': {
      'en':
          'Barqah Farms Barqah was one of the charitable endowments (ṣadaqāt) of the Prophet ﷺ. The Kingdom of Saudi Arabia has taken care to preserve the Prophetic historical sites.',
      'tr':
          'Berka Çiftlikleri Berka, Hz. Peygamber ﷺ\'in sadakalarından biriydi. Suudi Arabistan Krallığı, Nebevî tarihî eserlerin korunmasına özen göstermiştir.',
      'id':
          'Perkebunan Barqah Barqah merupakan salah satu sedekah Nabi ﷺ. Kerajaan Arab Saudi telah memberikan perhatian dalam menjaga situs-situs bersejarah yang berkaitan dengan Nabi ﷺ.',
    },
    'سوق المناخة': {
      'en':
          'Al-Manakhah Market The history of Al-Manakhah dates back to the Prophetic era, when the Messenger of Allah ﷺ sought to designate a marketplace for the Muslims in Al-Madinah Al-Munawwarah. He first visited the market of Banu Qaynuqa\', then proceeded to the site of the market of Al-Madinah. He struck the ground with his noble foot and said: "This is your market; it is not to be restricted, and no tax is to be levied in it." The Kingdom of Saudi Arabia has developed the market while preserving the architectural character of the Prophet\'s Mosque.',
      'tr':
          'Menâha Pazarı Menâha\'nın tarihi, Hz. Peygamber ﷺ\'in Medine-i Münevvere\'de Müslümanlara bir pazar yeri tahsis etmeye çalıştığı Nebevî döneme kadar uzanmaktadır. Resûlullah ﷺ önce Benî Kaynukā Pazarı\'nı ziyaret etti, ardından Medine pazarının yerine gitti. Mübarek ayağıyla yere vurdu ve şöyle buyurdu: "İşte sizin pazarınız budur; daraltılmayacak ve buradan vergi alınmayacaktır." Suudi Arabistan Krallığı, Mescid-i Nebevî\'nin mimarî görünümünü koruyarak pazarı geliştirmiştir.',
      'id':
          'Pasar Al-Manakhah Sejarah Al-Manakhah bermula sejak masa kenabian, ketika Rasulullah ﷺ berusaha menetapkan sebuah pasar bagi kaum Muslimin di Madinah. Beliau terlebih dahulu mengunjungi Pasar Bani Qainuqa\', kemudian menuju lokasi pasar Madinah. Beliau menghentakkan kaki beliau yang mulia ke tanah lalu bersabda: "Inilah pasar kalian; jangan dipersempit dan jangan dipungut pajak di dalamnya." Kerajaan Arab Saudi telah mengembangkan pasar tersebut dengan tetap mempertahankan tampilan arsitektur Masjid Nabawi.',
    },
    'حرة بني بياضة': {
      'en':
          'Harrah of Banu Bayadah This area was given this name in relation to Banu Bayadah, a clan of the Ansar, who trace their lineage to Bayadah ibn Amir ibn Zurayq ibn Abd Harithah of the Khazraj tribe.',
      'tr':
          'Benî Beyâda Harresi Bu bölge, Ensar\'ın bir kolu olan Benî Beyâda\'ya nispetle bu adla anılmıştır. Onlar, Hazrec kabilesinden Beyâda b. Âmir b. Zürayk b. Abd Hârise\'nin soyundandır.',
      'id':
          'Harrah Bani Bayadah Kawasan ini dinamai demikian karena dinisbatkan kepada Bani Bayadah, salah satu kabilah dari kaum Ansar, yang bernasab kepada Bayadah bin Amir bin Zuraiq bin Abd Haritsah dari kabilah Khazraj.',
    },
    'حرة شوران': {
      'en':
          'Harrah of Shawran Harrah Shawran is located on the southern side of Al-Madinah Al-Munawwarah, approximately seven kilometers from the Prophet\'s Mosque. It is one of the large volcanic lava fields, covering a vast area. It is distinguished by its geographical diversity, especially before the urban expansion during the era of the government of the Custodian of the Two Holy Mosques.',
      'tr':
          'Şevrân Harresi Şevrân Harresi, Medine-i Münevvere\'nin güney tarafında yer almakta olup Mescid-i Nebevî\'ye yaklaşık yedi kilometre uzaklıktadır. Büyük harrelerden biridir ve geniş bir alana sahiptir. Hâdimü\'l-Haremeyn eş-Şerîfeyn Hükûmeti dönemindeki şehirleşme ve genişleme çalışmalarından önce coğrafi çeşitliliğiyle öne çıkmaktaydı.',
      'id':
          'Harrah Shawran Harrah Shawran terletak di sebelah selatan Madinah, sekitar tujuh kilometer dari Masjid Nabawi. Harrah ini merupakan salah satu hamparan lava vulkanik yang besar dengan wilayah yang luas. Kawasan ini memiliki keragaman geografis yang menonjol, khususnya sebelum terjadinya perluasan kawasan perkotaan pada masa pemerintahan Penjaga Dua Tanah Suci.',
    },
    'مقبرة شهداء الخندق': {
      'en':
          'Cemetery of the Martyrs of the Battle of the Trench This is the cemetery of the martyrs who were martyred in the Battle of the Trench (Al-Khandaq). They are: Anas ibn Aws, Abdullah ibn Sahl, Al-Tufayl ibn al-Nu\'man, Tha\'labah ibn Ghanmah, and Ka\'b ibn Zayd (may Allah be pleased with them). The Government of the Kingdom of Saudi Arabia has taken care of the cemetery by preserving it and enclosing it with a boundary wall.',
      'tr':
          'Hendek Şehitleri Mezarlığı Burası, Hendek Gazvesi\'nde şehit olanların mezarlığıdır. Şehit olanlar şunlardır: Enes b. Evs, Abdullah b. Sehl, Tufeyl b. Nu\'mân, Sa\'lebe b. Ganeme ve Kâ\'b b. Zeyd (Allah onlardan razı olsun). Suudi Arabistan Krallığı Hükûmeti, mezarlığa gerekli özeni göstermiş, onu korumuş ve etrafını duvarla çevirmiştir.',
      'id':
          'Pemakaman Syuhada Perang Khandaq Ini adalah pemakaman para syuhada yang gugur dalam Perang Khandaq. Mereka adalah: Anas bin Aws, Abdullah bin Sahl, Al-Tufail bin an-Nu\'man, Tsa\'labah bin Ghanmah, dan Ka\'b bin Zaid (semoga Allah meridhai mereka). Pemerintah Kerajaan Arab Saudi telah memberikan perhatian terhadap pemakaman ini dengan menjaganya serta membangun pagar yang mengelilinginya.',
    },
    'مقبرة شهداء بدر': {
      'en':
          'Cemetery of the Martyrs of Badr The Great Battle of Badr took place in the second year after the Hijrah. A number of the Companions were martyred in it. Among the Muhajirun were: - Ubaydah ibn al-Harith al-Muttalibi al-Qurashi - Umayr ibn Abi Waqqas al-Zuhri al-Qurashi - Safwan ibn Wahb al-Fihri al-Qurashi - Aqil ibn al-Bukayr al-Laythi al-Kinani - Dhu al-Shimalayn ibn Abd Amr al-Khuza\'i - Mihja\' ibn Salih al-\'Akki And eight from the Ansar: - Sa\'d ibn Khaythamah al-Awsi - Mubashshir ibn Abd al-Mundhir al-\'Amri al-Awsi - Yazid ibn al-Harith al-Khazraji - Umayr ibn al-Humam al-Salami al-Khazraji - Rafi\' ibn al-Mu\'alla al-Zurqi al-Khazraji - Harith ibn Suraqah al-Najjari al-Khazraji - Mu\'awwidh ibn al-Harith al-Najjari al-Khazraji - Awf ibn al-Harith al-Najjari al-Khazraji The Government of the Kingdom of Saudi Arabia has taken care of the cemetery and enclosed it with a boundary wall.',
      'tr':
          'Bedir Şehitleri Mezarlığı Büyük Bedir Gazvesi, hicretin ikinci yılında gerçekleşmiştir. Bu gazvede sahâbeden bir kısmı şehit olmuştur. Muhacirlerden şehit olanlar: - Ubeyde b. Hâris el-Muttalibî el-Kureşî - Umeyr b. Ebû Vakkās ez-Zührî el-Kureşî - Safvân b. Vehb el-Fihrî el-Kureşî - Âkıl b. el-Bükeyr el-Leysî el-Kinânî - Zü\'ş-Şimâleyn b. Abd Amr el-Huzâî - Mihca\' b. Sâlih el-Akkî Ensardan sekiz kişi ise şunlardır: - Sa\'d b. Hayseme el-Evsî - Mübeşşir b. Abdülmünzir el-Amrî el-Evsî - Yezîd b. Hâris el-Hazrecî - Umeyr b. el-Humâm es-Sülemî el-Hazrecî - Râfi\' b. el-Muallâ ez-Zürkî el-Hazrecî - Hâris b. Sürâka en-Neccârî el-Hazrecî - Muavviz b. Hâris en-Neccârî el-Hazrecî - Avf b. Hâris en-Neccârî el-Hazrecî Suudi Arabistan Krallığı Hükûmeti mezarlığa gerekli özeni göstermiş ve etrafını duvarla çevirmiştir.',
      'id':
          'Pemakaman Syuhada Badar Perang Badar Kubra terjadi pada tahun kedua Hijrah. Dalam peperangan ini sejumlah sahabat gugur sebagai syuhada. Dari kalangan Muhajirin, mereka adalah: - Ubaidah bin al-Harits al-Muththalibi al-Qurasyi - Umair bin Abi Waqqash az-Zuhri al-Qurasyi - Shafwan bin Wahb al-Fihri al-Qurasyi - Aqil bin al-Bukair al-Laitsi al-Kinani - Dzu asy-Syimalain bin Abd Amr al-Khuza\'i - Mihja\' bin Shalih al-\'Akki Dan delapan orang dari kalangan Ansar, yaitu: - Sa\'d bin Khaitsamah al-Ausi - Mubasysyir bin Abd al-Mundzir al-\'Amri al-Ausi - Yazid bin al-Harits al-Khazraji - Umair bin al-Humam as-Salami al-Khazraji - Rafi\' bin al-Mu\'alla az-Zurqi al-Khazraji - Harits bin Suraqah an-Najjari al-Khazraji - Mu\'awwidz bin al-Harits an-Najjari al-Khazraji - Auf bin al-Harits an-Najjari al-Khazraji Pemerintah Kerajaan Arab Saudi telah memberikan perhatian terhadap pemakaman ini serta membangun pagar yang mengelilinginya.',
    },
    'جبل الملائكة': {
      'en':
          'Mount of the Angels This is the place where the angels supported the Prophet ﷺ during the Battle of Badr. Allah, the Exalted, said: "When you sought help from your Lord, and He answered you: \'Indeed, I will reinforce you with a thousand angels, following one another.\'" (Surah Al-Anfal, 8:9).',
      'tr':
          'Melekler Dağı Burası, Bedir Gazvesi sırasında meleklerin Hz. Peygamber\'i ﷺ desteklediği yerdir. Yüce Allah şöyle buyurmuştur: "Hani Rabbinizden yardım istiyordunuz da O size: \'Şüphesiz ben size peş peşe gelen bin melekle yardım edeceğim.\' diye karşılık vermişti." (Enfâl Sûresi, 8:9).',
      'id':
          'Gunung Malaikat Inilah tempat para malaikat memberikan pertolongan kepada Nabi ﷺ dalam Perang Badar. Allah Ta\'ala berfirman: "Ketika kamu memohon pertolongan kepada Tuhanmu, lalu Dia memperkenankan permohonanmu: \'Sesungguhnya Aku akan membantu kamu dengan seribu malaikat yang datang berturut-turut.\'" (Surah Al-Anfal [8]: 9).',
    },
    'بئر غرس': {
      'en':
          'Ghars Well Ghars Well is one of the historic wells associated with the Prophetic biography in Al-Madinah Al-Munawwarah. Its name is derived from the planting and cultivation for which the area was well known. Historical reports state that the well was dug by Malik ibn al-Nahhat, one of the forefathers of the Companion Sa\'d ibn Khaythamah, who came to own it at the time of the Prophet\'s Hijrah. The well acquired a special religious and historical significance because reports mention that the Prophet ﷺ drank from its water, performed ablution with it, and found its water pleasant. Narrations also indicate that he instructed Ali ibn Abi Talib (may Allah be pleased with him) that his body should be washed with its water after his death.',
      'tr':
          'Gars Kuyusu Gars Kuyusu, Medine-i Münevvere\'de Siyer-i Nebeviyye ile bağlantılı tarihî kuyulardan biridir. Kuyunun adı, bölgenin meşhur olduğu dikim ve ziraatten gelmektedir. Tarihî rivayetlere göre kuyu, sahâbî Sa\'d b. Hayseme\'nin dedelerinden biri olan Mâlik b. en-Nahhât tarafından kazılmış ve Hicret döneminde onun mülkiyetine geçmiştir. Kuyu, Hz. Peygamber ﷺ\'in suyundan içtiği, onunla abdest aldığı ve suyunu hoş bulduğu yönündeki rivayetler sebebiyle özel bir dinî ve tarihî değere sahip olmuştur. Ayrıca bazı rivayetlerde, Hz. Peygamber ﷺ\'in Ali b. Ebû Tâlib\'e (Allah ondan razı olsun), vefatından sonra naaşının bu kuyunun suyuyla yıkanmasını vasiyet ettiği nakledilmektedir.',
      'id':
          'Sumur Ghars Sumur Ghars merupakan salah satu sumur bersejarah yang berkaitan dengan Sirah Nabawiyah di Madinah. Nama sumur ini berasal dari kegiatan bercocok tanam dan pertanian yang dahulu terkenal di kawasan tersebut. Riwayat-riwayat sejarah menyebutkan bahwa sumur ini digali oleh Malik bin an-Nahhat, salah seorang leluhur sahabat Sa\'d bin Khaitsamah, yang kemudian menjadi pemiliknya pada masa Hijrah Nabi. Sumur ini memperoleh kedudukan agama dan sejarah yang istimewa karena terdapat riwayat yang menyebutkan bahwa Nabi ﷺ meminum airnya, berwudu dengannya, dan menyukai airnya. Selain itu, terdapat pula riwayat yang menunjukkan bahwa beliau berwasiat kepada Ali bin Abi Thalib (semoga Allah meridhainya) agar jenazah beliau dimandikan dengan air sumur tersebut setelah wafatnya.',
    },
    'مسجد الدرع': {
      'en':
          'Al-Dira\' Mosque It is also called Al-Shaykhayn Mosque, in reference to the two mountains, and it is also known as Al-Bada\'i Mosque. At this site, the army of the Muslims camped with the Messenger of Allah ﷺ on the night of their departure to fight the polytheists in the Battle of Uhud, on 15 Shawwal, 3 AH. The Prophet ﷺ performed the five daily prayers there and spent the night before heading to the battlefield. At this place, the Prophet ﷺ sent back some of the younger Companions. The Government of the Custodian of the Two Holy Mosques has taken care of the mosque and developed it.',
      'tr':
          'Dır\' Mescidi Bu mescit, iki dağa nispetle Şeyhayn Mescidi olarak da adlandırılır; ayrıca Bedâyi\' Mescidi adıyla da bilinmektedir. Müslüman ordusu, Resûlullah ﷺ ile birlikte Uhud Gazvesi\'nde müşriklerle savaşmak üzere yola çıktıkları gece, Hicret\'in 3. yılı Şevval ayının 15. gününde, bu yerde konaklamıştır. Hz. Peygamber ﷺ burada beş vakit namazı kılmış ve savaş alanına yönelmeden önce geceyi burada geçirmiştir. Yine bu yerde Hz. Peygamber ﷺ sahâbenin yaşça küçük olanlarından bir kısmını geri çevirmiştir. Hâdimü\'l-Haremeyn eş-Şerîfeyn Hükûmeti mescide özen göstermiş ve onu geliştirmiştir.',
      'id':
          'Masjid Ad-Dira\' Masjid ini juga dikenal sebagai Masjid Asy-Syaikhain, karena dinisbatkan kepada dua gunung, dan juga disebut Masjid Al-Bada\'i. Di tempat ini, pasukan kaum Muslimin berkemah bersama Rasulullah ﷺ pada malam keberangkatan mereka untuk memerangi kaum musyrik dalam Perang Uhud, pada 15 Syawal tahun 3 H. Nabi ﷺ melaksanakan salat lima waktu di tempat ini dan bermalam di sana sebelum menuju medan pertempuran. Di tempat ini pula Nabi ﷺ memulangkan sebagian sahabat yang masih berusia muda. Pemerintah Penjaga Dua Tanah Suci telah memberikan perhatian terhadap masjid ini serta melakukan pengembangannya.',
    },
    'مسجد بني أنيف': {
      'en':
          'Banu Unayf Mosque Banu Unayf Mosque is one of the historic mosques in the Quba area of Al-Madinah Al-Munawwarah. It is located southwest of Quba Mosque. It has been narrated that the Prophet ﷺ prayed at its location during his visit to the Companion Talhah ibn al-Bara\' while he was ill.',
      'tr':
          'Benî Üneyf Mescidi Benî Üneyf Mescidi, Medine-i Münevvere\'deki Kubâ bölgesinde bulunan tarihî mescitlerden biridir. Kubâ Mescidi\'nin güneybatısında yer almaktadır. Rivayet edildiğine göre Hz. Peygamber ﷺ, hastalığı sırasında sahâbî Talha b. Berâ\'yı ziyaret ettiğinde bu mescidin bulunduğu yerde namaz kılmıştır.',
      'id':
          'Masjid Bani Unayf Masjid Bani Unayf merupakan salah satu masjid bersejarah di kawasan Quba, Madinah. Masjid ini terletak di sebelah barat daya Masjid Quba. Diriwayatkan bahwa Nabi ﷺ melaksanakan salat di lokasi masjid ini ketika beliau mengunjungi sahabat Talhah bin al-Bara\' saat beliau sedang sakit.',
    },
    'حصن بني واقف': {
      'en':
          'Fort of Banu Waqif The Fort of Banu Waqif is one of the Islamic historical landmarks in Al-Madinah Al-Munawwarah. It was named after Banu Waqif, a clan of the Aws tribe who settled in this area. Its historical importance is highlighted by narrations stating that the Prophet ﷺ prayed in Banu Waqif Mosque, which was located within the fort. The fort is regarded as the largest of the forts of Banu Waqif.',
      'tr':
          'Benî Vâkıf Kalesi Benî Vâkıf Kalesi, Medine-i Münevvere\'deki İslâmî tarihî eserlerden biridir. Kale, bu bölgede yerleşen Evs kabilesinin bir kolu olan Benî Vâkıf\'a nispetle bu adı almıştır. Tarihî önemi, Hz. Peygamber ﷺ\'in kalenin içinde bulunan Benî Vâkıf Mescidi\'nde namaz kıldığına dair rivayetlerin bulunmasından kaynaklanmaktadır. Bu kale, Benî Vâkıf\'a ait kalelerin en büyüğü kabul edilmektedir.',
      'id':
          'Benteng Bani Waqif Benteng Bani Waqif merupakan salah satu situs bersejarah Islam di Madinah. Benteng ini dinamai berdasarkan Bani Waqif, salah satu kabilah dari Aus yang menetap di kawasan ini. Nilai sejarahnya tampak dari adanya riwayat yang menyebutkan bahwa Nabi ﷺ pernah melaksanakan salat di Masjid Bani Waqif yang berada di dalam benteng tersebut. Benteng ini merupakan benteng terbesar milik Bani Waqif.',
    },
    'غزوة أحد': {
      'en':
          'The Battle of Uhud The Battle of Uhud took place in the third year after the Hijrah. It occurred after Quraysh set out to avenge their defeat at the Battle of Badr. The number of the Muslims was about 700 fighters after the withdrawal of the hypocrites, while the army of the Quraysh disbelievers numbered about 3,000 fighters. The battle began in favor of the Muslims, but the archers\' descent from the mountain changed the course of the battle. About seventy Muslims were martyred, and the polytheists withdrew without achieving their objective of eliminating the Muslims. This is the site of the Battle of Uhud. The Government of the Kingdom of Saudi Arabia has developed the site and taken care of it.',
      'tr':
          'Uhud Gazvesi Uhud Gazvesi, Hicret\'in üçüncü yılında meydana gelmiştir. Kureyş, Bedir\'deki yenilgisinin intikamını almak için harekete çıktıktan sonra gerçekleşmiştir. Münafıkların ayrılmasının ardından Müslümanların sayısı yaklaşık 700 savaşçı, Kureyş müşriklerinin ordusu ise yaklaşık 3.000 savaşçı idi. Savaş başlangıçta Müslümanların lehine gelişti; ancak okçuların dağdan inmeleri savaşın seyrini değiştirdi. Yaklaşık yetmiş Müslüman şehit oldu ve müşrikler, Müslümanları tamamen ortadan kaldırma hedeflerine ulaşamadan geri çekildiler. Burası Uhud Gazvesi\'nin gerçekleştiği yerdir. Suudi Arabistan Krallığı Hükûmeti bu alanı geliştirmiş ve gerekli ilgiyi göstermiştir.',
      'id':
          'Perang Uhud Perang Uhud terjadi pada tahun ketiga Hijriah. Perang ini terjadi setelah kaum Quraisy keluar untuk membalas kekalahan mereka dalam Perang Badar. Jumlah kaum Muslimin sekitar 700 orang pejuang setelah kaum munafik mengundurkan diri, sedangkan pasukan kaum musyrik Quraisy berjumlah sekitar 3.000 orang pejuang. Pertempuran pada awalnya berpihak kepada kaum Muslimin, tetapi turunnya para pemanah dari bukit mengubah jalannya pertempuran. Sekitar tujuh puluh orang Muslim gugur sebagai syuhada, dan kaum musyrik mundur tanpa berhasil mencapai tujuan mereka untuk melenyapkan kaum Muslimin. Inilah lokasi Perang Uhud. Pemerintah Kerajaan Arab Saudi telah mengembangkan lokasi ini dan memberikan perhatian terhadapnya.',
    },
    'غزوة بدر': {
      'en':
          'The Battle of Badr The Battle of Badr took place in the second year after the Hijrah. The Muslims set out to intercept a caravan of Quraysh, but the mission developed into a battle against the army of Quraysh. The number of the Muslims was about 313 fighters, while the army of Quraysh numbered approximately 1,000 fighters. The battle ended with the victory of the Muslims, and a number of the leading chiefs of Quraysh were killed.',
      'tr':
          'Bedir Gazvesi Bedir Gazvesi, Hicret\'in ikinci yılında meydana gelmiştir. Müslümanlar, Kureyş\'e ait bir kervanı durdurmak amacıyla yola çıkmış; ancak görev, Kureyş ordusuyla yapılan bir savaşa dönüşmüştür. Müslümanların sayısı yaklaşık 313 savaşçı, Kureyş ordusunun sayısı ise yaklaşık 1.000 savaşçı idi. Gazve, Müslümanların zaferiyle sonuçlanmış ve Kureyş\'in önde gelen liderlerinden bir kısmı öldürülmüştür.',
      'id':
          'Perang Badar Perang Badar terjadi pada tahun kedua Hijriah. Kaum Muslimin berangkat untuk menghadang kafilah Quraisy, namun misi tersebut berubah menjadi pertempuran melawan pasukan Quraisy. Jumlah kaum Muslimin sekitar 313 orang pejuang, sedangkan jumlah pasukan Quraisy sekitar 1.000 orang pejuang. Perang ini berakhir dengan kemenangan kaum Muslimin, dan sejumlah pemimpin utama Quraisy terbunuh.',
    },
    'غزوة الخندق': {
      'en':
          'The Battle of the Trench The Battle of the Trench took place in the fifth year after the Hijrah, when several tribes formed an alliance to eliminate the Muslims. The number of the Muslims was about 3,000 fighters, while the army of the Confederates numbered approximately 10,000 fighters. Salman al-Farsi suggested digging a trench around Al-Madinah, preventing the Confederates from entering the city. Thereafter, Allah dispersed them by sending a strong wind and causing division among them. The battle ended with their withdrawal without a decisive engagement, and it was a victory for the Muslims. This is an approximate location of the Battle of the Trench. The Kingdom of Saudi Arabia has taken care of the site and developed it.',
      'tr':
          'Hendek Gazvesi Hendek Gazvesi, Hicret\'in beşinci yılında, bazı kabilelerin Müslümanları ortadan kaldırmak amacıyla ittifak kurmaları üzerine meydana gelmiştir. Müslümanların sayısı yaklaşık 3.000 savaşçı, Ahzâb ordusunun sayısı ise yaklaşık 10.000 savaşçı idi. Selmân el-Fârisî, Medine\'nin etrafına hendek kazılması fikrini ortaya koymuş, bunun üzerine Ahzâb şehre girmeyi başaramamıştır. Daha sonra Allah onları rüzgâr ve aralarına düşen anlaşmazlıklarla dağıtmış, gazve kesin bir çarpışma olmaksızın onların geri çekilmesiyle sonuçlanmış ve Müslümanlar için bir zafer olmuştur. Burası Hendek Gazvesi\'nin yaklaşık olarak gerçekleştiği yerdir. Suudi Arabistan Krallığı bu alana özen göstermiş ve geliştirmiştir.',
      'id':
          'Perang Khandaq Perang Khandaq terjadi pada tahun kelima Hijriah, ketika beberapa kabilah bersekutu untuk melenyapkan kaum Muslimin. Jumlah kaum Muslimin sekitar 3.000 orang pejuang, sedangkan jumlah pasukan Al-Ahzab sekitar 10.000 orang pejuang. Salman al-Farisi mengusulkan agar digali parit di sekeliling Madinah, sehingga pasukan Al-Ahzab tidak mampu memasuki kota. Kemudian Allah mencerai-beraikan mereka dengan angin dan perselisihan di antara mereka. Perang tersebut berakhir dengan mundurnya mereka tanpa pertempuran yang menentukan, dan menjadi kemenangan bagi kaum Muslimin. Inilah lokasi perkiraan terjadinya Perang Khandaq. Kerajaan Arab Saudi telah memberikan perhatian terhadap lokasi ini serta melakukan pengembangannya.',
    },
    'مسجد الخليفة عمر بن الخطاب': {'en': '', 'tr': '', 'id': ''},
    'مسجد الخليفة أبي بكر': {'en': '', 'tr': '', 'id': ''},
    'مسجد سلمان الفارسي': {'en': '', 'tr': '', 'id': ''},
    'مسجد الخليفة علي بن أبي طالب': {'en': '', 'tr': '', 'id': ''},
    'مسجد سعد بن معاذ': {'en': '', 'tr': '', 'id': ''},
    'جبل بني عبيد': {
      'en':
          'Mount Banu Ubayd is a historical landmark in Al-Madinah Al-Munawwarah associated with a prominent event in the Prophetic biography during the Battle of the Trench (Al-Khandaq). It is located to the northeast of the Prophet\'s Mosque and forms part of the volcanic hills surrounding the city. The mountain derives its historical significance from the fact that it served as one of the defensive positions overlooking the battlefield during the Battle of the Trench. It also marks the location where Banu Ubayd resided, from whom the mountain takes its name. Today, the mountain remains one of the historical geographical landmarks connected with the events of the Prophetic biography and the military history of Al-Madinah Al-Munawwarah.',
      'tr':
          'Benî Ubeyd Dağı, Medine-i Münevvere\'de bulunan ve Hendek Gazvesi sırasında meydana gelen önemli bir Siyer-i Nebeviyye olayıyla bağlantılı tarihî bir simgedir. Nebevî Mescid\'in kuzeydoğusunda yer almakta olup, şehri çevreleyen volkanik tepelerin bir parçasını oluşturmaktadır. Dağ, Hendek Gazvesi sırasında savaş alanına hâkim savunma noktalarından biri olması sebebiyle tarihî önem kazanmıştır. Ayrıca adını, bu bölgede yaşayan Benî Ubeyd kabilesinden almaktadır. Günümüzde dağ, Siyer-i Nebeviyye olayları ve Medine-i Münevvere\'nin askerî tarihiyle bağlantılı tarihî coğrafi simgelerden biri olmaya devam etmektedir.',
      'id':
          'Jabal Bani Ubayd merupakan salah satu landmark bersejarah di Madinah yang berkaitan dengan peristiwa penting dalam sirah Nabi Muhammad ﷺ pada Perang Khandaq. Gunung ini terletak di sebelah timur laut Masjid Nabawi dan menjadi bagian dari perbukitan vulkanik yang mengelilingi kota Madinah. Gunung ini memiliki nilai sejarah karena menjadi salah satu posisi pertahanan yang mengawasi medan pertempuran pada Perang Khandaq. Gunung ini juga merupakan kawasan tempat tinggal Bani Ubayd, yang darinya gunung tersebut memperoleh namanya. Hingga kini, gunung ini tetap menjadi salah satu landmark geografis bersejarah yang berkaitan dengan peristiwa sirah Nabi Muhammad ﷺ dan sejarah militer Madinah.',
    },
    'جبل قرين الصريحة': {
      'en':
          'Mount Qurayn Al-Surayhah is an important historical site in Al-Madinah Al-Munawwarah. It is renowned for its close association with the Battle of the Trench (Al-Khandaq), as it overlooks part of the battlefield and forms one of the elevated natural positions surrounding the area. The mountain derives its historical significance from its strategic location, which enabled observation of the surrounding terrain during military events. It remains one of the geographical landmarks connected with the Prophetic biography and the historical topography of Al-Madinah Al-Munawwarah.',
      'tr':
          'Cebelü Kurayn es-Surayhah, Medine-i Münevvere\'de bulunan önemli tarihî bir mevkidir. Özellikle Hendek Gazvesi ile olan yakın bağlantısıyla tanınmaktadır. Savaş alanının bir bölümüne hâkim olup, bölgeyi çevreleyen doğal yüksek noktalardan birini oluşturmaktadır. Dağ, stratejik konumu sayesinde askerî olaylar sırasında çevrenin gözetlenmesine imkân sağlaması sebebiyle tarihî önem kazanmıştır. Günümüzde de Siyer-i Nebeviyye ve Medine-i Münevvere\'nin tarihî coğrafyasıyla bağlantılı önemli coğrafî simgelerden biri olmaya devam etmektedir.',
      'id':
          'Jabal Qurayn As-Surayhah merupakan salah satu lokasi bersejarah yang penting di Madinah. Gunung ini terkenal karena keterkaitannya yang erat dengan Perang Khandaq, sebab gunung ini menghadap ke sebagian medan pertempuran dan menjadi salah satu titik ketinggian alami yang mengelilingi kawasan tersebut. Gunung ini memiliki nilai sejarah karena letaknya yang strategis, sehingga memungkinkan pengawasan terhadap wilayah sekitarnya selama berlangsungnya berbagai peristiwa militer. Hingga kini, gunung ini tetap menjadi salah satu landmark geografis yang berkaitan dengan sirah Nabi Muhammad ﷺ dan topografi sejarah Madinah.',
    },
    'وادي العقيق المبارك': {
      'en':
          'The Blessed Wadi Al-Aqiq is one of the most famous valleys of Al-Madinah Al-Munawwarah and among its greatest geographical and historical landmarks. It extends from the south of the city to its northwest, passing through several districts before joining the valleys surrounding Al-Madinah. The valley is renowned for its fertile land, abundant water, and numerous farms, and it was one of the principal agricultural areas of Al-Madinah. Wadi Al-Aqiq derives its distinction from its close association with the Prophetic biography. The Prophet Muhammad ﷺ camped there, prayed in it, and described it as a "blessed valley." It is also the site where revelation came to him concerning entering into the state of ihram, and he instructed those intending Hajj or Umrah to assume ihram from Dhu Al-Hulayfah, located within the valley. Throughout history, the valley has been celebrated in historical sources and Arabic literature because of its natural beauty and historical significance. Today, despite extensive urban development, it remains one of the most prominent natural and historical landmarks of Al-Madinah Al-Munawwarah.',
      'tr':
          'Mübarek Vadi el-Akīk, Medine-i Münevvere\'nin en meşhur vadilerinden ve en önemli coğrafî ile tarihî simgelerinden biridir. Şehrin güneyinden başlayarak kuzeybatısına doğru uzanır, birçok bölgeden geçer ve Medine çevresindeki diğer vadilerle birleşir. Vadi; verimli toprakları, bol suları ve çok sayıdaki çiftlikleriyle tanınmış olup, Medine\'nin en önemli tarım bölgelerinden biri olmuştur. Vadi el-Akīk, Siyer-i Nebeviyye ile olan yakın bağlantısı sebebiyle ayrı bir değere sahiptir. Hz. Peygamber ﷺ burada konaklamış, namaz kılmış ve burayı "mübarek bir vadi" olarak nitelendirmiştir. Ayrıca ihrama girmeye dair vahyin burada geldiği rivayet edilmiş, hac ve umre yapmak isteyenlerin vadinin içinde bulunan Zülhuleyfe\'den ihrama girmelerini emretmiştir. Tarih boyunca tabii güzelliği ve tarihî değeri sebebiyle tarih kaynaklarında ve Arap edebiyatında geniş şekilde anılmıştır. Günümüzde yoğun şehirleşmeye rağmen Medine-i Münevvere\'nin en önemli doğal ve tarihî simgelerinden biri olmayı sürdürmektedir.',
      'id':
          'Wadi Al-Aqiq Al-Mubarak merupakan salah satu lembah yang paling terkenal di Madinah serta termasuk landmark geografis dan sejarah terpenting di kota tersebut. Lembah ini membentang dari bagian selatan Madinah menuju barat laut, melintasi sejumlah kawasan sebelum bergabung dengan lembah-lembah lain di sekitar Madinah. Lembah ini terkenal karena tanahnya yang subur, sumber airnya yang melimpah, serta banyaknya kebun dan lahan pertanian, sehingga menjadi salah satu kawasan pertanian utama di Madinah. Wadi Al-Aqiq memperoleh keistimewaannya karena kaitannya yang erat dengan sirah Nabi Muhammad ﷺ. Rasulullah ﷺ pernah singgah dan melaksanakan salat di lembah ini serta menyebutnya sebagai "lembah yang diberkahi." Di tempat ini pula beliau menerima wahyu mengenai ihram, dan beliau memerintahkan orang yang hendak menunaikan haji atau umrah untuk memulai ihram dari Dzul Hulaifah, yang terletak di dalam lembah tersebut. Sepanjang sejarah, lembah ini banyak dipuji dalam sumber-sumber sejarah dan sastra Arab karena keindahan alam serta nilai sejarahnya. Hingga kini, meskipun telah mengalami perkembangan perkotaan yang pesat, lembah ini tetap menjadi salah satu landmark alam dan sejarah yang paling penting di Madinah.',
    },
    'وادي قناة': {
      'en':
          'Wadi Qanat is one of the most famous valleys of Al-Madinah Al-Munawwarah.',
      'tr':
          'Vadi Kanât, Medine-i Münevvere\'nin en meşhur vadilerinden biridir.',
      'id':
          'Wadi Qanat merupakan salah satu lembah yang paling terkenal di Madinah.',
    },
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
    if (_currentLang == 'ar') return place.description;
    final normalizedName = _normalize(place.name);
    for (final entry in _descriptionMap.entries) {
      if (_normalize(entry.key) == normalizedName) {
        final desc = entry.value[_currentLang] ?? '';
        return desc.isNotEmpty ? desc : place.description;
      }
    }
    return place.description;
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
    'قصر عروة بن الزبير': 'قصور',
    'سوق المناخة': 'أسواق',
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
    if (text.contains('آطم') || text.contains('أطم') || text.contains('حصن'))
      return 'حصون وآطام';
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
        final description = cleanDescription(rawDescription);
        final mapsUrl = extractMapsUrl(rawDescription);
        final styleUrl =
            placemark.findElements('styleUrl').firstOrNull?.innerText.trim() ??
            '';
        final category = detectCategory(name, description, styleUrl);

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
            description: description,
            category: category,
            mapsUrl: mapsUrl,
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
    if (Platform.isIOS) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_t('افتح بـ', 'Open with', 'Aç', 'Buka dengan')),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                                  final appleUrl = location != null
                    ? 'maps://?q=${location.latitude},${location.longitude}'
                    : url;
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
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('Google Maps'),
            ),
          ],
        ),
      );
    } else {
      final uri = Uri.parse(url);
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
    final coordinates =
        '${place.location.latitude}, ${place.location.longitude}';
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_buildLangToggle()],
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
          const SizedBox(height: 10),
          buildCategoryChips(),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(blurRadius: 12, color: Colors.black26),
              ],
            ),
            child: Text(
              _currentLang == 'ar'
                  ? 'Nabawi Maps - ${filteredPlaces.length} موقع'
                  : _currentLang == 'tr'
                  ? 'Nabawi Maps — ${filteredPlaces.length} konum'
                  : _currentLang == 'id'
                  ? 'Nabawi Maps — ${filteredPlaces.length} lokasi'
                  : 'Nabawi Maps — ${filteredPlaces.length} locations',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0B5D3B),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
