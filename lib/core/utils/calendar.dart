import 'package:intl/intl.dart';

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime startOfWeek(DateTime value) {
  final day = dateOnly(value);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime dayInCurrentWeek(int weekday, {DateTime? now}) {
  return startOfWeek(now ?? DateTime.now()).add(Duration(days: weekday - 1));
}

String weekdayLabel(int weekday) {
  const labels = {
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };
  return labels[weekday] ?? 'Day';
}

String compactDate(DateTime value) => DateFormat('EEE, MMM d').format(value);
