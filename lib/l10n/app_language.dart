import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'catalog.dart';

class AppLanguage extends ValueNotifier<Locale> {
  AppLanguage._() : super(const Locale('ar'));
  static final instance = AppLanguage._();
  static const preferenceKey = 'app_language';

  Future<void> load() async {
    final stored = (await SharedPreferences.getInstance()).getString(preferenceKey);
    value = Locale(stored == 'en' ? 'en' : 'ar');
  }

  Future<void> select(String code) async {
    if (code != 'ar' && code != 'en') return;
    value = Locale(code);
    await (await SharedPreferences.getInstance()).setString(preferenceKey, code);
  }
}

final _arabicToEnglish = {for (final e in englishToArabic.entries) e.value: e.key};

String translateFor(String value, String language) {
  final english = _arabicToEnglish[value] ?? value;
  if (language != 'ar') {
    final money = RegExp(r'^([\d.,]+) ر\.س$').firstMatch(english);
    if (english.startsWith('طلب خدمة ')) return 'Service request: ${english.substring(9)}';
    return money == null ? english : 'SAR ${money[1]}';
  }
  if (englishToArabic.containsKey(english)) return englishToArabic[english]!;
  if (english.contains(', ') && english.split(', ').every(englishToArabic.containsKey)) return english.split(', ').map((s) => translateFor(s, language)).join('، ');
  if (english.contains(' • ')) return english.split(' • ').map((s) => translateFor(s, language)).join(' • ');
  final prefixes = <String, String>{'Customer: ': 'العميل: ', 'Provider: ': 'مقدم الخدمة: ', 'Phone: ': 'الهاتف: ', 'by ': 'بواسطة '};
  for (final e in prefixes.entries) {
    if (english.startsWith(e.key)) return e.value + english.substring(e.key.length);
  }
  final money = RegExp(r'^SAR ([\d.,]+)(?: / (.*))?$').firstMatch(english);
  if (money != null) return '${money[1]} ر.س${money[2] == null ? '' : ' / ${translateFor(money[2]!, language)}'}';
  final years = RegExp(r'^(\d+) yrs$').firstMatch(english);
  if (years != null) return '${years[1]} سنوات';
  final ago = RegExp(r'^(\d+)([dhm]) ago$').firstMatch(english);
  if (ago != null) {
    final n = int.parse(ago[1]!);
    final units = {'d': ['يوم', 'يومين', 'أيام'], 'h': ['ساعة', 'ساعتين', 'ساعات'], 'm': ['دقيقة', 'دقيقتين', 'دقائق']}[ago[2]]!;
    return n == 1 ? 'منذ ${units[0]}' : n == 2 ? 'منذ ${units[1]}' : 'منذ $n ${n <= 10 ? units[2] : units[0]}';
  }
  if (english.startsWith('Location selected ✓')) return english.replaceFirst('Location selected ✓', 'تم اختيار الموقع ✓');
  if (english.startsWith('The request could not be completed (')) return english.replaceFirst('The request could not be completed', 'تعذر إتمام الطلب');
  for (final prefix in ['Could not fetch location: ', 'Location fetch error: ', 'Something went wrong: ', 'Error: ']) {
    if (english.startsWith(prefix)) return 'تعذر إتمام العملية. حاول مجددًا.';
  }
  return value;
}

String tr(BuildContext context, String value) => translateFor(value, Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar');

/// Translates explicitly selected UI copy while preserving const widget trees.
class LText extends StatelessWidget {
  const LText(this.data, {super.key, this.style, this.textAlign, this.textDirection, this.maxLines, this.overflow, this.softWrap});
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  @override
  Widget build(BuildContext context) => Text(tr(context, data), style: style, textAlign: textAlign, textDirection: textDirection, maxLines: maxLines, overflow: overflow, softWrap: softWrap);
}

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: tr(context, 'Language'),
    icon: const Icon(Icons.language),
    initialValue: Localizations.localeOf(context).languageCode,
    onSelected: (code) { AppLanguage.instance.select(code); },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'ar', child: Text('العربية', textDirection: TextDirection.rtl)),
      PopupMenuItem(value: 'en', child: Text('English', textDirection: TextDirection.ltr)),
    ],
  );
}
