import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/backup_files.dart';
import '../theme.dart';

class BackupDialog extends StatefulWidget {
  const BackupDialog({
    super.key,
    required this.onExport,
    required this.onImport,
    this.files,
  });

  final Future<Map<String, dynamic>> Function() onExport;
  final Future<void> Function(Map<String, dynamic>) onImport;
  final BackupFiles? files;

  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  late final BackupFiles _files;
  bool _busy = false;
  bool _confirming = false;
  bool _isError = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _files = widget.files ?? DeviceBackupFiles();
  }

  void _start() => setState(() {
    _busy = true;
    _status = null;
    _isError = false;
  });

  void _finish(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _confirming = false;
      _status = message;
      _isError = error;
    });
  }

  Future<void> _export() async {
    _start();
    try {
      final backup = await widget.onExport();
      final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(backup)),
      );
      final stamp = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceAll(':', '-');
      final result = await _files.save('saldo-backup-$stamp.json', bytes);
      _finish(switch (result) {
        BackupSaveResult.saved =>
          'Backup salvo. Guarde o arquivo em um local de sua confiança.',
        BackupSaveResult.downloadRequested =>
          'Download solicitado. Confira a pasta de downloads do navegador.',
        BackupSaveResult.cancelled =>
          'Exportação cancelada. Seus dados continuam no app.',
      });
    } catch (_) {
      _finish(
        'Não foi possível exportar o backup. Tente novamente.',
        error: true,
      );
    }
  }

  Future<void> _import() async {
    _start();
    try {
      final file = await _files.pick();
      if (!mounted) return;
      if (file == null) {
        _finish('Restauração cancelada. Nenhum dado foi alterado.');
        return;
      }
      final backup = decodeBackup(file.bytes);
      final entries = (backup['entries'] as List).length;
      final goals = (backup['goals'] as List).length;
      if (!mounted) return;
      setState(() => _confirming = true);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Substituir seus dados?'),
          content: SingleChildScrollView(
            child: Text(
              'O arquivo “${file.name}” contém $entries lançamento(s) e $goals meta(s).\n\n'
              'A restauração substitui TODOS os lançamentos, limites e metas deste dispositivo. '
              'Exporte seus dados atuais antes de continuar se quiser guardá-los.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Substituir e restaurar'),
            ),
          ],
        ),
      );
      if (mounted) setState(() => _confirming = false);
      if (confirmed != true) {
        _finish('Restauração cancelada. Nenhum dado foi alterado.');
        return;
      }
      await widget.onImport(backup);
      _finish(
        'Backup restaurado. Seus lançamentos, limites e metas foram atualizados.',
      );
    } on FormatException catch (error) {
      _finish('${error.message} Nenhum dado foi alterado.', error: true);
    } catch (_) {
      _finish(
        'Não foi possível concluir a restauração. Reabra o app para conferir seus dados e tente novamente.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Seus dados, com você.'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Guarde uma cópia ou leve seus registros para outro dispositivo.',
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: canvas,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.folder_copy_outlined, color: green, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'O arquivo JSON inclui lançamentos, limites e metas. Ele contém seus registros financeiros e não possui senha.',
                        style: TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Exportar backup'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Restaurar backup'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Arquivos .json de até 5 MB. A restauração pede confirmação antes de substituir seus dados.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.5),
              ),
              if (_busy && !_confirming)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: LinearProgressIndicator(),
                ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _status!,
                      style: TextStyle(
                        color: _isError ? coral : green,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );
}
