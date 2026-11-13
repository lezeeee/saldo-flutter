# Saldo

Aplicativo acadêmico de finanças pessoais desenvolvido em Dart e Flutter. Permite acompanhar o resultado mensal, planejar gastos por categoria e acompanhar metas em reais ou dólares.

## Funcionalidades

- Cadastro, edição e exclusão de receitas e despesas, com pesquisa e controle de pagamentos pendentes.
- Resumo mensal com resultado realizado e previsão considerando as pendências.
- Limites por categoria e metas de economia em BRL ou USD.
- Cotação de referência USD/BRL pela API Frankfurter, com a data de referência informada pelo provedor.
- Persistência local em SQLite e exportação e restauração de backup JSON.

## Como executar

O projeto foi desenvolvido com Flutter 3.41.5 e Dart 3.11.3. Na pasta que contém pubspec.yaml, execute:

```sh
flutter pub get
flutter run -d chrome
```

Para Android, inicie um emulador, consulte o identificador com `flutter devices` e execute `flutter run -d ID_DO_EMULADOR`. O aplicativo cria o banco automaticamente. A consulta de câmbio usa internet e dispensa chave de API.

## Organização

As pastas `lib/screens` e `lib/widgets` contêm a interface. Em `lib/models` ficam os modelos e os cálculos do mês. O repositório SQLite fica em `lib/data`, e a integração HTTP em `lib/services`.

## Testes

```sh
flutter test
```
