import 'dart:async';
import 'package:flutter/material.dart';
import '../models/contracao.dart';
import '../data/contracoes_data.dart';
import '../services/contracoes_storage.dart';

class ContracaoScreen extends StatefulWidget {
  const ContracaoScreen({super.key});

  @override
  State<ContracaoScreen> createState() => _ContracaoScreenState();
}

class _ContracaoScreenState extends State<ContracaoScreen> {
  Timer? _timer;
  int _segundos = 0;
  bool _emAndamento = false;
  DateTime? _inicioDateTime;

  String intensidade = 'Forte';
  final TextEditingController observacoesController = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    observacoesController.dispose();
    super.dispose();
  }

  String formatarTempo(int totalSegundos) {
    final minutos = (totalSegundos ~/ 60).toString().padLeft(2, '0');
    final segundos = (totalSegundos % 60).toString().padLeft(2, '0');
    return '$minutos:$segundos';
  }

  void iniciarContracao() {
    if (_emAndamento) return;

    setState(() {
      _emAndamento = true;
      _segundos = 0;
      _inicioDateTime = DateTime.now();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _segundos++;
      });
    });
  }

  Future<void> pararESalvarContracao() async {
    if (!_emAndamento || _inicioDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicie uma contração antes de salvar.')),
      );
      return;
    }

    _timer?.cancel();
    final fimDateTime = DateTime.now();

    final novaContracao = Contracao(
      inicio:
          '${_inicioDateTime!.hour.toString().padLeft(2, '0')}:${_inicioDateTime!.minute.toString().padLeft(2, '0')}',
      fim:
          '${fimDateTime.hour.toString().padLeft(2, '0')}:${fimDateTime.minute.toString().padLeft(2, '0')}',
      intensidade: intensidade,
      observacoes: observacoesController.text.trim().isEmpty
          ? 'Duração: ${formatarTempo(_segundos)}'
          : 'Duração: ${formatarTempo(_segundos)} | ${observacoesController.text.trim()}',
    );

    listaContracoes.add(novaContracao);
    await ContracoesStorage.salvarContracoes(listaContracoes);

    setState(() {
      _emAndamento = false;
      _segundos = 0;
      _inicioDateTime = null;
      intensidade = 'Forte';
      observacoesController.clear();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contração salva com sucesso!')),
    );
  }

  Widget intensidadeButton({
    required String label,
    required String emoji,
    required Color bgColor,
    required Color textColor,
    required bool selected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            intensidade = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? textColor : Colors.transparent,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time_rounded, color: Color(0xFF534AB7), size: 20),
              SizedBox(height: 3),
              CircleAvatar(
                radius: 2,
                backgroundColor: Color(0xFF534AB7),
              ),
            ],
          ),
          Icon(Icons.auto_graph_rounded, color: Color(0xFF888780), size: 20),
          Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF888780), size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF534AB7), Color(0xFF7F77DD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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
                              color: Color.fromRGBO(255, 255, 255, 0.7),
                              size: 18,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Voltar',
                              style: TextStyle(
                                color: Color.fromRGBO(255, 255, 255, 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Registrar Contração',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Monitore em tempo real',
                        style: TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'DURAÇÃO ATUAL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF7F77DD),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                formatarTempo(_segundos),
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF3C3489),
                                  height: 1,
                                  letterSpacing: -2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'min : seg',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7F77DD),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: iniciarContracao,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF534AB7), Color(0xFF7F77DD)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _emAndamento
                                  ? 'Contração em andamento...'
                                  : '▶ Iniciar Contração',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: pararESalvarContracao,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color.fromRGBO(83, 74, 183, 0.25),
                              ),
                            ),
                            child: const Text(
                              '■ Parar e Salvar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF534AB7),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'INTENSIDADE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: Color(0xFFB4B2A9),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            intensidadeButton(
                              label: 'Leve',
                              emoji: '😌',
                              bgColor: const Color(0xFFE1F5EE),
                              textColor: const Color(0xFF085041),
                              selected: intensidade == 'Leve',
                            ),
                            const SizedBox(width: 8),
                            intensidadeButton(
                              label: 'Moderada',
                              emoji: '😬',
                              bgColor: const Color(0xFFFAEEDA),
                              textColor: const Color(0xFF633806),
                              selected: intensidade == 'Moderada',
                            ),
                            const SizedBox(width: 8),
                            intensidadeButton(
                              label: 'Forte',
                              emoji: '😣',
                              bgColor: const Color(0xFFFBEAF0),
                              textColor: const Color(0xFF72243E),
                              selected: intensidade == 'Forte',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'OBSERVAÇÃO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: Color(0xFFB4B2A9),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: observacoesController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Adicione uma anotação...',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888780),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF7F5FF),
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(
                                color: Color.fromRGBO(83, 74, 183, 0.12),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(
                                color: Color.fromRGBO(83, 74, 183, 0.12),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(
                                color: Color(0xFF7F77DD),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                navBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}