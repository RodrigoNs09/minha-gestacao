import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _proibidos = <String, RegExp>{
  'IA': RegExp(r'(?<![\p{L}\p{N}_])IA(?![\p{L}\p{N}_])', unicode: true),
  'inteligência artificial': RegExp(
    r'intelig[eê]ncia\s+artificial',
    caseSensitive: false,
    unicode: true,
  ),
  'Inteligente': RegExp('inteligente', caseSensitive: false),
  'insight': RegExp('insight', caseSensitive: false),
  'assistente': RegExp('assistente', caseSensitive: false),
};

List<String> termosEm(String texto) => [
  for (final proibido in _proibidos.entries)
    if (proibido.value.hasMatch(texto)) proibido.key,
];

List<File> arquivosDeLib() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((arquivo) => arquivo.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  group('O app não se apresenta como IA nem como assistente', () {
    test('nenhum texto de lib/ usa os termos proibidos', () {
      final ocorrencias = <String>[];

      for (final arquivo in arquivosDeLib()) {
        final caminho = arquivo.path.replaceAll(Platform.pathSeparator, '/');
        final linhas = arquivo.readAsLinesSync();
        for (var i = 0; i < linhas.length; i++) {
          if (linhas[i].trimLeft().startsWith('//')) continue;
          for (final termo in termosEm(linhas[i])) {
            ocorrencias.add('$caminho:${i + 1}: $termo');
          }
        }
      }

      expect(ocorrencias, isEmpty);
    });

    test('a varredura alcança o app inteiro', () {
      final caminhos = arquivosDeLib()
          .map(
            (arquivo) => arquivo.path.replaceAll(Platform.pathSeparator, '/'),
          )
          .toList();

      expect(caminhos, contains('lib/main.dart'));
      expect(caminhos, contains('lib/screens/contracao_screen.dart'));
      expect(caminhos, contains('lib/widgets/aviso_de_saude.dart'));
      expect(caminhos.length, greaterThan(30));
    });

    test('pega os rótulos que o app já teve', () {
      for (final texto in [
        'Assistente IA',
        'IA · Online',
        'Padrões e insights com IA',
        'INSIGHT DA IA',
        'Análise Inteligente',
        'Assistente de Dúvidas',
        'Tire dúvidas com apoio de IA',
        'Feito com Inteligência Artificial',
        'apoio de inteligencia  artificial',
        '(IA)',
      ]) {
        expect(termosEm(texto), isNotEmpty, reason: texto);
      }
    });

    test('a sigla só conta em maiúsculas e como palavra inteira', () {
      for (final texto in [
        'dia',
        'Dia',
        'DIA',
        'média',
        'MÉDIA',
        'Família',
        'FAMÍLIA',
        'IDÉIA',
        'Diário',
        'ia',
        'Ia',
        'VIA',
        'IAS',
        'intervaloMedio',
        'Registre o seu dia',
      ]) {
        expect(termosEm(texto), isEmpty, reason: texto);
      }
    });
  });
}
