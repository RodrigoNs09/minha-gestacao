import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/models/consulta.dart';

void main() {
  Consulta consultaValida({String id = 'c1', bool realizada = false}) =>
      Consulta(
        id: id,
        titulo: 'Pré-natal',
        profissional: 'Dra. Ana',
        data: '2026-09-08',
        hora: '14:30',
        realizada: realizada,
      );

  String fonteDoStorage() => File('lib/services/consultas_storage.dart')
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

  group('Consulta — round-trip toMap/fromMap', () {
    test('ida e volta preserva todos os campos', () {
      final devolvida = Consulta.fromMap(consultaValida().toMap());

      expect(devolvida.id, 'c1');
      expect(devolvida.titulo, 'Pré-natal');
      expect(devolvida.profissional, 'Dra. Ana');
      expect(devolvida.data, '2026-09-08');
      expect(devolvida.hora, '14:30');
      expect(devolvida.realizada, isFalse);
    });

    test('ida e volta preserva realizada = true', () {
      final devolvida = Consulta.fromMap(
        consultaValida(realizada: true).toMap(),
      );

      expect(devolvida.realizada, isTrue);
    });

    test('toMap mantém o formato persistido — as seis chaves', () {
      expect(consultaValida().toMap().keys.toSet(), {
        'id',
        'titulo',
        'profissional',
        'data',
        'hora',
        'realizada',
      });
    });
  });

  group('Consulta — identidade', () {
    test('o id do campo é preservado', () {
      final devolvida = Consulta.fromMap(consultaValida(id: 'abc123').toMap());

      expect(devolvida.id, 'abc123');
    });

    test('o id do documento entra quando o campo falta', () {
      final devolvida = Consulta.fromMap(const {
        'titulo': 'Ultrassom',
      }, idDoDocumento: '1757300000000');

      expect(devolvida.id, '1757300000000');
      expect(devolvida.titulo, 'Ultrassom');
    });

    test('o campo vence o id do documento quando existe', () {
      final devolvida = Consulta.fromMap(const {
        'id': 'do-campo',
      }, idDoDocumento: 'do-documento');

      expect(devolvida.id, 'do-campo');
    });

    test('id vazio ou só espaços cai para o id do documento', () {
      for (final vazio in ['', '   ']) {
        expect(
          Consulta.fromMap({'id': vazio}, idDoDocumento: 'doc-1').id,
          'doc-1',
          reason: '"$vazio"',
        );
      }
    });

    test('id de tipo inesperado cai para o id do documento', () {
      final devolvida = Consulta.fromMap(const {
        'id': 12345,
      }, idDoDocumento: 'doc-1');

      expect(devolvida.id, 'doc-1');
    });

    test('um documento carregado nunca fica com id vazio', () {
      final devolvida = Consulta.fromMap(const {}, idDoDocumento: 'doc-1');

      expect(devolvida.id, isNotEmpty);
    });

    test('comId carimba o id e preserva o resto', () {
      final carimbada = consultaValida(id: '').comId('novo-id');

      expect(carimbada.id, 'novo-id');
      expect(carimbada.titulo, 'Pré-natal');
      expect(carimbada.data, '2026-09-08');
      expect(carimbada.hora, '14:30');
    });
  });

  group('Consulta.fromMap — campos ausentes', () {
    test('mapa vazio produz uma consulta segura, sem lançar', () {
      final devolvida = Consulta.fromMap(const {});

      expect(devolvida.id, '');
      expect(devolvida.titulo, '');
      expect(devolvida.profissional, '');
      expect(devolvida.data, '');
      expect(devolvida.hora, '');
      expect(devolvida.realizada, isFalse);
    });

    test('nulos explícitos não lançam', () {
      final devolvida = Consulta.fromMap(const {
        'id': null,
        'titulo': null,
        'profissional': null,
        'data': null,
        'hora': null,
        'realizada': null,
      });

      expect(devolvida.titulo, '');
      expect(devolvida.realizada, isFalse);
    });
  });

  group('Consulta.fromMap — tipos inesperados', () {
    test('textos vindos como número não lançam', () {
      expect(
        () => Consulta.fromMap(const {
          'titulo': 42,
          'profissional': 3.5,
          'data': 20260908,
          'hora': 1430,
        }),
        returnsNormally,
      );

      final devolvida = Consulta.fromMap(const {'titulo': 42});
      expect(devolvida.titulo, '');
    });

    test('textos vindos como lista ou mapa não lançam', () {
      for (final invalido in <Object>[
        <String>['Pré-natal'],
        <String, String>{'nome': 'Pré-natal'},
        true,
      ]) {
        expect(
          () => Consulta.fromMap({'titulo': invalido}),
          returnsNormally,
          reason: '$invalido',
        );
        expect(Consulta.fromMap({'titulo': invalido}).titulo, '');
      }
    });

    test('realizada como texto é interpretada', () {
      expect(Consulta.fromMap(const {'realizada': 'true'}).realizada, isTrue);
      expect(Consulta.fromMap(const {'realizada': 'TRUE'}).realizada, isTrue);
      expect(Consulta.fromMap(const {'realizada': 'false'}).realizada, isFalse);
      expect(Consulta.fromMap(const {'realizada': 'sim'}).realizada, isFalse);
    });

    test('realizada como número é interpretada', () {
      expect(Consulta.fromMap(const {'realizada': 1}).realizada, isTrue);
      expect(Consulta.fromMap(const {'realizada': 0}).realizada, isFalse);
    });

    test('realizada de tipo absurdo não lança e vira falso', () {
      for (final invalido in <Object>[
        <String>['sim'],
        <String, int>{'v': 1},
      ]) {
        expect(
          () => Consulta.fromMap({'realizada': invalido}),
          returnsNormally,
          reason: '$invalido',
        );
        expect(Consulta.fromMap({'realizada': invalido}).realizada, isFalse);
      }
    });
  });

  group('Consulta.dataHora — válida', () {
    test('data e hora bem formadas viram DateTime', () {
      expect(consultaValida().dataHora, DateTime(2026, 9, 8, 14, 30));
    });

    test('aceita componentes sem zero à esquerda', () {
      final c = Consulta(
        id: 'c1',
        titulo: '',
        profissional: '',
        data: '2026-9-8',
        hora: '9:05',
      );

      expect(c.dataHora, DateTime(2026, 9, 8, 9, 5));
    });

    test('aceita os extremos do dia', () {
      Consulta comHora(String hora) => Consulta(
        id: 'c1',
        titulo: '',
        profissional: '',
        data: '2026-09-08',
        hora: hora,
      );

      expect(comHora('00:00').dataHora, DateTime(2026, 9, 8, 0, 0));
      expect(comHora('23:59').dataHora, DateTime(2026, 9, 8, 23, 59));
    });

    test('aceita 29 de fevereiro em ano bissexto', () {
      final c = Consulta(
        id: 'c1',
        titulo: '',
        profissional: '',
        data: '2028-02-29',
        hora: '10:00',
      );

      expect(c.dataHora, DateTime(2028, 2, 29, 10, 0));
    });
  });

  group('Consulta.dataHora — inválida devolve null sem lançar', () {
    Consulta com(String data, String hora) => Consulta(
      id: 'c1',
      titulo: 'Consulta',
      profissional: '',
      data: data,
      hora: hora,
    );

    test('data vazia', () {
      expect(() => com('', '14:30').dataHora, returnsNormally);
      expect(com('', '14:30').dataHora, isNull);
    });

    test('hora vazia', () {
      expect(() => com('2026-09-08', '').dataHora, returnsNormally);
      expect(com('2026-09-08', '').dataHora, isNull);
    });

    test('data sem estrutura yyyy-MM-dd', () {
      for (final data in ['abc', '2026', '2026-09', '2026-09-08-01']) {
        expect(
          () => com(data, '14:30').dataHora,
          returnsNormally,
          reason: data,
        );
        expect(com(data, '14:30').dataHora, isNull, reason: data);
      }
    });

    test('hora sem estrutura HH:mm', () {
      for (final hora in ['10', 'xx:30', '14:30:00', '']) {
        expect(
          () => com('2026-09-08', hora).dataHora,
          returnsNormally,
          reason: hora,
        );
        expect(com('2026-09-08', hora).dataHora, isNull, reason: hora);
      }
    });

    test('componentes não numéricos', () {
      expect(com('2026-ab-08', '14:30').dataHora, isNull);
      expect(com('2026-09-08', 'xx:30').dataHora, isNull);
      expect(com('2026-09-08', '14:mm').dataHora, isNull);
    });

    test('mês e dia impossíveis são rejeitados, não rolados', () {
      // DateTime(2026, 13, 45) viraria 2027-02-14 em silêncio.
      expect(com('2026-13-45', '14:30').dataHora, isNull);
      expect(com('2026-02-30', '14:30').dataHora, isNull);
      expect(com('2027-02-29', '14:30').dataHora, isNull);
      expect(com('2026-00-10', '14:30').dataHora, isNull);
      expect(com('2026-09-00', '14:30').dataHora, isNull);
    });

    test('hora e minuto fora de faixa são rejeitados', () {
      expect(com('2026-09-08', '24:00').dataHora, isNull);
      expect(com('2026-09-08', '14:60').dataHora, isNull);
      expect(com('2026-09-08', '-1:30').dataHora, isNull);
    });

    test('nenhuma combinação inválida lança', () {
      for (final data in ['', 'abc', '2026-13-45', '2026/09/08']) {
        for (final hora in ['', '10', 'xx:30', '99:99']) {
          expect(
            () => com(data, hora).dataHora,
            returnsNormally,
            reason: '"$data" "$hora"',
          );
        }
      }
    });
  });

  group('Consulta.diasRestantes — seguro', () {
    test('é nulo quando a data é inválida, sem lançar', () {
      final c = Consulta(
        id: 'c1',
        titulo: '',
        profissional: '',
        data: '',
        hora: 'xx',
      );

      expect(() => c.diasRestantes, returnsNormally);
      expect(c.diasRestantes, isNull);
    });

    test('conta zero para hoje', () {
      final agora = DateTime.now();
      final c = Consulta(
        id: 'c1',
        titulo: '',
        profissional: '',
        data:
            '${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}',
        hora: '10:00',
      );

      expect(c.diasRestantes, 0);
    });

    test('conta negativo para data passada', () {
      final ontem = DateTime.now().subtract(const Duration(days: 1));
      final c = Consulta(
        id: 'c1',
        titulo: '',
        profissional: '',
        data:
            '${ontem.year}-${ontem.month.toString().padLeft(2, '0')}-${ontem.day.toString().padLeft(2, '0')}',
        hora: '10:00',
      );

      expect(c.diasRestantes, lessThan(0));
    });
  });

  group('Consulta.copyWith', () {
    test('preserva o id em qualquer alteração', () {
      final original = consultaValida(id: 'fixo');

      expect(original.copyWith(titulo: 'Outro').id, 'fixo');
      expect(original.copyWith(realizada: true).id, 'fixo');
      expect(original.copyWith(data: '2026-10-01').id, 'fixo');
    });

    test('altera só o campo pedido', () {
      final original = consultaValida();

      final comTitulo = original.copyWith(titulo: 'Ultrassom');
      expect(comTitulo.titulo, 'Ultrassom');
      expect(comTitulo.profissional, 'Dra. Ana');
      expect(comTitulo.data, '2026-09-08');

      final comProfissional = original.copyWith(profissional: 'Dr. Bruno');
      expect(comProfissional.profissional, 'Dr. Bruno');
      expect(comProfissional.titulo, 'Pré-natal');

      final comData = original.copyWith(data: '2026-10-01');
      expect(comData.data, '2026-10-01');
      expect(comData.hora, '14:30');

      final comHora = original.copyWith(hora: '08:15');
      expect(comHora.hora, '08:15');
      expect(comHora.data, '2026-09-08');

      final marcada = original.copyWith(realizada: true);
      expect(marcada.realizada, isTrue);
      expect(marcada.titulo, 'Pré-natal');
    });

    test('sem argumentos devolve os mesmos valores', () {
      final original = consultaValida(realizada: true);
      final copia = original.copyWith();

      expect(copia.toMap(), original.toMap());
    });

    test('alterar data recalcula dataHora', () {
      final original = consultaValida();

      expect(
        original.copyWith(data: '2026-10-01').dataHora,
        DateTime(2026, 10, 1, 14, 30),
      );
      expect(original.copyWith(data: 'quebrada').dataHora, isNull);
    });
  });

  group('ConsultasStorage — o padrão destrutivo não pode voltar', () {
    test('salvarConsultas(List...) não existe mais', () {
      expect(fonteDoStorage(), isNot(contains('salvarConsultas')));
    });

    test('o storage não usa batch', () {
      final codigo = fonteDoStorage();

      expect(codigo, isNot(contains('batch')));
      expect(codigo, isNot(contains('WriteBatch')));
      expect(codigo, isNot(contains('.commit()')));
    });

    test('nenhuma escrita enumera a coleção antes de gravar', () {
      for (final metodo in [
        'static Future<Consulta?> adicionar(',
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
  });

  group('ConsultasStorage — operação individual por documento', () {
    test('as operações endereçam o documento pelo id', () {
      final codigo = fonteDoStorage();

      expect(codigo, contains('_documento(consulta.id)'));
      expect(codigo, contains('_documento(id)'));
      expect(codigo, contains('return _colecao?.doc(id);'));
      expect(
        corpoDoMetodo(codigo, 'static Future<Consulta?> adicionar('),
        contains('colecao.doc(id).set('),
      );
    });

    test('atualizar usa update, para não recriar consulta apagada', () {
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
        'static Future<Consulta?> adicionar(',
      );

      expect(corpo, contains('idEhEnderecavel(consulta.id)'));
      expect(corpo, contains('colecao.doc().id'));
    });

    test('novoId existe e vem da própria coleção', () {
      expect(
        fonteDoStorage(),
        contains('static String? novoId() => _colecao?.doc().id;'),
      );
    });

    test('o caminho da coleção continua o mesmo', () {
      final codigo = fonteDoStorage();

      expect(codigo, contains(".collection('usuarios')"));
      expect(codigo, contains(".collection('consultas')"));
    });

    test('o load usa o id do documento como reserva', () {
      final corpo = corpoDoMetodo(
        fonteDoStorage(),
        'static Future<List<Consulta>> carregarConsultas(',
      );

      expect(corpo, contains('idDoDocumento: doc.id'));
    });

    test('o storage não engole erro — quem trata é a tela', () {
      expect(fonteDoStorage(), isNot(contains('catch')));
    });
  });
}
