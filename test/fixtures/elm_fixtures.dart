/// SYNTHETIC response fixtures, hand-built from the frame formats in the
/// ELM327 datasheet and ISO 15765-4 / SAE J1979. They are NOT recordings from
/// the Boost N' Inflate IQ. Add real captures to test/fixtures/recorded/ once
/// hardware is available, and keep these as regression cases.
class ElmFixtures {
  // ----------------------------------------------------- CAN 11-bit, H1 S0
  /// 0100 with echo still on and SEARCHING (first OBD request after ATSP0).
  static const supportedPidsSearching =
      '0100\rSEARCHING...\r7E8064100BE3FA81300\r\r';

  /// 010C, single ECU, padded to 8 data bytes. 0x1AF8 / 4 = 1726 rpm.
  static const rpm1726 = '7E804410C1AF8000000\r\r';

  /// 010C answered by engine (7E8) and transmission (7E9).
  static const rpmTwoEcus = '7E804410C0FA0000000\r7E904410C0FA4000000\r\r';

  /// Same, with spaces on (ATS1) – parser must cope.
  static const rpmWithSpaces = '7E8 04 41 0C 1A F8 00 00 00\r\r';

  /// Mode 03 with 4 DTCs (P0301 P0420 P0171 U0100) – ISO-TP multi-frame.
  /// Payload: 43 04 03 01 04 20 01 71 C1 00  (10 bytes)
  static const dtcsMultiFrame = '7E8100A430403010420\r7E8210171C100000000\r\r';

  /// Mode 03, no codes.
  static const dtcsNone = '7E80243000000000000\r\r';

  /// VIN (mode 09 PID 02) – synthetic VIN MGHDEM00000000001.
  static const vinMultiFrame =
      '7E81014490201'
      '4D4748\r7E82144454D30303030\r7E82230303030303031\r\r';

  /// 29-bit CAN, engine at source address 10.
  static const rpm29Bit = '18DAF11004410C1AF8000000\r\r';

  // ------------------------------------------------------- Legacy, H1 S0
  /// ISO 9141-2: `48 6B 10 41 0C 1A F8 <checksum>`
  static String get legacyRpm {
    final bytes = [0x48, 0x6B, 0x10, 0x41, 0x0C, 0x1A, 0xF8];
    final cs = bytes.fold<int>(0, (a, b) => a + b) & 0xFF;
    return '${_hex([...bytes, cs])}\r\r';
  }

  /// ISO 9141-2 mode 03 with 4 codes across two frames.
  static String get legacyDtcs {
    final f1 = [0x48, 0x6B, 0x10, 0x43, 0x03, 0x01, 0x04, 0x20, 0x01, 0x71];
    final f2 = [0x48, 0x6B, 0x10, 0x43, 0xC1, 0x00, 0x00, 0x00, 0x00, 0x00];
    int cs(List<int> b) => b.fold<int>(0, (a, x) => a + x) & 0xFF;
    return '${_hex([...f1, cs(f1)])}\r${_hex([...f2, cs(f2)])}\r\r';
  }

  // ------------------------------------------------------------- Errors
  static const noData = 'NO DATA\r\r';
  static const unableToConnect = 'SEARCHING...\rUNABLE TO CONNECT\r\r';
  static const busInitError = 'BUS INIT: ...ERROR\r\r';
  static const unknownCommand = '?\r\r';
  static const stopped = 'STOPPED\r\r';
  static const corruptFrame = '7E804410C1AF8000000<DATA ERROR\r\r';

  /// First frame announces 20 bytes but only one consecutive frame arrives.
  static const partialMultiFrame =
      '7E81014490201414243\r7E8214445464748494A\r\r';

  /// Consecutive frame sequence jumps from 1 to 3.
  static const outOfOrder =
      '7E81014490201414243\r7E8214445464748494A\r7E8234B4C4D4E4F5051\r\r';

  /// Garbage that is not hex.
  static const malformedLine = '7E8ZZ410C\r\r';

  static String _hex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();
}
