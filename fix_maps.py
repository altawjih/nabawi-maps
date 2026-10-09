content = open('lib/main.dart', 'r', encoding='utf-8').read()

content = content.replace("import 'package:url_launcher/url_launcher.dart';", "import 'dart:io';\nimport 'package:url_launcher/url_launcher.dart';")

old = """Future<void> openMaps(String url) async {
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
  }"""

new = """Future<void> openMaps(String url) async {
    if (Platform.isIOS) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_t('افتح بـ', 'Open with', 'Aç', 'Buka dengan')),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final appleUrl = url
                    .replaceAll('https://maps.google.com', 'https://maps.apple.com')
                    .replaceAll('http://maps.google.com', 'https://maps.apple.com');
                final uri = Uri.parse(appleUrl);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: const Text('Apple Maps'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final uri = Uri.parse(url);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: const Text('Google Maps'),
            ),
          ],
        ),
      );
    } else {
      final uri = Uri.parse(url);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (not opened and mounted):
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
  }"""

if old in content:
    content = content.replace(old, new)
    open('lib/main.dart', 'w', encoding='utf-8').write(content)
    print('SUCCESS')
else:
    print('NOT FOUND')
