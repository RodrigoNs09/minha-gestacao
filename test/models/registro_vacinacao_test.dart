import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/models/registro_vacinacao.dart';

void main() {
  RegistroVacinacao registroCompleto() {
    return RegistroVacinacao(
      vacinaCodigo: 'dtpa',
      situacaoInformada: SituacaoInformada.aplicadaComData,
      versaoCalendario: 'PNI-2026',
      dataAplicacao: DateTime(2026, 9, 2),
      dumNoRegistro: DateTime(2026, 3, 10),
      criadoEm: DateTime(2026, 9, 2, 14, 30),
      observacao: 'aplicada na UBS',
    );
  }

  group('RegistroVacinacao.toMap', () {
    test('grava todos os campos conhecidos', () {
      final mapa = registroCompleto().toMap();

      expect(mapa['vacinaCodigo'], 'dtpa');
      expect(mapa['situacaoInformada'], 'APLICADA_COM_DATA');
      expect(mapa['origemRegistro'], 'REGISTRADO_PELA_USUARIA');
      expect(mapa['versaoCalendario'], 'PNI-2026');
      expect(mapa['observacao'], 'aplicada na UBS');
    });

    test('data de aplicação é gravada como yyyy-MM-dd', () {
      final mapa = registroCompleto().toMap();
      expect(mapa['dataAplicacao'], '2026-09-02');
    });

    test('dum e criadoEm são gravados como ISO8601', () {
      final mapa = registroCompleto().toMap();

      expect(mapa['dumNoRegistro'], DateTime(2026, 3, 10).toIso8601String());
      expect(mapa['criadoEm'], DateTime(2026, 9, 2, 14, 30).toIso8601String());
    });

    test('nunca grava o id: a identidade é o doc.id', () {
      final mapa = registroCompleto().comId('abc123').toMap();

      expect(mapa.containsKey('id'), isFalse);
      expect(mapa.values, isNot(contains('abc123')));
    });

    test('omite as chaves desconhecidas em vez de gravar null', () {
      final mapa = const RegistroVacinacao(
        vacinaCodigo: 'influenza',
        situacaoInformada: SituacaoInformada.naoAplicadaInformado,
        versaoCalendario: 'PNI-2026',
      ).toMap();

      expect(mapa.containsKey('dataAplicacao'), isFalse);
      expect(mapa.containsKey('dumNoRegistro'), isFalse);
      expect(mapa.containsKey('criadoEm'), isFalse);
      expect(mapa.containsKey('observacao'), isFalse);
      expect(mapa.values, isNot(contains(null)));
    });

    test('origem é sempre gravada, mesmo sem ter sido informada na criação', () {
      final mapa = const RegistroVacinacao(
        vacinaCodigo: 'covid19',
        situacaoInformada: SituacaoInformada.aplicadaDataDesconhecida,
        versaoCalendario: 'PNI-2026',
      ).toMap();

      expect(mapa['origemRegistro'], 'REGISTRADO_PELA_USUARIA');
    });
  });

  group('RegistroVacinacao.fromMap', () {
    test('reconstrói os campos a partir do documento', () {
      final registro = RegistroVacinacao.fromMap(const {
        'vacinaCodigo': 'vsr',
        'situacaoInformada': 'APLICADA_COM_DATA',
        'origemRegistro': 'REGISTRADO_PELA_USUARIA',
        'versaoCalendario': 'PNI-2026',
        'dataAplicacao': '2026-09-02',
        'observacao': 'segunda dose',
      });

      expect(registro.vacinaCodigo, 'vsr');
      expect(registro.situacaoInformada, SituacaoInformada.aplicadaComData);
      expect(registro.origemRegistro, OrigemRegistro.registradoPelaUsuaria);
      expect(registro.versaoCalendario, 'PNI-2026');
      expect(registro.dataAplicacao, DateTime(2026, 9, 2));
      expect(registro.observacao, 'segunda dose');
    });

    test('adota o id do documento, que não vem do payload', () {
      final registro = RegistroVacinacao.fromMap(
        const {'vacinaCodigo': 'dtpa'},
        id: 'doc-42',
      );

      expect(registro.id, 'doc-42');
    });

    test('sem id informado, o registro fica sem identidade', () {
      final registro = RegistroVacinacao.fromMap(const {'vacinaCodigo': 'dtpa'});
      expect(registro.id, isNull);
    });

    test('lê dum e criadoEm em ISO8601', () {
      final registro = RegistroVacinacao.fromMap({
        'vacinaCodigo': 'dtpa',
        'dumNoRegistro': DateTime(2026, 3, 10).toIso8601String(),
        'criadoEm': DateTime(2026, 9, 2, 14, 30).toIso8601String(),
      });

      expect(registro.dumNoRegistro, DateTime(2026, 3, 10));
      expect(registro.criadoEm, DateTime(2026, 9, 2, 14, 30));
    });
  });

  group('RegistroVacinacao — defaults seguros', () {
    test('documento vazio não lança e não inventa dados', () {
      final registro = RegistroVacinacao.fromMap(const {});

      expect(registro.vacinaCodigo, '');
      expect(registro.versaoCalendario, '');
      expect(registro.dataAplicacao, isNull);
      expect(registro.dumNoRegistro, isNull);
      expect(registro.criadoEm, isNull);
      expect(registro.observacao, isNull);
    });

    test('sem situação informada, a situação é desconhecida', () {
      final registro = RegistroVacinacao.fromMap(const {'vacinaCodigo': 'dtpa'});

      expect(registro.situacaoInformada, SituacaoInformada.situacaoDesconhecida);
    });

    test('campo ausente NÃO é interpretado como dose aplicada', () {
      final semCampo = RegistroVacinacao.fromMap(const {'vacinaCodigo': 'dtpa'});
      final documentoVazio = RegistroVacinacao.fromMap(const {});

      for (final registro in [semCampo, documentoVazio]) {
        expect(registro.situacaoInformada, isNot(SituacaoInformada.aplicadaComData));
        expect(registro.situacaoInformada, isNot(SituacaoInformada.aplicadaDataDesconhecida));
        // Também não é lido como recusa: a usuária não disse nada.
        expect(registro.situacaoInformada, isNot(SituacaoInformada.naoAplicadaInformado));
        expect(registro.situacaoInformada, SituacaoInformada.situacaoDesconhecida);
      }
    });

    test('código desconhecido cai em situação desconhecida, não em dose aplicada', () {
      final registro = RegistroVacinacao.fromMap(const {
        'vacinaCodigo': 'dtpa',
        'situacaoInformada': 'APLICADA_EM_OUTRO_ESQUEMA_FUTURO',
      });

      expect(registro.situacaoInformada, SituacaoInformada.situacaoDesconhecida);
    });

    test('tipo inesperado em situacaoInformada não vira dose aplicada', () {
      final registro = RegistroVacinacao.fromMap(const {
        'vacinaCodigo': 'dtpa',
        'situacaoInformada': 1,
      });

      expect(registro.situacaoInformada, SituacaoInformada.situacaoDesconhecida);
    });

    test('campos com tipo inesperado são ignorados, sem lançar', () {
      final registro = RegistroVacinacao.fromMap(const {
        'vacinaCodigo': 42,
        'versaoCalendario': true,
        'observacao': 99,
        'dataAplicacao': 20260902,
      });

      expect(registro.vacinaCodigo, '');
      expect(registro.versaoCalendario, '');
      expect(registro.observacao, isNull);
      expect(registro.dataAplicacao, isNull);
    });

    test('data malformada vira desconhecida em vez de derrubar a leitura', () {
      final registro = RegistroVacinacao.fromMap(const {
        'vacinaCodigo': 'dtpa',
        'dataAplicacao': 'ontem',
        'dumNoRegistro': '',
        'criadoEm': '2026-13-45',
      });

      expect(registro.dataAplicacao, isNull);
      expect(registro.dumNoRegistro, isNull);
      expect(registro.criadoEm, isNull);
    });

    test('data fora de faixa é rejeitada, não normalizada para outro dia', () {
      // DateTime.tryParse('2026-13-45') devolve 2027-02-14 em silêncio.
      // Uma data corrompida que vira outra data plausível levaria a engine
      // a calcular intervalos sobre um valor inventado.
      expect(DateTime.tryParse('2026-13-45'), isNotNull);

      final registro = RegistroVacinacao.fromMap(const {
        'vacinaCodigo': 'dtpa',
        'dataAplicacao': '2026-13-45',
      });

      expect(registro.dataAplicacao, isNull);
    });

    test('dia inexistente no mês é rejeitado', () {
      final registro = RegistroVacinacao.fromMap(const {
        'vacinaCodigo': 'dtpa',
        'dataAplicacao': '2026-02-30',
      });

      expect(registro.dataAplicacao, isNull);
    });

    test('data parcial, sem dia, é tratada como desconhecida', () {
      final registro = RegistroVacinacao.fromMap(const {
        'vacinaCodigo': 'dtpa',
        'dataAplicacao': '2026-09',
      });

      expect(registro.dataAplicacao, isNull);
    });
  });

  group('RegistroVacinacao — data de aplicação', () {
    test('com valor, sobrevive à ida e volta', () {
      final original = registroCompleto();
      final lido = RegistroVacinacao.fromMap(original.toMap());

      expect(lido.dataAplicacao, DateTime(2026, 9, 2));
    });

    test('nula continua nula, sem virar a data de hoje', () {
      final original = const RegistroVacinacao(
        vacinaCodigo: 'hepatite_b',
        situacaoInformada: SituacaoInformada.aplicadaDataDesconhecida,
        versaoCalendario: 'PNI-2026',
      );

      final lido = RegistroVacinacao.fromMap(original.toMap());

      expect(lido.dataAplicacao, isNull);
    });
  });

  group('SituacaoInformada', () {
    test('os quatro casos sobrevivem à ida e volta', () {
      for (final situacao in SituacaoInformada.values) {
        final lido = RegistroVacinacao.fromMap(
          RegistroVacinacao(
            vacinaCodigo: 'dt',
            situacaoInformada: situacao,
            versaoCalendario: 'PNI-2026',
          ).toMap(),
        );

        expect(lido.situacaoInformada, situacao);
      }
    });

    test('os códigos persistidos são estáveis e distintos entre si', () {
      expect(SituacaoInformada.aplicadaComData.codigo, 'APLICADA_COM_DATA');
      expect(SituacaoInformada.aplicadaDataDesconhecida.codigo, 'APLICADA_DATA_DESCONHECIDA');
      expect(SituacaoInformada.naoAplicadaInformado.codigo, 'NAO_APLICADA_INFORMADO');
      expect(SituacaoInformada.situacaoDesconhecida.codigo, 'SITUACAO_DESCONHECIDA');

      final codigos = SituacaoInformada.values.map((s) => s.codigo).toSet();
      expect(codigos.length, SituacaoInformada.values.length);
    });

    test('os quatro estados são semanticamente distintos', () {
      expect(SituacaoInformada.values, hasLength(4));
      expect(
        SituacaoInformada.values.toSet(),
        {
          SituacaoInformada.aplicadaComData,
          SituacaoInformada.aplicadaDataDesconhecida,
          SituacaoInformada.naoAplicadaInformado,
          SituacaoInformada.situacaoDesconhecida,
        },
      );
    });

    test('situação desconhecida é distinta de não aplicada', () {
      // "Não sei" nunca deve ser confundido com "ela disse que não tomou":
      // um é ausência de informação, o outro é uma declaração.
      expect(
        SituacaoInformada.situacaoDesconhecida,
        isNot(SituacaoInformada.naoAplicadaInformado),
      );
      expect(
        SituacaoInformada.situacaoDesconhecida.codigo,
        isNot(SituacaoInformada.naoAplicadaInformado.codigo),
      );
    });

    test('código desconhecido não é adivinhado', () {
      expect(SituacaoInformada.porCodigo('QUALQUER_OUTRO'), isNull);
      expect(SituacaoInformada.porCodigo(null), isNull);
      expect(SituacaoInformada.porCodigo(7), isNull);
    });
  });

  group('OrigemRegistro — nunca representa dado validado', () {
    test('o único valor possível é declaração da usuária', () {
      expect(OrigemRegistro.values, [OrigemRegistro.registradoPelaUsuaria]);
      expect(OrigemRegistro.registradoPelaUsuaria.codigo, 'REGISTRADO_PELA_USUARIA');
    });

    test('é o padrão quando não informado na criação', () {
      const registro = RegistroVacinacao(
        vacinaCodigo: 'dtpa',
        situacaoInformada: SituacaoInformada.aplicadaComData,
        versaoCalendario: 'PNI-2026',
      );

      expect(registro.origemRegistro, OrigemRegistro.registradoPelaUsuaria);
    });

    test('origem ausente ou desconhecida é lida como declaração da usuária', () {
      final semOrigem = RegistroVacinacao.fromMap(const {'vacinaCodigo': 'dtpa'});
      final origemEstranha = RegistroVacinacao.fromMap(const {
        'vacinaCodigo': 'dtpa',
        'origemRegistro': 'VALIDADO_POR_SERVICO_DE_SAUDE',
      });

      expect(semOrigem.origemRegistro, OrigemRegistro.registradoPelaUsuaria);
      expect(origemEstranha.origemRegistro, OrigemRegistro.registradoPelaUsuaria);
    });
  });

  group('versaoCalendario', () {
    test('é preservada na ida e volta', () {
      final lido = RegistroVacinacao.fromMap(
        const RegistroVacinacao(
          vacinaCodigo: 'dtpa',
          situacaoInformada: SituacaoInformada.aplicadaComData,
          versaoCalendario: 'PNI-2026',
        ).toMap(),
      );

      expect(lido.versaoCalendario, 'PNI-2026');
    });

    test('ausente fica vazia, sem assumir a versão vigente', () {
      final registro = RegistroVacinacao.fromMap(const {'vacinaCodigo': 'dtpa'});

      expect(registro.versaoCalendario, '');
      expect(registro.versaoCalendario, isNot('PNI-2026'));
    });
  });

  group('observacao', () {
    test('opcional: ausente permanece nula na ida e volta', () {
      final lido = RegistroVacinacao.fromMap(
        const RegistroVacinacao(
          vacinaCodigo: 'dtpa',
          situacaoInformada: SituacaoInformada.aplicadaComData,
          versaoCalendario: 'PNI-2026',
        ).toMap(),
      );

      expect(lido.observacao, isNull);
    });

    test('vazia é distinta de ausente', () {
      final mapa = const RegistroVacinacao(
        vacinaCodigo: 'dtpa',
        situacaoInformada: SituacaoInformada.aplicadaComData,
        versaoCalendario: 'PNI-2026',
        observacao: '',
      ).toMap();

      expect(mapa['observacao'], '');
      expect(RegistroVacinacao.fromMap(mapa).observacao, '');
    });
  });

  group('RegistroVacinacao.comId', () {
    test('anexa o id sem alterar os demais campos', () {
      final original = registroCompleto();
      final comId = original.comId('doc-7');

      expect(comId.id, 'doc-7');
      expect(comId.vacinaCodigo, original.vacinaCodigo);
      expect(comId.situacaoInformada, original.situacaoInformada);
      expect(comId.origemRegistro, original.origemRegistro);
      expect(comId.versaoCalendario, original.versaoCalendario);
      expect(comId.dataAplicacao, original.dataAplicacao);
      expect(comId.dumNoRegistro, original.dumNoRegistro);
      expect(comId.criadoEm, original.criadoEm);
      expect(comId.observacao, original.observacao);
    });

    test('substitui um id já existente', () {
      final registro = registroCompleto().comId('antigo').comId('novo');
      expect(registro.id, 'novo');
    });
  });

  group('RegistroVacinacao — ida e volta completa', () {
    test('preserva todos os campos de um registro completo', () {
      final original = registroCompleto().comId('doc-1');
      final lido = RegistroVacinacao.fromMap(original.toMap(), id: original.id);

      expect(lido.id, original.id);
      expect(lido.vacinaCodigo, original.vacinaCodigo);
      expect(lido.situacaoInformada, original.situacaoInformada);
      expect(lido.origemRegistro, original.origemRegistro);
      expect(lido.versaoCalendario, original.versaoCalendario);
      expect(lido.dataAplicacao, original.dataAplicacao);
      expect(lido.dumNoRegistro, original.dumNoRegistro);
      expect(lido.criadoEm, original.criadoEm);
      expect(lido.observacao, original.observacao);
    });

    test('preserva um registro mínimo, sem inventar campos', () {
      const original = RegistroVacinacao(
        vacinaCodigo: 'febre_amarela',
        situacaoInformada: SituacaoInformada.naoAplicadaInformado,
        versaoCalendario: 'PNI-2026',
      );

      final lido = RegistroVacinacao.fromMap(original.toMap());

      expect(lido.vacinaCodigo, 'febre_amarela');
      expect(lido.situacaoInformada, SituacaoInformada.naoAplicadaInformado);
      expect(lido.versaoCalendario, 'PNI-2026');
      expect(lido.dataAplicacao, isNull);
      expect(lido.dumNoRegistro, isNull);
      expect(lido.criadoEm, isNull);
      expect(lido.observacao, isNull);
    });
  });
}
