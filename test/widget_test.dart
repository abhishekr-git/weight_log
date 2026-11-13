import 'package:flutter_test/flutter_test.dart';
import 'package:weightlog/app/weightlog_app.dart';

void main() {
  testWidgets('WeightLog app can be constructed', (tester) async {
    expect(const WeightLogApp(), isA<WeightLogApp>());
  });
}
