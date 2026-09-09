import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/models/contracao.dart';

void main() {
  group('Contracao.duracaoSegundosDe — casos canônicos', () {
    test('Duração: 01:30 → 90s', () {
      expect(Contracao.duracaoSegundosDe('Duração: 01:30'), 90);
    });

    test('Duração: 01:30 | dor lombar → 90s (anotação não interfere)', () {
      expect(Contracao.duracaoSegundosDe('Duração: 01:30 | dor lombar'), 90);
    });

    test('Duração: 105:30 → 6330s (regressão da regex de 2 dígitos)', () {
      expect(Contracao.duracaoSegundosDe('Duração: 105:30'), 6330);
    });

    test('Duração: 00:00 → 0s, e 0 é distinto de null', () {
      final resultado = Contracao.duracaoSegundosDe('Duração: 00:00');
      expect(resultado, 0);
      expect(resultado, isNotNull);
    });

    test('minutos com 1 dígito são aceitos', () {
      expect(Contracao.duracaoSegundosDe('Duração: 1:30'), 90);
    });

    test('minutos com 3 dígitos no limite superior', () {
      expect(Contracao.duracaoSegundosDe('Duração: 999:59'), 59999);
    });

    test('espaçamento variável após o rótulo', () {
      expect(Contracao.duracaoSegundosDe('Duração:01:30'), 90);
      expect(Contracao.duracaoSegundosDe('Duração:   01:30'), 90);
      expect(Contracao.duracaoSegundosDe('Duração:\t01:30'), 90);
    });
  });

  group('Contracao.duracaoSegundosDe — texto com acento e emoji', () {
    test('anotação com emoji não quebra a derivação', () {
      expect(
        Contracao.duracaoSegundosDe('Duração: 02:15 | dor forte 😣 e náusea'),
        135,
      );
    });

    test('anotação só com emoji', () {
      expect(Contracao.duracaoSegundosDe('Duração: 03:05 | 🤰🤱💜'), 185);
    });

    test('anotação com acentuação pesada e cedilha', () {
      expect(
        Contracao.duracaoSegundosDe(
          'Duração: 00:45 | contração muito intensa, pressão na região lombar',
        ),
        45,
      );
    });

    test('emoji antes do padrão não impede o casamento', () {
      expect(Contracao.duracaoSegundosDe('😖 Duração: 01:00'), 60);
    });
  });

  group('Contracao.duracaoSegundosDe — entradas inválidas retornam null', () {
    test('string vazia', () {
      expect(Contracao.duracaoSegundosDe(''), isNull);
    });

    test('null', () {
      expect(Contracao.duracaoSegundosDe(null), isNull);
    });

    test('anotação sem prefixo', () {
      expect(Contracao.duracaoSegundosDe('anotação sem prefixo'), isNull);
    });

    test('Duração: ab:cd', () {
      expect(Contracao.duracaoSegundosDe('Duração: ab:cd'), isNull);
    });

    test('rótulo sem valor', () {
      expect(Contracao.duracaoSegundosDe('Duração:'), isNull);
      expect(Contracao.duracaoSegundosDe('Duração: '), isNull);
    });

    test('segundos fora da faixa (>= 60) são rejeitados', () {
      // Preferimos "desconhecido" a converter um valor incoerente.
      expect(Contracao.duracaoSegundosDe('Duração: 01:75'), isNull);
      expect(Contracao.duracaoSegundosDe('Duração: 01:99'), isNull);
    });

    test('segundos com menos de 2 dígitos', () {
      expect(Contracao.duracaoSegundosDe('Duração: 01:5'), isNull);
    });

    test('minutos com mais de 3 dígitos', () {
      expect(Contracao.duracaoSegundosDe('Duração: 1050:30'), isNull);
    });

    test('sequência de dígitos longa não é truncada', () {
      expect(Contracao.duracaoSegundosDe('Duração: 01:530'), isNull);
    });

    test('minutos negativos não são aceitos', () {
      expect(Contracao.duracaoSegundosDe('Duração: -1:30'), isNull);
    });

    test('separador diferente de dois-pontos', () {
      expect(Contracao.duracaoSegundosDe('Duração: 01-30'), isNull);
      expect(Contracao.duracaoSegundosDe('Duração: 01.30'), isNull);
    });

    test('rótulo sem acento não é reconhecido (comportamento documentado)', () {
      expect(Contracao.duracaoSegundosDe('Duracao: 01:30'), isNull);
    });
  });

  group('Contracao — classificação por origem da duração', () {
    Contracao criar({String observacoes = '', int? duracaoSegundos}) {
      return Contracao(
        inicio: '08:00',
        fim: '08:02',
        intensidade: 'Forte',
        observacoes: observacoes,
        data: '2026-01-15',
        duracaoSegundos: duracaoSegundos,
      );
    }

    test('campo tipado tem precedência sobre o texto legado', () {
      final c = criar(observacoes: 'Duração: 01:30', duracaoSegundos: 200);
      expect(c.duracaoSegundos, 200);
      expect(c.origemDuracao, OrigemDuracao.campo);
    });

    test('sem campo tipado, deriva do texto legado', () {
      final c = criar(observacoes: 'Duração: 01:30');
      expect(c.duracaoSegundos, 90);
      expect(c.origemDuracao, OrigemDuracao.observacoes);
    });

    test('sem campo e sem padrão reconhecível → indisponivel', () {
      final c = criar(observacoes: 'só uma anotação');
      expect(c.duracaoSegundos, isNull);
      expect(c.origemDuracao, OrigemDuracao.indisponivel);
    });

    test(
      'campo tipado igual a zero é respeitado, não tratado como ausente',
      () {
        final c = criar(observacoes: 'Duração: 05:00', duracaoSegundos: 0);
        expect(c.duracaoSegundos, 0);
        expect(c.origemDuracao, OrigemDuracao.campo);
      },
    );

    test('campo tipado negativo é descartado e cai na derivação', () {
      final c = criar(observacoes: 'Duração: 01:30', duracaoSegundos: -5);
      expect(c.duracaoSegundos, 90);
      expect(c.origemDuracao, OrigemDuracao.observacoes);
    });
  });

  group('Contracao.duracaoFormatada', () {
    Contracao comSegundos(int? s) => Contracao(
      inicio: '08:00',
      fim: '08:02',
      intensidade: 'Leve',
      observacoes: '',
      data: '2026-01-15',
      duracaoSegundos: s,
    );

    test('formata como MM:SS com zero à esquerda', () {
      expect(comSegundos(90).duracaoFormatada, '01:30');
      expect(comSegundos(0).duracaoFormatada, '00:00');
      expect(comSegundos(59).duracaoFormatada, '00:59');
    });

    test('minutos acima de 99 não são truncados', () {
      expect(comSegundos(6330).duracaoFormatada, '105:30');
    });

    test('null quando a duração é desconhecida', () {
      expect(comSegundos(null).duracaoFormatada, isNull);
    });

    test('ida e volta: derivar e reformatar preserva o valor', () {
      for (final texto in [
        'Duração: 00:07',
        'Duração: 12:34',
        'Duração: 105:30',
      ]) {
        final segundos = Contracao.duracaoSegundosDe(texto);
        final c = comSegundos(segundos);
        expect('Duração: ${c.duracaoFormatada}', texto);
      }
    });
  });

  group('Contracao.fromMap — compatibilidade com o esquema legado', () {
    test('documento v1 puro deriva a duração do texto', () {
      final c = Contracao.fromMap({
        'data': '2026-01-15',
        'inicio': '08:00',
        'fim': '08:02',
        'intensidade': 'Forte',
        'observacoes': 'Duração: 01:30 | dor lombar',
      });
      expect(c.duracaoSegundos, 90);
      expect(c.origemDuracao, OrigemDuracao.observacoes);
      expect(c.id, isNull);
    });

    test('documento v2 usa o campo tipado', () {
      final c = Contracao.fromMap({
        'data': '2026-01-15',
        'inicio': '08:00',
        'fim': '08:02',
        'intensidade': 'Forte',
        'observacoes': 'Duração: 01:30',
        'duracaoSegundos': 90,
      }, id: 'abc123');
      expect(c.duracaoSegundos, 90);
      expect(c.origemDuracao, OrigemDuracao.campo);
      expect(c.id, 'abc123');
    });

    test('duracaoSegundos vindo como num é normalizado para int', () {
      final c = Contracao.fromMap({'observacoes': '', 'duracaoSegundos': 90.0});
      expect(c.duracaoSegundos, 90);
      expect(c.origemDuracao, OrigemDuracao.campo);
    });

    test('duracaoSegundos com tipo inesperado é ignorado, sem lançar', () {
      final c = Contracao.fromMap({
        'observacoes': 'Duração: 02:00',
        'duracaoSegundos': {'valor': 90},
      });
      expect(c.duracaoSegundos, 120);
      expect(c.origemDuracao, OrigemDuracao.observacoes);
    });

    test('documento sem campos não lança e fica sem duração', () {
      final c = Contracao.fromMap(const {});
      expect(c.duracaoSegundos, isNull);
      expect(c.origemDuracao, OrigemDuracao.indisponivel);
      expect(c.inicio, '');
      expect(c.intensidade, '');
    });

    test('campo data ausente NÃO cai no fallback de hoje', () {
      final c = Contracao.fromMap(const {'observacoes': ''});
      final agora = DateTime.now();
      final hoje =
          '${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}';

      // Atribuir o dia de hoje a um documento sem data deslocaria a
      // contração para a data errada, em silêncio.
      expect(c.data, '');
      expect(c.data, isNot(hoje));
    });

    test('construir uma contração nova continua caindo no fallback de hoje', () {
      final agora = DateTime.now();
      final hoje =
          '${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}';

      final nova = Contracao(
        inicio: '08:00',
        fim: '08:02',
        intensidade: 'Forte',
        observacoes: '',
      );

      expect(nova.data, hoje);
    });
  });

  group('Contracao.comId', () {
    Contracao base({String observacoes = 'Duração: 01:30', int? segundos}) {
      return Contracao(
        inicio: '08:00',
        fim: '08:02',
        intensidade: 'Forte',
        observacoes: observacoes,
        data: '2026-01-15',
        duracaoSegundos: segundos,
      );
    }

    test('anexa o id sem alterar os demais campos', () {
      final original = base();
      final comId = original.comId('doc-abc');

      expect(comId.id, 'doc-abc');
      expect(comId.data, original.data);
      expect(comId.inicio, original.inicio);
      expect(comId.fim, original.fim);
      expect(comId.intensidade, original.intensidade);
      expect(comId.observacoes, original.observacoes);
      expect(comId.duracaoSegundos, original.duracaoSegundos);
    });

    test('preserva origemDuracao derivada — não a promove a campo', () {
      final derivada = base();
      expect(derivada.origemDuracao, OrigemDuracao.observacoes);
      expect(
        derivada.comId('doc-abc').origemDuracao,
        OrigemDuracao.observacoes,
      );
    });

    test('preserva origemDuracao de campo', () {
      final medida = base(segundos: 200);
      expect(medida.origemDuracao, OrigemDuracao.campo);
      expect(medida.comId('doc-abc').origemDuracao, OrigemDuracao.campo);
    });

    test('preserva duração indisponível', () {
      final semDuracao = base(observacoes: 'sem prefixo');
      expect(semDuracao.origemDuracao, OrigemDuracao.indisponivel);

      final comId = semDuracao.comId('doc-abc');
      expect(comId.duracaoSegundos, isNull);
      expect(comId.origemDuracao, OrigemDuracao.indisponivel);
    });

    test('substitui um id já existente', () {
      final antiga = base().comId('antigo');
      expect(antiga.comId('novo').id, 'novo');
    });
  });

  group('Contracao.toMap — esquema v2', () {
    test('grava duracaoSegundos quando conhecida', () {
      final mapa = Contracao(
        data: '2026-01-15',
        inicio: '08:00',
        fim: '08:02',
        intensidade: 'Forte',
        observacoes: 'Duração: 01:30',
        duracaoSegundos: 90,
      ).toMap();

      expect(mapa['duracaoSegundos'], 90);
      expect(mapa.keys.toSet(), {
        'data',
        'inicio',
        'fim',
        'intensidade',
        'observacoes',
        'duracaoSegundos',
      });
    });

    test('omite a chave quando a duração é desconhecida, sem gravar null', () {
      final mapa = Contracao(
        data: '2026-01-15',
        inicio: '08:00',
        fim: '08:02',
        intensidade: 'Leve',
        observacoes: 'anotação sem prefixo',
      ).toMap();

      expect(mapa.containsKey('duracaoSegundos'), isFalse);
      expect(mapa.keys.toSet(), {
        'data',
        'inicio',
        'fim',
        'intensidade',
        'observacoes',
      });
    });

    test('mantém o prefixo Duração no texto — dual-write', () {
      final mapa = Contracao(
        data: '2026-01-15',
        inicio: '08:00',
        fim: '08:02',
        intensidade: 'Forte',
        observacoes: 'Duração: 01:30 | dor lombar',
        duracaoSegundos: 90,
      ).toMap();

      expect(mapa['observacoes'], 'Duração: 01:30 | dor lombar');
      expect(mapa['duracaoSegundos'], 90);
    });

    test('nunca grava o id: a identidade é o doc.id', () {
      final mapa = Contracao(
        id: 'doc-abc',
        data: '2026-01-15',
        inicio: '08:00',
        fim: '08:02',
        intensidade: 'Forte',
        observacoes: 'Duração: 01:30',
      ).toMap();

      expect(mapa.containsKey('id'), isFalse);
    });

    test('ida e volta v2 preserva a duração e marca origem como campo', () {
      final original = Contracao(
        data: '2026-01-15',
        inicio: '08:00',
        fim: '08:02',
        intensidade: 'Moderada',
        observacoes: 'Duração: 02:10 | náusea 🤢',
        duracaoSegundos: 130,
      );
      final reconstruida = Contracao.fromMap(original.toMap());

      expect(reconstruida.data, original.data);
      expect(reconstruida.inicio, original.inicio);
      expect(reconstruida.fim, original.fim);
      expect(reconstruida.intensidade, original.intensidade);
      expect(reconstruida.observacoes, original.observacoes);
      expect(reconstruida.duracaoSegundos, 130);
      expect(reconstruida.origemDuracao, OrigemDuracao.campo);
    });

    test('registro legado carregado seria promovido a v2 ao serializar', () {
      final legado = Contracao.fromMap(const {
        'data': '2026-01-15',
        'inicio': '08:00',
        'fim': '08:02',
        'intensidade': 'Forte',
        'observacoes': 'Duração: 01:30 | dor lombar',
      });

      expect(legado.origemDuracao, OrigemDuracao.observacoes);
      expect(legado.toMap()['duracaoSegundos'], 90);
    });
  });

  group('Contracao.fromMap — tipos inesperados não lançam', () {
    test('data com tipo inesperado não lança e fica vazia', () {
      for (final invalido in <Object>[
        20260115,
        3.5,
        true,
        <String>['2026-01-15'],
        <String, String>{'d': '2026-01-15'},
      ]) {
        expect(
          () => Contracao.fromMap({'data': invalido}),
          returnsNormally,
          reason: '$invalido',
        );
        expect(
          Contracao.fromMap({'data': invalido}).data,
          '',
          reason: '$invalido',
        );
      }
    });

    test('os quatro campos de texto toleram tipo inesperado', () {
      final c = Contracao.fromMap(const {
        'inicio': 800,
        'fim': 802,
        'intensidade': 3,
        'observacoes': <String>['dor lombar'],
      });

      expect(c.inicio, '');
      expect(c.fim, '');
      expect(c.intensidade, '');
      expect(c.observacoes, '');
    });

    test('documento inteiramente malformado não lança', () {
      expect(
        () => Contracao.fromMap(const {
          'data': 1,
          'inicio': 2,
          'fim': 3,
          'intensidade': 4,
          'observacoes': 5,
          'duracaoSegundos': <String>['90'],
        }, id: 'doc-ruim'),
        returnsNormally,
      );
    });

    test('um documento malformado continua endereçável pelo doc.id', () {
      final c = Contracao.fromMap(const {'data': 1}, id: 'doc-ruim');

      expect(c.id, 'doc-ruim');
    });

    test('nulos explícitos não lançam', () {
      final c = Contracao.fromMap(const {
        'data': null,
        'inicio': null,
        'fim': null,
        'intensidade': null,
        'observacoes': null,
        'duracaoSegundos': null,
      });

      expect(c.data, '');
      expect(c.inicio, '');
      expect(c.duracaoSegundos, isNull);
      expect(c.origemDuracao, OrigemDuracao.indisponivel);
    });

    test('observações com tipo inesperado não derivam duração fantasma', () {
      final c = Contracao.fromMap(const {'observacoes': 90});

      expect(c.observacoes, '');
      expect(c.duracaoSegundos, isNull);
      expect(c.origemDuracao, OrigemDuracao.indisponivel);
    });
  });

  group('Contracao.copyWith', () {
    Contracao base({String observacoes = 'Duração: 01:30', int? segundos}) {
      return Contracao(
        id: 'c1',
        data: '2026-01-15',
        inicio: '08:00',
        fim: '08:02',
        intensidade: 'Forte',
        observacoes: observacoes,
        duracaoSegundos: segundos,
      );
    }

    test('preserva o id em qualquer alteração', () {
      expect(base().copyWith(intensidade: 'Leve').id, 'c1');
      expect(base().copyWith(data: '2026-02-01').id, 'c1');
      expect(base().copyWith(observacoes: 'outra').id, 'c1');
    });

    test('altera só o campo pedido', () {
      final original = base(segundos: 90);

      final comIntensidade = original.copyWith(intensidade: 'Leve');
      expect(comIntensidade.intensidade, 'Leve');
      expect(comIntensidade.inicio, '08:00');
      expect(comIntensidade.data, '2026-01-15');

      final comData = original.copyWith(data: '2026-02-01');
      expect(comData.data, '2026-02-01');
      expect(comData.fim, '08:02');

      final comHorarios = original.copyWith(inicio: '09:00', fim: '09:03');
      expect(comHorarios.inicio, '09:00');
      expect(comHorarios.fim, '09:03');
    });

    test('sem argumentos devolve os mesmos valores', () {
      final original = base(segundos: 90);
      final copia = original.copyWith();

      expect(copia.toMap(), original.toMap());
      expect(copia.id, original.id);
      expect(copia.origemDuracao, original.origemDuracao);
    });

    test('preserva a duração de campo como campo', () {
      final copia = base(segundos: 200).copyWith(intensidade: 'Leve');

      expect(copia.duracaoSegundos, 200);
      expect(copia.origemDuracao, OrigemDuracao.campo);
    });

    test('preserva origem derivada — não a promove a campo', () {
      final legado = base(observacoes: 'Duração: 01:30');
      expect(legado.origemDuracao, OrigemDuracao.observacoes);

      final copia = legado.copyWith(intensidade: 'Leve');

      expect(copia.duracaoSegundos, 90);
      expect(copia.origemDuracao, OrigemDuracao.observacoes);
    });

    test('preserva duração indisponível', () {
      final copia = base(observacoes: 'só uma anotação').copyWith(fim: '08:05');

      expect(copia.duracaoSegundos, isNull);
      expect(copia.origemDuracao, OrigemDuracao.indisponivel);
    });

    test('trocar a duração explicitamente vira duração de campo', () {
      final copia = base(
        observacoes: 'Duração: 01:30',
      ).copyWith(duracaoSegundos: 200);

      expect(copia.duracaoSegundos, 200);
      expect(copia.origemDuracao, OrigemDuracao.campo);
    });

    test('trocar as observações re-deriva a duração legada', () {
      final copia = base(
        observacoes: 'Duração: 01:30',
      ).copyWith(observacoes: 'Duração: 02:00');

      expect(copia.duracaoSegundos, 120);
      expect(copia.origemDuracao, OrigemDuracao.observacoes);
    });

    test('o id continua fora do mapa persistido', () {
      expect(
        base().copyWith(intensidade: 'Leve').toMap().containsKey('id'),
        isFalse,
      );
    });
  });

  group('ContracoesStorage — forma das operações', () {
    String fonteDoStorage() => File('lib/services/contracoes_storage.dart')
        .readAsLinesSync()
        .where((linha) => !linha.trimLeft().startsWith('//'))
        .join('\n');

    String corpoDoMetodo(String fonte, String assinatura) {
      final inicio = fonte.indexOf(assinatura);
      expect(inicio, greaterThan(-1), reason: assinatura);

      final fim = fonte.indexOf('\n  }\n', inicio);
      expect(fim, greaterThan(inicio), reason: assinatura);

      return fonte.substring(inicio, fim);
    }

    test('não existe escrita destrutiva', () {
      final codigo = fonteDoStorage();

      expect(codigo, isNot(contains('batch')));
      expect(codigo, isNot(contains('WriteBatch')));
      expect(codigo, isNot(contains('.commit()')));
      expect(codigo, isNot(contains('doc.reference')));
      expect(codigo, isNot(contains('salvarContracoes')));
    });

    test('nenhuma escrita enumera a coleção', () {
      for (final metodo in [
        'static Future<Contracao?> adicionar(',
        'static Future<bool> atualizar(',
        'static Future<bool> remover(',
      ]) {
        final corpo = corpoDoMetodo(fonteDoStorage(), metodo);

        expect(corpo, isNot(contains('.get()')), reason: metodo);
        expect(corpo, isNot(contains('docs')), reason: metodo);
        expect(corpo, isNot(contains('for (')), reason: metodo);
      }
    });

    test('o único delete é o de um documento nomeado', () {
      final codigo = fonteDoStorage();

      expect('delete('.allMatches(codigo), hasLength(1));
      expect(
        corpoDoMetodo(codigo, 'static Future<bool> remover('),
        contains('doc.delete()'),
      );
    });

    test('atualizar usa update, para não recriar contração apagada', () {
      final corpo = corpoDoMetodo(
        fonteDoStorage(),
        'static Future<bool> atualizar(',
      );

      expect(corpo, contains('doc.update('));
      expect(corpo, isNot(contains('.set(')));
    });

    test('adicionar reaproveita o id recebido', () {
      final corpo = corpoDoMetodo(
        fonteDoStorage(),
        'static Future<Contracao?> adicionar(',
      );

      expect(corpo, contains('idEhEnderecavel(idRecebido)'));
      expect(corpo, contains('colecao.doc(id).set('));
    });

    test('as operações validam o id antes de endereçar', () {
      final codigo = fonteDoStorage();

      expect(codigo, contains('static bool idEhEnderecavel(String id)'));
      expect(codigo, contains('_documento(contracao.id'));
      expect(codigo, contains('_documento(id)'));
    });

    test('as escritas sinalizam ausência de sessão', () {
      final codigo = fonteDoStorage();

      expect(
        corpoDoMetodo(codigo, 'static Future<Contracao?> adicionar('),
        contains('return null;'),
      );
      for (final metodo in [
        'static Future<bool> atualizar(',
        'static Future<bool> remover(',
      ]) {
        expect(corpoDoMetodo(codigo, metodo), contains('return false;'));
      }
    });

    test('o carregamento não ordena no servidor e usa o doc.id', () {
      final corpo = corpoDoMetodo(
        fonteDoStorage(),
        'static Future<List<Contracao>> carregarContracoes(',
      );

      expect(corpo, isNot(contains('orderBy')));
      expect(corpo, contains('Contracao.fromDoc(doc)'));
    });

    test('o caminho da coleção continua o mesmo', () {
      final codigo = fonteDoStorage();

      expect(codigo, contains(".collection('usuarios')"));
      expect(codigo, contains(".collection('contracoes')"));
    });

    test('o storage não engole erro — quem trata é a tela', () {
      expect(fonteDoStorage(), isNot(contains('catch')));
    });
  });
}
