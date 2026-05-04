class IaService {
  static Future<String> perguntar(String pergunta) async {
    await Future.delayed(const Duration(seconds: 1));

    final texto = pergunta.toLowerCase();

    if (texto.contains('maternidade') || texto.contains('ir para')) {
      return 'Se as contrações estiverem ficando frequentes, intensas e regulares, procure sua maternidade conforme orientação do seu profissional de saúde.';
    }

    if (texto.contains('falsa') || texto.contains('verdadeira')) {
      return 'Contrações verdadeiras tendem a ficar mais regulares, intensas e próximas. Contrações falsas costumam ser irregulares e menos progressivas.';
    }

    if (texto.contains('acompanhante')) {
      return 'O acompanhante pode ajudar a manter a calma, observar os intervalos das contrações, organizar documentos e apoiar a gestante física e emocionalmente.';
    }

    if (texto.contains('sangramento')) {
      return 'Sangramento importante não deve ser ignorado. Procure avaliação profissional ou emergência imediatamente.';
    }

    if (texto.contains('maternidade') || texto.contains('levar')) {
      return 'Documentos, exames, itens de higiene, roupas para a mãe e o bebê, além do que foi orientado previamente pela sua maternidade.';
    }

    return 'Posso ajudar com dúvidas sobre contrações, sinais de atenção, ida à maternidade e apoio do acompanhante.';
  }
}