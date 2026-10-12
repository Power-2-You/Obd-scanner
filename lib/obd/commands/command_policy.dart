/// Allow-list of everything the app is permitted to send to a scanner.
///
/// Enforced in [ElmChannel] for every command, so no screen or future feature
/// can accidentally transmit something outside this list. In particular the
/// following are impossible by construction:
///  * Mode 04 – clear trouble codes / reset emission monitors
///  * Mode 08 – on-board actuator control
///  * UDS services (0x10, 0x11, 0x27, 0x2E, 0x2F, 0x31, 0x34-0x37, 0x3B …) –
///    session control, ECU reset, security access (immobiliser), coding,
///    routines, flashing
///  * Adapter commands that change persistent adapter settings or the bus
///    (ATPP, ATSH, ATCRA, ATMA, ATWS/ATD …)
class CommandPolicy {
  const CommandPolicy._();

  static const Set<String> allowedAt = {
    'ATZ', // reset interpreter (soft reset, identification banner)
    'ATI', // identify
    'ATE0', // echo off
    'ATL0', // linefeeds off
    'ATS0', // spaces off
    'ATH1', // headers on (identify responding ECU)
    'ATSP0', // automatic protocol selection
    'ATDP', // describe protocol
    'ATDPN', // describe protocol by number
    'ATRV', // read voltage at OBD pin 16
  };

  /// Read-only OBD-II services (SAE J1979).
  static const Set<String> allowedModes = {
    '01', // current data
    '03', // stored DTCs
    '07', // pending DTCs
    '0A', // permanent DTCs
  };

  static const Set<String> allowedMode09Pids = {'00', '02'};

  static final RegExp _hex = RegExp(r'^[0-9A-F]+$');

  static bool isAllowed(String command) {
    final c = command.replaceAll(' ', '').toUpperCase();
    if (c.startsWith('AT')) return allowedAt.contains(c);
    if (!_hex.hasMatch(c) || c.length < 2 || c.length.isOdd) return false;
    final mode = c.substring(0, 2);
    if (mode == '09') {
      return c.length == 4 && allowedMode09Pids.contains(c.substring(2));
    }
    if (!allowedModes.contains(mode)) return false;
    if (mode == '01') return c.length == 4;
    return c.length == 2;
  }
}
