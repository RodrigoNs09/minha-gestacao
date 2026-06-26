import 'package:flutter/material.dart';
import '../data/contracoes_data.dart';
import '../models/contracao.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  String _filtro = 'Hoje';

  List<Contracao> get contracoesFiltradas {
    final agora = DateTime.now();

    return listaContracoes.where((c) {
      final partes = c.inicio.split(':');
      if (partes.length < 2) return false;
      final hora = int.tryParse(partes[0]) ?? 0;
      final minuto = int.tryParse(partes[1]) ?? 0;

      final horarioContracao = DateTime(
        agora.year,
        agora.month,
        agora.day,
        hora,
        minuto,
      );

      if (_filtro == 'Hoje') {
        return horarioContracao.day == agora.day &&
            horarioContracao.month == agora.month &&
            horarioContracao.year == agora.year;
      } else if (_filtro == 'Semana') {
        final seteDiasAtras = agora.subtract(const Duration(days: 7));
        return horarioContracao.isAfter(seteDiasAtras);
      } else {
        // Mês
        return horarioContracao.month == agora.month &&
            horarioContracao.year == agora.year;
      }
    }).toList();
  }

  String get intervaloMedio {
    final lista = contracoesFiltradas;
    if (lista.length < 2) return '—';

    final horarios = lista.map((c) {
      final partes = c.inicio.split(':');
      if (partes.length != 2) return null;
      final hora = int.tryParse(partes[0]);
      final minuto = int.tryParse(partes[1]);
      if (hora == null || minuto == null) return null;
      return hora * 60 + minuto;
    }).whereType<int>().toList();

    if (horarios.length < 2) return '—';

    int soma = 0;
    for (int i = 1; i < horarios.length; i++) {
      soma += (horarios[i] - horarios[i - 1]).abs();
    }

    final media = soma ~/ (horarios.length - 1);
    return '${media}min';
  }

  String get duracaoMedia {
    final lista = contracoesFiltradas;
    if (lista.isEmpty) return '—';

    int somaSegundos = 0;
    int validas = 0;

    for (final c in lista) {
      final match =
          RegExp(r'Duração:\s*([0-9]{2}):([0-9]{2})').firstMatch(c.observacoes);
      if (match != null) {
        final min = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seg = int.tryParse(match.group(2) ?? '0') ?? 0;
        somaSegundos += (min * 60) + seg;
        validas++;
      }
    }

    if (validas == 0) return '—';

    final media = somaSegundos ~/ validas;
    final min = media ~/ 60;
    final seg = media % 60;

    if (min > 0) return '${min}min';
    return '${seg}s';
  }

  Color badgeBg(String intensidade) {
    switch (intensidade) {
      case 'Forte':
        return const Color(0xFFFBEAF0);
      case 'Moderada':
        return const Color(0xFFFAEEDA);
      default:
        return const Color(0xFFE1F5EE);
    }
  }

  Color badgeText(String intensidade) {
    switch (intensidade) {
      case 'Forte':
        return const Color(0xFF72243E);
      case 'Moderada':
        return const Color(0xFF633806);
      default:
        return const Color(0xFF085041);
    }
  }

  Color dotColor(String intensidade) {
    switch (intensidade) {
      case 'Forte':
        return const Color(0xFFD4537E);
      case 'Moderada':
        return const Color(0xFFEF9F27);
      default:
        return const Color(0xFF1D9E75);
    }
  }

  String extrairDuracao(String observacoes) {
    final match =
        RegExp(r'Duração:\s*([0-9]{2}:[0-9]{2})').firstMatch(observacoes);
    if (match != null) return match.group(1)!;
    return '--:--';
  }

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

  @override
  Widget build(BuildContext context) {
    final lista = contracoesFiltradas;

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
                      'Histórico',
                      style: TextStyle(
                        color: Color(0xFF26215C),
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Acompanhe todos os registros',
                      style: TextStyle(
                        color: Color(0xFF888780),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: ['Hoje', 'Semana', 'Mês'].map((f) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filtro = f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 13, vertical: 5),
                              decoration: BoxDecoration(
                                color: _filtro == f
                                    ? const Color(0xFF534AB7)
                                    : const Color(0xFFEEEDFE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _filtro == f
                                      ? Colors.white
                                      : const Color(0xFF534AB7),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF534AB7), Color(0xFF7F77DD)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          _summaryItem('${lista.length}', 'Total'),
                          _divider(),
                          _summaryItem(intervaloMedio, 'Intervalo'),
                          _divider(),
                          _summaryItem(duracaoMedia, 'Duração méd.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${_filtro.toUpperCase()} — REGISTROS',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                        color: Color(0xFFB4B2A9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (lista.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color.fromRGBO(0, 0, 0, 0.07),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'Nenhuma contração registrada $_filtro.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF888780),
                          ),
                        ),
                      )
                    else
                      ...lista.reversed.map((c) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color.fromRGBO(0, 0, 0, 0.07),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: dotColor(c.intensidade),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.inicio,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF26215C),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      'Duração: ${extrairDuracao(c.observacoes)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF888780),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg(c.intensidade),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  c.intensidade,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: badgeText(c.intensidade),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
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

  Widget _summaryItem(String valor, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: const Color.fromRGBO(255, 255, 255, 0.2),
    );
  }
}