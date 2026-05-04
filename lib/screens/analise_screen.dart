import 'package:flutter/material.dart';
import '../data/contracoes_data.dart';

class AnaliseScreen extends StatelessWidget {
  const AnaliseScreen({super.key});

  int get total => listaContracoes.length;
  int get fortes =>
      listaContracoes.where((c) => c.intensidade == 'Forte').length;
  int get moderadas =>
      listaContracoes.where((c) => c.intensidade == 'Moderada').length;
  int get leves =>
      listaContracoes.where((c) => c.intensidade == 'Leve').length;

  String gerarRecomendacao() {
    if (listaContracoes.isEmpty) {
      return 'Nenhuma contração registrada ainda. Registre novas contrações para receber uma análise.';
    }

    if (listaContracoes.length == 1) {
      return 'Há apenas uma contração registrada. Continue monitorando para identificar um possível padrão.';
    }

    final ultimas = listaContracoes.reversed.take(3).toList();
    final fortesRecentes = ultimas.where((c) => c.intensidade == 'Forte').length;
    final moderadasRecentes =
        ultimas.where((c) => c.intensidade == 'Moderada').length;

    if (total >= 5 && fortesRecentes >= 2) {
      return 'Há um padrão indicando aumento de intensidade. Procure orientação profissional e prepare-se para ir à maternidade se o padrão persistir.';
    }

    if (total >= 4 && (fortesRecentes + moderadasRecentes) >= 2) {
      return 'Existe um padrão sugestivo de evolução das contrações. Continue observando frequência e intensidade.';
    }

    if (total >= 3) {
      return 'As contrações já mostram repetição. Continue registrando para melhorar a análise.';
    }

    return 'Continue registrando as contrações. Ainda não há dados suficientes para uma recomendação mais precisa.';
  }

  bool get statusAtencao => total >= 4 && (fortes + moderadas) >= 2;

  Widget navBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color.fromRGBO(0, 0, 0, 0.06),
          width: 0.5,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(36),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(Icons.home_rounded, color: Color(0xFF888780), size: 20),
          Icon(Icons.access_time_rounded, color: Color(0xFF888780), size: 20),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_graph_rounded, color: Color(0xFF534AB7), size: 20),
              SizedBox(height: 3),
              CircleAvatar(
                radius: 2,
                backgroundColor: Color(0xFF534AB7),
              ),
            ],
          ),
          Icon(Icons.chat_bubble_outline_rounded,
              color: Color(0xFF888780), size: 20),
        ],
      ),
    );
  }

  Widget bar(double h, String day, Color color) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            day,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFFB4B2A9),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recomendacao = gerarRecomendacao();

    return Scaffold(
      backgroundColor: const Color(0xFFF0EEFF),
      body: Center(
        child: Container(
          width: 300,
          constraints: const BoxConstraints(minHeight: 620),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: const Color.fromRGBO(0, 0, 0, 0.08),
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDF6FF),
                  border: Border(
                    bottom: BorderSide(
                      color: Color.fromRGBO(0, 0, 0, 0.05),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.chevron_left_rounded,
                            color: Color(0xFF7F77DD),
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Voltar',
                            style: TextStyle(
                              color: Color(0xFF7F77DD),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Análise Inteligente',
                      style: TextStyle(
                        color: Color(0xFF26215C),
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Padrões e insights com IA',
                      style: TextStyle(
                        color: Color(0xFF888780),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusAtencao
                            ? const Color(0xFFFAEEDA)
                            : const Color(0xFFE1F5EE),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: statusAtencao
                                  ? const Color.fromRGBO(186, 117, 23, 0.15)
                                  : const Color.fromRGBO(29, 158, 117, 0.15),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              statusAtencao
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 20,
                              color: statusAtencao
                                  ? const Color(0xFF633806)
                                  : const Color(0xFF085041),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  statusAtencao ? 'Atenção' : 'Monitoramento estável',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: statusAtencao
                                        ? const Color(0xFF633806)
                                        : const Color(0xFF085041),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Acompanhe a evolução das contrações para entender melhor o padrão.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF888780),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color.fromRGBO(0, 0, 0, 0.07),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Padrão recente',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF26215C),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 75,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                bar(18, 'S', const Color(0xFFE1F5EE)),
                                const SizedBox(width: 5),
                                bar(30, 'T', const Color(0xFFEEEDFE)),
                                const SizedBox(width: 5),
                                bar(24, 'Q', const Color(0xFFE1F5EE)),
                                const SizedBox(width: 5),
                                bar(42, 'Q', const Color(0xFFFAEEDA)),
                                const SizedBox(width: 5),
                                bar(55, 'S', const Color(0xFFFBEAF0)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEDFE),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              CircleAvatar(
                                radius: 3,
                                backgroundColor: Color(0xFF534AB7),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'INSIGHT DA IA',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF534AB7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            recomendacao,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF3C3489),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color.fromRGBO(0, 0, 0, 0.07),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resumo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF26215C),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total registradas: $total\nLeves: $leves\nModeradas: $moderadas\nFortes: $fortes',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888780),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              navBar(),
            ],
          ),
        ),
      ),
    );
  }
}