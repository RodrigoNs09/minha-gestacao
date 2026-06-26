import 'package:flutter/material.dart';
import '../data/contracoes_data.dart';
import '../services/contracoes_storage.dart';

class AnaliseScreen extends StatefulWidget {
  const AnaliseScreen({super.key});

  @override
  State<AnaliseScreen> createState() => _AnaliseScreenState();
}

class _AnaliseScreenState extends State<AnaliseScreen> {

  @override
  void initState() {
    super.initState();
    _recarregar();
  }

  Future<void> _recarregar() async {
    final dados = await ContracoesStorage.carregarContracoes();
    setState(() {
      listaContracoes = dados;
    });
  }

  int get total => listaContracoes.length;
  int get fortes => listaContracoes.where((c) => c.intensidade == 'Forte').length;
  int get moderadas => listaContracoes.where((c) => c.intensidade == 'Moderada').length;
  int get leves => listaContracoes.where((c) => c.intensidade == 'Leve').length;

  List<Map<String, dynamic>> gerarDadosGrafico() {
    final blocos = [
      {'label': '0h', 'horas': [0, 1, 2, 3]},
      {'label': '4h', 'horas': [4, 5, 6, 7]},
      {'label': '8h', 'horas': [8, 9, 10, 11]},
      {'label': '12h', 'horas': [12, 13, 14, 15]},
      {'label': '16h', 'horas': [16, 17, 18, 19]},
      {'label': '20h', 'horas': [20, 21, 22, 23]},
    ];

    return blocos.map((bloco) {
      final horas = bloco['horas'] as List<int>;

      final count = listaContracoes.where((c) {
        final partes = c.inicio.split(':');
        if (partes.isEmpty) return false;
        final hora = int.tryParse(partes[0]) ?? -1;
        return horas.contains(hora);
      }).length;

      final fortesBloco = listaContracoes.where((c) {
        final partes = c.inicio.split(':');
        if (partes.isEmpty) return false;
        final hora = int.tryParse(partes[0]) ?? -1;
        return horas.contains(hora) && c.intensidade == 'Forte';
      }).length;

      final moderadasBloco = listaContracoes.where((c) {
        final partes = c.inicio.split(':');
        if (partes.isEmpty) return false;
        final hora = int.tryParse(partes[0]) ?? -1;
        return horas.contains(hora) && c.intensidade == 'Moderada';
      }).length;

      Color cor;
      if (fortesBloco > 0) {
        cor = const Color(0xFFFBEAF0);
      } else if (moderadasBloco > 0) {
        cor = const Color(0xFFFAEEDA);
      } else if (count > 0) {
        cor = const Color(0xFFE1F5EE);
      } else {
        cor = const Color(0xFFEEEDFE);
      }

      return {'label': bloco['label'], 'count': count, 'cor': cor};
    }).toList();
  }

