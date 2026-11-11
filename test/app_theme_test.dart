import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hifz_helper/app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('Arabic styles do not inherit letter spacing from the UI theme', () {
    expect(AppTheme.arabicStyle().letterSpacing, 0);
    expect(AppTheme.arabicStyle(script: 'indopak').letterSpacing, 0);
  });
}
