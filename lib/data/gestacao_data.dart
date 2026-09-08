import '../models/gestacao_info.dart';

// DUM padrão (semana 28) — usada até o usuário configurar a data real
DateTime _dumPadrao = DateTime.now().subtract(const Duration(days: 28 * 7 + 3));

GestacaoInfo gestacaoAtual = GestacaoInfo(dum: _dumPadrao);

void atualizarDUM(DateTime novaDum) {
  gestacaoAtual = GestacaoInfo(dum: novaDum, id: gestacaoAtual.id);
}

void iniciarGestacao(DateTime dum) {
  gestacaoAtual = GestacaoInfo(dum: dum);
}

void definirGestacao(DateTime dum, String id) {
  gestacaoAtual = GestacaoInfo(dum: dum, id: id);
}