  String gerarRecomendacao() {
    if (listaContracoes.isEmpty) {
      return 'Nenhuma contração registrada ainda. Registre novas contrações para receber uma análise.';
    }
    if (listaContracoes.length == 1) {
      return 'Há apenas uma contração registrada. Continue monitorando para identificar um possível padrão.';
    }
    final ultimas = listaContracoes.reversed.take(3).toList();
    final fortesRecentes = ultimas.where((c) => c.intensidade == 'Forte').length;
    final moderadasRecentes = ultimas.where((c) => c.intensidade == 'Moderada').length;

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

  // CORREÇÃO: bar() agora retorna Column (sem Expanded)
  Widget _barColumn(double maxAltura, int count, int maxCount, String label, Color color) {
    final altura = maxCount == 0 ? 8.0 : (count / maxCount * maxAltura).clamp(8.0, maxAltura);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (count > 0)
          Text(
            '$count',
            style: const TextStyle(fontSize: 8, color: Color(0xFF534AB7), fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 2),
        Container(
          height: altura,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFFB4B2A9))),
      ],
    );
  }

  Widget navBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.06), width: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
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
              CircleAvatar(radius: 2, backgroundColor: Color(0xFF534AB7)),
            ],
          ),
          Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF888780), size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recomendacao = gerarRecomendacao();
    final dadosGrafico = gerarDadosGrafico();
    final maxCount = dadosGrafico
        .map((d) => d['count'] as int)
        .fold(0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: const Color(0xFFF0EEFF),
      body: Center(
        child: Container(
          width: 300,
          constraints: const BoxConstraints(minHeight: 620),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.08), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDF6FF),
                  border: Border(bottom: BorderSide(color: Color.fromRGBO(0, 0, 0, 0.05), width: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.chevron_left_rounded, color: Color(0xFF7F77DD), size: 18),
                          SizedBox(width: 4),
                          Text('Voltar', style: TextStyle(color: Color(0xFF7F77DD), fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Análise Inteligente',
                        style: TextStyle(color: Color(0xFF26215C), fontSize: 20, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    const Text('Padrões e insights com IA',
                        style: TextStyle(color: Color(0xFF888780), fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                  children: [
                    // Card de status
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusAtencao ? const Color(0xFFFAEEDA) : const Color(0xFFE1F5EE),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: statusAtencao
                                  ? const Color.fromRGBO(186, 117, 23, 0.15)
                                  : const Color.fromRGBO(29, 158, 117, 0.15),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              statusAtencao ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                              size: 20,
                              color: statusAtencao ? const Color(0xFF633806) : const Color(0xFF085041),
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
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: statusAtencao ? const Color(0xFF633806) : const Color(0xFF085041),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Acompanhe a evolução das contrações para entender melhor o padrão.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF888780), height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Gráfico com dados reais — CORRIGIDO
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.07), width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Contrações por período',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF26215C))),
                          const SizedBox(height: 4),
                          const Text('Distribuição ao longo do dia',
                              style: TextStyle(fontSize: 10, color: Color(0xFFB4B2A9))),
                          const SizedBox(height: 12),
                          if (listaContracoes.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text('Nenhum dado ainda',
                                    style: TextStyle(fontSize: 12, color: Color(0xFFB4B2A9))),
                              ),
                            )
                          else
                            SizedBox(
                              height: 100,
                              // CORREÇÃO: Row direto com Expanded e SizedBox intercalados
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (int i = 0; i < dadosGrafico.length; i++) ...[
                                    Expanded(
                                      child: _barColumn(
                                        60,
                                        dadosGrafico[i]['count'] as int,
                                        maxCount,
                                        dadosGrafico[i]['label'] as String,
                                        dadosGrafico[i]['cor'] as Color,
                                      ),
                                    ),
                                    if (i < dadosGrafico.length - 1) const SizedBox(width: 5),
                                  ],
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _legenda(const Color(0xFFFBEAF0), 'Forte'),
                              const SizedBox(width: 10),
                              _legenda(const Color(0xFFFAEEDA), 'Moderada'),
                              const SizedBox(width: 10),
                              _legenda(const Color(0xFFE1F5EE), 'Leve'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Insight IA
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEEEDFE), borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              CircleAvatar(radius: 3, backgroundColor: Color(0xFF534AB7)),
                              SizedBox(width: 6),
                              Text('INSIGHT DA IA',
                                  style: TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5, color: Color(0xFF534AB7))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(recomendacao,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF3C3489), height: 1.6)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Resumo
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.07), width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resumo',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF26215C))),
                          const SizedBox(height: 8),
                          _resumoItem('Total registradas', '$total'),
                          _resumoItem('Leves', '$leves'),
                          _resumoItem('Moderadas', '$moderadas'),
                          _resumoItem('Fortes', '$fortes'),
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

  Widget _legenda(Color cor, String label) {
    return Row(
      children: [
        Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFFB4B2A9))),
      ],
    );
  }

  Widget _resumoItem(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
          Text(valor,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF26215C))),
        ],
      ),
    );
  }
}