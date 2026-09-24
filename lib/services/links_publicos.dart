import 'package:flutter/services.dart';

class LinksPublicos {
  static const String site = 'https://minha-gestacao-4af55.web.app';
  static const String politicaDePrivacidade = '$site/privacidade.html';

  static const MethodChannel canal = MethodChannel('minha_gestacao/links');

  static Future<bool> abrir(String url) async {
    try {
      final abriu = await canal.invokeMethod<bool>('abrir', {'url': url});
      return abriu ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
