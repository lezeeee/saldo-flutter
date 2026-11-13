import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

const maxBackupBytes = 5 * 1024 * 1024;

class BackupFile {
  const BackupFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

enum BackupSaveResult { saved, downloadRequested, cancelled }

/// Fronteira com o sistema de arquivos. A interface pode usar um substituto nos
/// testes, sem abrir seletores nativos nem acessar arquivos de outra pessoa.
abstract class BackupFiles {
  Future<BackupFile?> pick();
  Future<BackupSaveResult> save(String name, Uint8List bytes);
}

class DeviceBackupFiles implements BackupFiles {
  @override
  Future<BackupFile?> pick() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Escolha um backup do Saldo',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    final size = file.lengthSync() ?? await file.length();
    if (size != null && size > maxBackupBytes) {
      throw const FormatException('O arquivo deve ter no máximo 5 MB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBackupBytes) {
      throw const FormatException('O arquivo deve ter no máximo 5 MB.');
    }
    return BackupFile(name: file.name, bytes: bytes);
  }

  @override
  Future<BackupSaveResult> save(String name, Uint8List bytes) async {
    final location = await FilePicker.saveFile(
      dialogTitle: 'Salvar backup do Saldo',
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
    );
    // No modo web padrão o plugin inicia o download e retorna null mesmo no
    // sucesso. Não confundimos isso com cancelamento do seletor nativo.
    // O navegador confirma o pedido, não a gravação final no disco.
    if (kIsWeb) return BackupSaveResult.downloadRequested;
    return location == null
        ? BackupSaveResult.cancelled
        : BackupSaveResult.saved;
  }
}

/// Validação de envelope antes de pedir confirmação. O banco faz a validação
/// completa dos campos e restaura tudo em uma única transação.
Map<String, dynamic> decodeBackup(Uint8List bytes) {
  if (bytes.length > maxBackupBytes) {
    throw const FormatException('O arquivo deve ter no máximo 5 MB.');
  }
  final dynamic json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const FormatException('O arquivo não contém um JSON válido.');
  }
  if (json is! Map<String, dynamic> ||
      json['app'] != 'saldo' ||
      json['schemaVersion'] != 2 ||
      json['entries'] is! List ||
      json['goals'] is! List ||
      json['budgets'] is! List) {
    throw const FormatException(
      'Este arquivo não é um backup compatível do Saldo.',
    );
  }
  return json;
}
