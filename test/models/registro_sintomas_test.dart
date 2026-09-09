import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/models/registro_sintomas.dart';

void main() {
  group('RegistroSintomas — round-trip toMap/fromMap', () {
    test('ida e volta preserva todos os campos', () {
      final original = RegistroSintomas(
        data: '2026-09-08',
        humor: 2,
        sintomas: const ['nausea', 'azia'],
        peso: 68.4,
      );

      final devolvido = RegistroSintomas.fromMap(original.toMap());

      expect(devolvido.data, '2026-09-08');
      expect(devolvido.humor, 2);
      expect(devolvido.sintomas, ['nausea', 'azia']);
      expect(devolvido.peso, 68.4);
    });

    test('ida e volta preserva um registro só com a data', () {
      final original = RegistroSintomas(data: '2026-09-08');

      final devolvido = RegistroSintomas.fromMap(original.toMap());

      expect(devolvido.data, '2026-09-08');
      expect(devolvido.humor, isNull);
      expect(devolvido.sintomas, isEmpty);
      expect(devolvido.peso, isNull);
    });

    test('toMap mantém o formato persistido — as quatro chaves', () {
      final mapa = RegistroSintomas(data: '2026-09-08').toMap();

      expect(mapa.keys.toSet(), {'data', 'humor', 'sintomas', 'peso'});
    });
  });

  group('RegistroSintomas.fromMap — campos ausentes', () {
    test('mapa vazio produz um registro seguro, sem lançar', () {
      final registro = RegistroSintomas.fromMap(const {});

      expect(registro.data, '');
      expect(registro.humor, isNull);
      expect(registro.sintomas, isEmpty);
      expect(registro.peso, isNull);
    });

    test('a data do documento entra quando o campo falta', () {
      final registro = RegistroSintomas.fromMap(const {
        'humor': 1,
      }, dataDoDocumento: '2026-09-06');

      expect(registro.data, '2026-09-06');
      expect(registro.humor, 1);
    });

    test('o campo data vence a data do documento quando existe', () {
      final registro = RegistroSintomas.fromMap(const {
        'data': '2026-09-07',
      }, dataDoDocumento: '2026-09-06');

      expect(registro.data, '2026-09-07');
    });

    test('data vazia cai para a data do documento', () {
      final registro = RegistroSintomas.fromMap(const {
        'data': '',
      }, dataDoDocumento: '2026-09-06');

      expect(registro.data, '2026-09-06');
    });

    test('data de tipo inesperado não lança', () {
      expect(RegistroSintomas.fromMap(const {'data': 20260908}).data, '');
      expect(
        RegistroSintomas.fromMap(const {
          'data': 20260908,
        }, dataDoDocumento: '2026-09-08').data,
        '2026-09-08',
      );
    });

    test('valores nulos explícitos não lançam', () {
      final registro = RegistroSintomas.fromMap(const {
        'data': null,
        'humor': null,
        'sintomas': null,
        'peso': null,
      });

      expect(registro.data, '');
      expect(registro.humor, isNull);
      expect(registro.sintomas, isEmpty);
      expect(registro.peso, isNull);
    });
  });

  group('RegistroSintomas.fromMap — peso', () {
    test('peso inteiro vira double', () {
      final registro = RegistroSintomas.fromMap(const {'peso': 68});

      expect(registro.peso, 68.0);
      expect(registro.peso, isA<double>());
    });

    test('peso decimal é preservado', () {
      final registro = RegistroSintomas.fromMap(const {'peso': 68.45});

      expect(registro.peso, 68.45);
    });

    test('peso como texto numérico é aproveitado', () {
      expect(RegistroSintomas.fromMap(const {'peso': '68.4'}).peso, 68.4);
      expect(RegistroSintomas.fromMap(const {'peso': '68,4'}).peso, 68.4);
    });

    test('peso de tipo inválido não lança e vira nulo', () {
      for (final invalido in <Object>[
        'muito',
        '',
        true,
        <String>['68'],
        <String, int>{'kg': 68},
      ]) {
        expect(
          () => RegistroSintomas.fromMap({'peso': invalido}),
          returnsNormally,
          reason: '$invalido',
        );
        expect(
          RegistroSintomas.fromMap({'peso': invalido}).peso,
          isNull,
          reason: '$invalido',
        );
      }
    });

    test('NaN e infinito viram nulo em vez de contaminar a formatação', () {
      expect(RegistroSintomas.fromMap({'peso': double.nan}).peso, isNull);
      expect(RegistroSintomas.fromMap({'peso': double.infinity}).peso, isNull);
      expect(
        RegistroSintomas.fromMap({'peso': double.negativeInfinity}).peso,
        isNull,
      );
    });
  });

  group('RegistroSintomas.fromMap — humor', () {
    test('humor inteiro é preservado', () {
      expect(RegistroSintomas.fromMap(const {'humor': 3}).humor, 3);
    });

    test('humor vindo como num vira inteiro', () {
      expect(RegistroSintomas.fromMap(const {'humor': 3.0}).humor, 3);
    });

    test('humor de tipo inválido não lança e vira nulo', () {
      expect(RegistroSintomas.fromMap(const {'humor': 'feliz'}).humor, isNull);
      expect(RegistroSintomas.fromMap(const {'humor': true}).humor, isNull);
    });
  });

  group('RegistroSintomas.fromMap — lista de sintomas', () {
    test('lista de textos é preservada na ordem', () {
      final registro = RegistroSintomas.fromMap(const {
        'sintomas': ['nausea', 'costas', 'azia'],
      });

      expect(registro.sintomas, ['nausea', 'costas', 'azia']);
    });

    test('lista mista mantém só os textos utilizáveis', () {
      final registro = RegistroSintomas.fromMap(const {
        'sintomas': ['nausea', 7, null, '', 'azia'],
      });

      expect(registro.sintomas, ['nausea', 'azia']);
    });

    test('sintomas de tipo inválido viram lista vazia, sem lançar', () {
      for (final invalido in <Object>[
        'nausea',
        42,
        <String, String>{'0': 'nausea'},
      ]) {
        expect(
          () => RegistroSintomas.fromMap({'sintomas': invalido}),
          returnsNormally,
          reason: '$invalido',
        );
        expect(
          RegistroSintomas.fromMap({'sintomas': invalido}).sintomas,
          isEmpty,
          reason: '$invalido',
        );
      }
    });

    test('lista vazia continua vazia', () {
      expect(
        RegistroSintomas.fromMap(const {'sintomas': <String>[]}).sintomas,
        isEmpty,
      );
    });
  });

  group('RegistroSintomas.copyWith', () {
    test('troca só o humor', () {
      final original = RegistroSintomas(
        data: '2026-09-08',
        humor: 1,
        sintomas: const ['azia'],
        peso: 68.0,
      );

      final novo = original.copyWith(humor: 4);

      expect(novo.humor, 4);
      expect(novo.sintomas, ['azia']);
      expect(novo.peso, 68.0);
    });

    test('troca só os sintomas', () {
      final original = RegistroSintomas(
        data: '2026-09-08',
        humor: 1,
        sintomas: const ['azia'],
      );

      final novo = original.copyWith(sintomas: const ['nausea', 'inchaco']);

      expect(novo.sintomas, ['nausea', 'inchaco']);
      expect(novo.humor, 1);
    });

    test('troca só o peso', () {
      final original = RegistroSintomas(data: '2026-09-08', peso: 68.0);

      final novo = original.copyWith(peso: 68.9);

      expect(novo.peso, 68.9);
    });

    test('sem argumentos devolve os mesmos valores', () {
      final original = RegistroSintomas(
        data: '2026-09-08',
        humor: 2,
        sintomas: const ['cansaco'],
        peso: 70.5,
      );

      final novo = original.copyWith();

      expect(novo.data, original.data);
      expect(novo.humor, original.humor);
      expect(novo.sintomas, original.sintomas);
      expect(novo.peso, original.peso);
    });
  });

  group('RegistroSintomas — a data é a identidade', () {
    test('copyWith nunca troca a data', () {
      final original = RegistroSintomas(data: '2026-09-08', humor: 0);

      final novo = original.copyWith(humor: 4, peso: 70.0);

      expect(novo.data, '2026-09-08');
    });

    test('a data sobrevive a uma volta completa pelo mapa', () {
      final original = RegistroSintomas(data: '2026-09-08', peso: 68.4);

      final devolvido = RegistroSintomas.fromMap(
        original.copyWith(humor: 3).toMap(),
      );

      expect(devolvido.data, '2026-09-08');
    });

    test('a data é o que o storage usa como caminho do documento', () {
      final registro = RegistroSintomas(data: '2026-09-08');

      expect(registro.toMap()['data'], registro.data);
    });
  });
}
