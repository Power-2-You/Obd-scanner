/// OBD-II bus protocols as numbered by the ELM327 `ATSP`/`ATDPN` commands
/// (ELM327 datasheet, "Protocols").
enum ObdProtocol {
  auto(0, 'Automatic'),
  j1850Pwm(1, 'SAE J1850 PWM (41.6 kbaud)'),
  j1850Vpw(2, 'SAE J1850 VPW (10.4 kbaud)'),
  iso9141(3, 'ISO 9141-2 (5 baud init)'),
  kwp5Baud(4, 'ISO 14230-4 KWP (5 baud init)'),
  kwpFast(5, 'ISO 14230-4 KWP (fast init)'),
  can11x500(6, 'ISO 15765-4 CAN (11 bit, 500 kbaud)'),
  can29x500(7, 'ISO 15765-4 CAN (29 bit, 500 kbaud)'),
  can11x250(8, 'ISO 15765-4 CAN (11 bit, 250 kbaud)'),
  can29x250(9, 'ISO 15765-4 CAN (29 bit, 250 kbaud)'),
  j1939(10, 'SAE J1939 CAN (29 bit, 250 kbaud)'),
  user1Can(11, 'USER1 CAN'),
  user2Can(12, 'USER2 CAN'),
  unknown(-1, 'Unknown');

  const ObdProtocol(this.number, this.label);

  final int number;
  final String label;

  bool get isCan => number >= 6 && number <= 12;
  bool get isCan29Bit =>
      this == can29x500 || this == can29x250 || this == j1939;
  bool get isLegacy => number >= 1 && number <= 5;

  /// Parses the reply to `ATDPN`, e.g. `A6` (automatic, currently 6) or `6`.
  static ObdProtocol fromDpn(String reply) {
    var r = reply.trim().toUpperCase();
    if (r.length == 2 && r.startsWith('A')) r = r.substring(1);
    if (r.length != 1) return unknown;
    final n = int.tryParse(r, radix: 16);
    if (n == null) return unknown;
    return values.firstWhere((p) => p.number == n, orElse: () => unknown);
  }
}
