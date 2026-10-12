import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../device/connection_controller.dart';
import '../../vehicle/vehicle.dart';
import '../../vehicle/vehicle_repository.dart';
import '../widgets/common.dart';

class VehicleEditorScreen extends StatefulWidget {
  const VehicleEditorScreen({super.key, this.vehicle});
  final Vehicle? vehicle;

  static Future<void> open(BuildContext context, {Vehicle? vehicle}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => VehicleEditorScreen(vehicle: vehicle),
        ),
      );

  @override
  State<VehicleEditorScreen> createState() => _VehicleEditorScreenState();
}

class _VehicleEditorScreenState extends State<VehicleEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _make = TextEditingController(text: widget.vehicle?.make);
  late final _model = TextEditingController(text: widget.vehicle?.model);
  late final _year = TextEditingController(
    text: widget.vehicle?.year?.toString(),
  );
  late final _engine = TextEditingController(text: widget.vehicle?.engine);
  late final _nickname = TextEditingController(text: widget.vehicle?.nickname);
  late final _vin = TextEditingController(text: widget.vehicle?.vin);
  bool _readingVin = false;
  String? _vinNote;

  @override
  void dispose() {
    for (final c in [_make, _model, _year, _engine, _nickname, _vin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _readVin() async {
    final session = context.read<ConnectionController>().session;
    if (session == null) return;
    setState(() {
      _readingVin = true;
      _vinNote = null;
    });
    try {
      final vin = await session.readVin();
      setState(() {
        if (vin == null) {
          _vinNote = 'This vehicle did not report a VIN. You can type it in from the windscreen or registration papers.';
        } else {
          _vin.text = vin;
          _vinNote = 'VIN read from the vehicle.';
        }
      });
    } on AppException catch (e) {
      setState(() => _vinNote = e.userMessage);
    } finally {
      if (mounted) setState(() => _readingVin = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<VehicleRepository>();
    final nav = Navigator.of(context);
    final year = int.tryParse(_year.text.trim());
    final vin = _vin.text.trim().toUpperCase();
    final existing = widget.vehicle;
    if (existing == null) {
      await repo.add(
        make: _make.text,
        model: _model.text,
        year: year,
        engine: _engine.text,
        vin: vin.isEmpty ? null : vin,
        nickname: _nickname.text,
      );
    } else {
      await repo.update(
        existing.copyWith(
          make: _make.text.trim(),
          model: _model.text.trim(),
          year: year,
          engine: _engine.text.trim(),
          nickname: _nickname.text.trim(),
          vin: vin.isEmpty ? null : vin,
          clearVin: vin.isEmpty,
        ),
      );
    }
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<ConnectionController>().isReady;
    final isNew = widget.vehicle == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Add vehicle' : 'Edit vehicle'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _field(_make, 'Manufacturer', 'e.g. Toyota', required: true),
              _field(_model, 'Model', 'e.g. HiLux', required: true),
              _field(
                _year,
                'Year',
                'e.g. 2019',
                keyboard: TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final y = int.tryParse(v);
                  final max = DateTime.now().year + 1;
                  if (y == null || y < 1980 || y > max) {
                    return 'Enter a year between 1980 and $max';
                  }
                  return null;
                },
              ),
              _field(_engine, 'Engine', 'e.g. 2.8L turbo diesel'),
              _field(_nickname, 'Nickname (optional)', 'e.g. Work ute'),
              const SectionTitle('VIN (optional)'),
              TextFormField(
                controller: _vin,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp('[A-HJ-NPR-Za-hj-npr-z0-9]'),
                  ),
                  LengthLimitingTextInputFormatter(17),
                ],
                decoration: const InputDecoration(
                  labelText: 'Vehicle Identification Number',
                ),
                validator: (v) {
                  final s = (v ?? '').trim().toUpperCase();
                  if (s.isEmpty) return null;
                  return Vehicle.vinPattern.hasMatch(s)
                      ? null
                      : 'A VIN has 17 letters and numbers (no I, O or Q)';
                },
              ),
              const SizedBox(height: 10),
              if (connected)
                OutlinedButton.icon(
                  onPressed: _readingVin ? null : _readVin,
                  icon: _readingVin
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Read VIN from vehicle'),
                ),
              if (_vinNote != null) ...[
                const SizedBox(height: 8),
                InfoNote(text: _vinNote!),
              ],
              const SizedBox(height: 10),
              const InfoNote(
                icon: Icons.lock_outline,
                text:
                    'Your VIN is stored only on this phone. It is never sent to '
                    'the AI mechanic and is hidden in shared reports and logs.',
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _save,
                child: Text(isNew ? 'Add to garage' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    String hint, {
    bool required = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      inputFormatters: formatters,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(color: BrandColors.white),
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator:
          validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty)
                    ? '$label is required'
                    : null
              : null),
    ),
  );
}
