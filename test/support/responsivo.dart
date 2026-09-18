import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Apoio para os testes de responsividade.
///
/// Padroniza o que hoje está duplicado em cada arquivo de teste de tela, e
/// deliberadamente **não** oferece supressão de overflow: um `RenderFlex`
/// estourado deve reprovar o teste, não ser escondido.

/// Tamanhos de referência, em dp. Correspondem a aparelhos reais em vez de
/// superfícies artificialmente grandes — foi justamente a superfície de
/// 1000x2400 dos testes antigos que deixou passar os defeitos de layout.
class Telas {
  const Telas._();

  /// Aparelho pequeno.
  static const pequena = Size(320, 568);

  /// Aparelho comum.
  static const comum = Size(360, 640);

  /// Motorola G10 — a referência das validações físicas.
  static const g10 = Size(411.43, 835);

  /// Tablet pequeno.
  static const tabletPequeno = Size(600, 960);

  /// Tablet.
  static const tablet = Size(800, 1280);

  /// Paisagem de aparelho comum.
  static const paisagem = Size(800, 360);

  /// Todas as anteriores, para varrer a matriz de uma vez.
  static const todas = <String, Size>{
    '320x568': pequena,
    '360x640': comum,
    '411x835': g10,
    '600x960': tabletPequeno,
    '800x1280': tablet,
    '800x360 (paisagem)': paisagem,
  };
}

/// Altura aproximada do teclado do G10 em retrato, medida no aparelho.
const double alturaDeTecladoRetrato = 322;

/// Altura aproximada do teclado em paisagem, onde sobra bem menos tela.
const double alturaDeTecladoPaisagem = 230;

/// Monta [tela] numa superfície de tamanho e escala de texto controlados.
///
/// `devicePixelRatio` fica em 1.0 para que o tamanho informado seja lido
/// diretamente em dp, o que torna as asserções de geometria legíveis.
///
/// [assentar] usa `pumpAndSettle`. Telas com animação infinita
/// (`Timer.periodic`, `AnimationController.repeat`) nunca assentam — para
/// elas passe `false`, que o helper avança o tempo em passos fixos.
Future<void> montar(
  WidgetTester tester,
  Widget tela, {
  Size tamanho = Telas.comum,
  double escalaDeTexto = 1.0,
  bool assentar = true,
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: tela,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: escalaDeTexto,
        maxScaleFactor: escalaDeTexto,
        child: child!,
      ),
    ),
  );

  await _avancar(tester, assentar: assentar);
}

/// Simula o teclado subindo **depois** de a tela já estar montada, que é a
/// ordem real. Aplicar o recuo antes encolheria a tela desde o primeiro
/// quadro e mascararia o comportamento que se quer medir.
Future<void> abrirTeclado(
  WidgetTester tester, {
  double altura = alturaDeTecladoRetrato,
  bool assentar = true,
}) async {
  tester.view.viewInsets = FakeViewPadding(bottom: altura);
  addTearDown(tester.view.resetViewInsets);

  await _avancar(tester, assentar: assentar);
}

Future<void> _avancar(WidgetTester tester, {required bool assentar}) async {
  if (assentar) {
    await tester.pumpAndSettle();
    return;
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Largura que um cartão de [maxWidth] deve ter numa tela de [larguraDaTela],
/// considerando os 12 dp de padding lateral da [MolduraResponsiva].
///
/// Deixa as asserções de geometria explícitas em vez de espalhar números
/// mágicos pelos testes.
double larguraEsperadaDoCartao(double larguraDaTela, {double maxWidth = 400}) {
  final disponivel = larguraDaTela - 24;
  return disponivel < maxWidth ? disponivel : maxWidth;
}
