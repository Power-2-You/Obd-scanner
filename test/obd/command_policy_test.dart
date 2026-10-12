import 'package:flutter_test/flutter_test.dart';
import 'package:my_garage_hero_iq/obd/commands/command_policy.dart';

void main() {
  test('allows the read-only command set', () {
    for (final c in [
      'ATZ',
      'ATE0',
      'ATL0',
      'ATS0',
      'ATH1',
      'ATSP0',
      'ATDPN',
      'ATRV',
      '0100',
      '010C',
      '0142',
      '03',
      '07',
      '0A',
      '0902',
    ]) {
      expect(CommandPolicy.isAllowed(c), isTrue, reason: c);
    }
  });

  test('blocks clearing codes, actuator control, UDS and adapter writes', () {
    for (final c in [
      '04', // clear DTCs
      '08', '0801', // actuator control
      '1003', '1101', '2701', '2EF190', '2F', '3101', '34', '36', '3B', // UDS
      'ATPP0CSV', 'ATSH7E0', 'ATMA', 'ATWS', 'ATD', 'STFAC', // adapter
      '0904', '010C0D', // outside allow-list
      '', 'ZZ',
    ]) {
      expect(CommandPolicy.isAllowed(c), isFalse, reason: c);
    }
  });
}
