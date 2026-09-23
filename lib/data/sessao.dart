import 'chutes_data.dart';
import 'consultas_data.dart';
import 'contracoes_data.dart';
import 'gestacao_data.dart';
import 'sintomas_data.dart';

void limparEstadoDaSessao() {
  listaContracoes = [];
  listaChutes = [];
  listaSintomas = [];
  listaConsultas = [];
  encerrarGestacao();
}
