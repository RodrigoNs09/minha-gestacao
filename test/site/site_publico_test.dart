import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const paginas = ['index.html', 'privacidade.html', 'exclusao-conta.html'];

  String pagina(String nome) => File('public/$nome').readAsStringSync();

  String textoVisivel(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ');

  group('Site público — Firebase Hosting', () {
    test('o Hosting publica public/ e não o build do Flutter Web', () {
      final config =
          jsonDecode(File('firebase.json').readAsStringSync())
              as Map<String, dynamic>;
      final hosting = config['hosting'] as Map<String, dynamic>;

      expect(hosting['public'], 'public');
      expect(hosting.containsKey('rewrites'), isFalse);
    });

    test('nenhum artefato do Flutter Web está em public/', () {
      for (final artefato in [
        'main.dart.js',
        'flutter.js',
        'flutter_bootstrap.js',
        'flutter_service_worker.js',
        'version.json',
        'manifest.json',
      ]) {
        expect(
          File('public/$artefato').existsSync(),
          isFalse,
          reason: artefato,
        );
      }
    });

    test('a pasta web/ do Flutter continua existindo', () {
      expect(File('web/index.html').existsSync(), isTrue);
    });
  });

  group('Site público — estrutura', () {
    test('as três páginas e a folha de estilo existem', () {
      for (final nome in [...paginas, 'estilo.css']) {
        expect(File('public/$nome').existsSync(), isTrue, reason: nome);
      }
    });

    test('todas as páginas são pt-BR, UTF-8 e responsivas', () {
      for (final nome in paginas) {
        final html = pagina(nome);

        expect(html, contains('<html lang="pt-BR">'), reason: nome);
        expect(html, contains('<meta charset="utf-8">'), reason: nome);
        expect(html, contains('name="viewport"'), reason: nome);
      }
    });

    test('a página inicial leva à política e à exclusão', () {
      final html = pagina('index.html');

      expect(html, contains('href="privacidade.html"'));
      expect(html, contains('href="exclusao-conta.html"'));
    });

    test('a página inicial identifica o app e o desenvolvedor', () {
      final texto = textoVisivel(pagina('index.html'));

      expect(texto, contains('Minha Gestação'));
      expect(texto, contains('Rodrigo Nascimento da Silva'));
    });

    test('todo link relativo aponta para um arquivo que existe', () {
      final href = RegExp(r'href="([^"]+)"');

      for (final nome in paginas) {
        for (final m in href.allMatches(pagina(nome))) {
          final alvo = m.group(1)!;
          if (alvo.startsWith('http') ||
              alvo.startsWith('mailto:') ||
              alvo.startsWith('data:') ||
              alvo.startsWith('#')) {
            continue;
          }
          final arquivo = alvo.split('#').first;
          expect(
            File('public/$arquivo').existsSync(),
            isTrue,
            reason: '$nome -> $alvo',
          );
        }
      }
    });
  });

  group('Política de Privacidade — conteúdo', () {
    late String texto;

    setUp(() => texto = textoVisivel(pagina('privacidade.html')));

    test('cita os dois serviços Firebase realmente usados', () {
      expect(texto, contains('Firebase Authentication'));
      expect(texto, contains('Cloud Firestore'));
    });

    test('não cita serviços que o app não usa', () {
      for (final servico in [
        'Google Analytics',
        'Firebase Analytics',
        'Crashlytics',
        'Cloud Messaging',
        'FCM',
        'Remote Config',
        'Cloud Storage',
        'AdMob',
      ]) {
        expect(texto, isNot(contains(servico)), reason: servico);
      }
    });

    test('cobre todas as categorias de dados do app', () {
      for (final dado in [
        'E-mail',
        'Senha',
        'Identificador da conta',
        'última menstruação',
        'Contrações',
        'Movimentos do bebê',
        'Humor',
        'Sintomas',
        'Peso',
        'Consultas',
        'nome do profissional',
        'Vacinação',
        'texto livre',
        'endereço IP',
      ]) {
        expect(texto, contains(dado), reason: dado);
      }
    });

    test('cobre finalidade, compartilhamento, retenção, direitos e contato', () {
      for (final secao in [
        'Para que os dados são usados',
        'Com quem os dados são compartilhados',
        'Por quanto tempo os dados são mantidos',
        'Como excluir sua conta',
        'Seus direitos',
        'Contato',
        'Alterações desta política',
      ]) {
        expect(texto, contains(secao), reason: secao);
      }
    });

    test('identifica o responsável e o canal de contato', () {
      expect(texto, contains('Rodrigo Nascimento da Silva'));
      expect(texto, contains('suporte.minhagestacaoapp@gmail.com'));
    });

    test('traz a data da última atualização', () {
      expect(texto, matches(RegExp(r'Última atualização: \d{1,2} de \w+ de \d{4}')));
    });

    test('declara as três bases legais decididas', () {
      expect(texto, contains('Bases legais'));
      expect(
        texto,
        contains(
          'o seu consentimento específico e destacado (LGPD, art. 11, I)',
        ),
      );
      expect(texto, contains('antes de qualquer registro'));
      expect(
        texto,
        contains(
          'a execução do serviço que você solicita ao criar a conta '
          '(LGPD, art. 7º, V)',
        ),
      );
      expect(
        texto,
        contains(
          'o legítimo interesse em proteger a sua conta (LGPD, art. 7º, IX)',
        ),
      );
    });

    test('não declara base legal que o app não usa', () {
      for (final base in [
        'obrigação legal',
        'tutela da saúde',
        'proteção da vida',
        'proteção do crédito',
        'órgão de pesquisa',
      ]) {
        expect(texto, isNot(contains(base)), reason: base);
      }
    });

    test('o legítimo interesse não cobre dados de saúde', () {
      final itens = RegExp(
        r'<li>(.*?)</li>',
        dotAll: true,
      ).allMatches(pagina('privacidade.html')).map((m) => m.group(1)!);
      final doLegitimoInteresse = itens
          .where((item) => item.contains('legítimo interesse'))
          .toList();

      expect(doLegitimoInteresse, hasLength(1));
      expect(doLegitimoInteresse.single, isNot(contains('saúde')));
    });

    test('a revogação do consentimento é feita pela exclusão da conta', () {
      expect(
        texto,
        contains(
          'A autorização para o tratamento dos dados de saúde pode ser '
          'revogada a qualquer momento.',
        ),
      );
      expect(
        texto,
        contains(
          'a revogação é feita pela exclusão da conta, pelo caminho descrito '
          'na seção 9.',
        ),
      );
    });
  });

  group('Exclusão de conta — página', () {
    late String html;
    late String texto;

    setUp(() {
      html = pagina('exclusao-conta.html');
      texto = textoVisivel(html);
    });

    test('explica o caminho pelo app', () {
      expect(texto, contains('Excluir minha conta'));
      expect(texto, contains('senha'));
    });

    test('permite pedir a exclusão sem o app', () {
      expect(
        html,
        contains('href="mailto:suporte.minhagestacaoapp@gmail.com?subject='),
      );
    });

    test('não finge que a exclusão pela web é automática', () {
      expect(texto, contains('não é automática'));
      expect(texto, contains('processada pelo responsável'));
    });

    test('exige o e-mail cadastrado para proteger a conta', () {
      expect(texto, contains('a partir do e-mail cadastrado na sua conta'));
    });

    test('diz o que é apagado e o que pode continuar existindo', () {
      expect(texto, contains('O que é apagado'));
      expect(texto, contains('O que pode continuar existindo'));
    });
  });

  group('Site público — higiene', () {
    test('nenhum marcador de texto pendente', () {
      for (final nome in paginas) {
        final texto = textoVisivel(pagina(nome));

        for (final marcador in [
          '[',
          ']',
          'XXX',
          'TODO',
          'PREENCHER',
          'Lorem',
          '{{',
          'CNPJ',
        ]) {
          expect(texto, isNot(contains(marcador)), reason: '$nome: $marcador');
        }
      }
    });

    test('nenhuma credencial ou chave no site', () {
      final arquivos = Directory(
        'public',
      ).listSync(recursive: true).whereType<File>();

      for (final arquivo in arquivos) {
        final conteudo = arquivo.readAsStringSync();

        for (final segredo in [
          'AIza',
          'storePassword',
          'keyPassword',
          'PRIVATE KEY',
          'apiKey',
        ]) {
          expect(
            conteudo,
            isNot(contains(segredo)),
            reason: '${arquivo.path}: $segredo',
          );
        }
      }
    });

    test('o site não carrega scripts nem rastreadores', () {
      for (final nome in paginas) {
        final html = pagina(nome);

        expect(html, isNot(contains('<script')), reason: nome);
        expect(html, isNot(contains('gtag')), reason: nome);
        expect(html, isNot(contains('googletagmanager')), reason: nome);
      }
    });
  });
}
