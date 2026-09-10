import '../models/gestacao_info.dart';

DateTime _dumPadrao() =>
    DateTime.now().subtract(const Duration(days: 28 * 7 + 3));

GestacaoInfo gestacaoAtual = GestacaoInfo(dum: _dumPadrao());

void atualizarDUM(DateTime novaDum) {
  gestacaoAtual = GestacaoInfo(
    dum: novaDum,
    id: gestacaoAtual.id,
    configurada: true,
  );
}

void iniciarGestacao(DateTime dum) {
  gestacaoAtual = GestacaoInfo(dum: dum, configurada: true);
}

void definirGestacao(DateTime dum, String id) {
  gestacaoAtual = GestacaoInfo(dum: dum, id: id, configurada: true);
}

void encerrarGestacao() {
  gestacaoAtual = GestacaoInfo(dum: _dumPadrao());
}
