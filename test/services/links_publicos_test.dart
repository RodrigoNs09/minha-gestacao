import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/services/links_publicos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mensageiro =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => mensageiro.setMockMethodCallHandler(LinksPublicos.canal, null));

  String mainActivity() => File(
    'android/app/src/main/kotlin/com/rodrigons/minhadegestacao/MainActivity.kt',
  ).readAsStringSync();

  group('LinksPublicos — endereços', () {
    test('a política está no domínio do Firebase Hosting do projeto', () {
      final projeto = RegExp(
        r'"default"\s*:\s*"([^"]+)"',
      ).firstMatch(File('.firebaserc').readAsStringSync())!.group(1);

      expect(LinksPublicos.site, 'https://$projeto.web.app');
      expect(
        LinksPublicos.politicaDePrivacidade,
        startsWith('${LinksPublicos.site}/'),
      );
    });

    test('o arquivo apontado existe no site publicado', () {
      final caminho = Uri.parse(LinksPublicos.politicaDePrivacidade).path;

      expect(File('public$caminho').existsSync(), isTrue, reason: caminho);
    });

    test('só usa https', () {
      expect(LinksPublicos.politicaDePrivacidade, startsWith('https://'));
    });
  });

  group('LinksPublicos — abrir', () {
    test('pede ao Android para abrir a URL e devolve o resultado', () async {
      MethodCall? recebida;
      mensageiro.setMockMethodCallHandler(LinksPublicos.canal, (chamada) async {
        recebida = chamada;
        return true;
      });

      final abriu = await LinksPublicos.abrir(
        LinksPublicos.politicaDePrivacidade,
      );

      expect(abriu, isTrue);
      expect(recebida?.method, 'abrir');
      expect(recebida?.arguments, {'url': LinksPublicos.politicaDePrivacidade});
    });

    test('sem navegador disponível devolve false', () async {
      mensageiro.setMockMethodCallHandler(
        LinksPublicos.canal,
        (_) async => false,
      );

      expect(await LinksPublicos.abrir(LinksPublicos.site), isFalse);
    });

    test('sem implementação nativa devolve false em vez de lançar', () async {
      expect(await LinksPublicos.abrir(LinksPublicos.site), isFalse);
    });

    test('erro da plataforma devolve false em vez de lançar', () async {
      mensageiro.setMockMethodCallHandler(LinksPublicos.canal, (_) async {
        throw PlatformException(code: 'falha');
      });

      expect(await LinksPublicos.abrir(LinksPublicos.site), isFalse);
    });
  });

  group('LinksPublicos — lado Android', () {
    test('o canal tem o mesmo nome dos dois lados', () {
      expect(mainActivity(), contains('"${LinksPublicos.canal.name}"'));
    });

    test('o Android só abre endereços https', () {
      final codigo = mainActivity();

      expect(codigo, contains('url.startsWith("https://")'));
      expect(codigo, contains('Intent.ACTION_VIEW'));
      expect(codigo, contains('ActivityNotFoundException'));
    });

    test('o registro dos plugins continua acontecendo', () {
      expect(
        mainActivity(),
        contains('super.configureFlutterEngine(flutterEngine)'),
      );
    });

    test('nenhuma dependência nova foi adicionada para abrir links', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, isNot(contains('url_launcher')));
    });
  });
}
