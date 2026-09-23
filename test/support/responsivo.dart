import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


class Telas {
  const Telas._();

  static const pequena = Size(320, 568);

  static const comum = Size(360, 640);

  static const g10 = Size(411.43, 835);

  static const tabletPequeno = Size(600, 960);

  static const tablet = Size(800, 1280);

  static const paisagem = Size(800, 360);

  static const todas = <String, Size>{
    '320x568': pequena,
    '360x640': comum,
    '411x835': g10,
    '600x960': tabletPequeno,
    '800x1280': tablet,
    '800x360 (paisagem)': paisagem,
  };
}

const double alturaDeTecladoRetrato = 322;

const double alturaDeTecladoPaisagem = 230;

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

double larguraEsperadaDoCartao(double larguraDaTela, {double maxWidth = 400}) {
  final disponivel = larguraDaTela - 24;
  return disponivel < maxWidth ? disponivel : maxWidth;
}
