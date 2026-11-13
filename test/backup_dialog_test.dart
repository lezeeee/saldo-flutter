import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/services/backup_files.dart';
import 'package:saldo/theme.dart';
import 'package:saldo/widgets/backup_dialog.dart';

class FakeFiles implements BackupFiles {
  BackupFile? selected;
  BackupSaveResult result = BackupSaveResult.saved;
  String? savedName;
  Uint8List? savedBytes;

  @override
  Future<BackupFile?> pick() async => selected;

  @override
  Future<BackupSaveResult> save(String name, Uint8List bytes) async {
    savedName = name;
    savedBytes = bytes;
    return result;
  }
}

Map<String, dynamic> sampleBackup() => {
  'app': 'saldo',
  'schemaVersion': 2,
  'createdAt': '2026-11-03T12:00:00.000Z',
  'entries': <Map<String, dynamic>>[],
  'budgets': <Map<String, dynamic>>[],
  'goals': <Map<String, dynamic>>[],
};

BackupFile jsonFile(Object value) => BackupFile(
  name: 'saldo-teste.json',
  bytes: Uint8List.fromList(utf8.encode(jsonEncode(value))),
);

Future<void> mountDialog(
  WidgetTester tester,
  FakeFiles files,
  Future<void> Function(Map<String, dynamic>) onImport,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: BackupDialog(
          files: files,
          onExport: () async => sampleBackup(),
          onImport: onImport,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('rejeita JSON inválido, envelope estranho e arquivo excessivo', () {
    expect(
      () => decodeBackup(Uint8List.fromList(utf8.encode('{'))),
      throwsFormatException,
    );
    expect(
      () => decodeBackup(jsonFile({'schemaVersion': 2}).bytes),
      throwsFormatException,
    );
    expect(
      () => decodeBackup(Uint8List(maxBackupBytes + 1)),
      throwsFormatException,
    );
    expect(decodeBackup(jsonFile(sampleBackup()).bytes), sampleBackup());
  });

  testWidgets('cancelar seletor não chama importação nem confirmação', (
    tester,
  ) async {
    var calls = 0;
    await mountDialog(tester, FakeFiles(), (_) async => calls++);
    await tester.tap(find.text('Restaurar backup'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Substituir seus dados?'), findsNothing);
    expect(
      find.text('Restauração cancelada. Nenhum dado foi alterado.'),
      findsOneWidget,
    );
  });

  testWidgets('arquivo inválido mostra erro sem abrir confirmação', (
    tester,
  ) async {
    var calls = 0;
    final files = FakeFiles()..selected = jsonFile(['outra estrutura']);
    await mountDialog(tester, files, (_) async => calls++);
    await tester.tap(find.text('Restaurar backup'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.textContaining('backup compatível'), findsOneWidget);
    expect(find.text('Substituir seus dados?'), findsNothing);
  });

  testWidgets('não substitui dados antes da confirmação nem após cancelar', (
    tester,
  ) async {
    var calls = 0;
    final files = FakeFiles()..selected = jsonFile(sampleBackup());
    await mountDialog(tester, files, (_) async => calls++);
    await tester.tap(find.text('Restaurar backup'));
    await tester.pumpAndSettle();
    expect(find.text('Substituir seus dados?'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('confirmar restaura uma vez o objeto selecionado', (
    tester,
  ) async {
    final imported = <Map<String, dynamic>>[];
    final files = FakeFiles()..selected = jsonFile(sampleBackup());
    await mountDialog(tester, files, (value) async => imported.add(value));
    await tester.tap(find.text('Restaurar backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Substituir e restaurar'));
    await tester.pumpAndSettle();
    expect(imported, [sampleBackup()]);
    expect(find.textContaining('Backup restaurado.'), findsOneWidget);
  });

  testWidgets('erro de validação do banco preserva diálogo com aviso', (
    tester,
  ) async {
    final files = FakeFiles()..selected = jsonFile(sampleBackup());
    await mountDialog(tester, files, (_) async {
      throw const FormatException('Valor inválido.');
    });
    await tester.tap(find.text('Restaurar backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Substituir e restaurar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Valor inválido. Nenhum dado foi alterado.'),
      findsOneWidget,
    );
    expect(find.text('Restaurar backup'), findsOneWidget);
  });

  testWidgets('exporta JSON e informa download sem afirmar gravação no disco', (
    tester,
  ) async {
    final files = FakeFiles()..result = BackupSaveResult.downloadRequested;
    await mountDialog(tester, files, (_) async {});
    await tester.tap(find.text('Exportar backup'));
    await tester.pumpAndSettle();
    expect(files.savedName, startsWith('saldo-backup-'));
    expect(jsonDecode(utf8.decode(files.savedBytes!)), sampleBackup());
    expect(
      find.text(
        'Download solicitado. Confira a pasta de downloads do navegador.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('exportação cancelada não é anunciada como salva', (
    tester,
  ) async {
    final files = FakeFiles()..result = BackupSaveResult.cancelled;
    await mountDialog(tester, files, (_) async {});
    await tester.tap(find.text('Exportar backup'));
    await tester.pumpAndSettle();
    expect(
      find.text('Exportação cancelada. Seus dados continuam no app.'),
      findsOneWidget,
    );
    expect(find.textContaining('Backup salvo.'), findsNothing);
  });
}
