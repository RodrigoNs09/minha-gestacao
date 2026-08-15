import 'dart:async';
import 'package:flutter/material.dart';
import '../models/contracao.dart';
import '../data/contracoes_data.dart';
import '../services/contracoes_storage.dart';
import '../theme/app_theme.dart';

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

    final dataRegistro =
        '${_inicioDateTime!.year}-${_inicioDateTime!.month.toString().padLeft(2, '0')}-${_inicioDateTime!.day.toString().padLeft(2, '0')}';

    final novaContracao = Contracao(
      data: dataRegistro,
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

  Widget navBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.navBar(context),
        border: Border.all(
          color: AppColors.border(context),
          width: 0.5,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(36),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(Icons.home_rounded, color: AppColors.textSecondary(context), size: 20),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time_rounded, color: AppTheme.primaryPurple, size: 20),
              const SizedBox(height: 3),
              const CircleAvatar(
                radius: 2,
                backgroundColor: Color(0xFF534AB7),
              ),
            ],
          ),
          Icon(Icons.auto_graph_rounded, color: AppColors.textSecondary(context), size: 20),
          Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textSecondary(context), size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Center(
        child: Container(
          width: 300,
          constraints: const BoxConstraints(minHeight: 620),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: AppColors.borderStrong(context),
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
                    color: AppColors.surface(context),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.statPurple(context),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'DURAÇÃO ATUAL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.purpleLabel(context),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                formatarTempo(_segundos),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.accentText(context),
                                  height: 1,
                                  letterSpacing: -2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'min : seg',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.purpleLabel(context),
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
                              color: AppColors.surface(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primaryPurple.withOpacity(0.25),
                              ),
                            ),
                            child: Text(
                              '■ Parar e Salvar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.primaryPurple,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'INTENSIDADE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            intensidadeButton(
                              label: 'Leve',
                              emoji: '😌',
                              bgColor: AppColors.statGreen(context),
                              textColor: const Color(0xFF085041),
                              selected: intensidade == 'Leve',
                            ),
                            const SizedBox(width: 8),
                            intensidadeButton(
                              label: 'Moderada',
                              emoji: '😬',
                              bgColor: AppColors.statOrange(context),
                              textColor: const Color(0xFF633806),
                              selected: intensidade == 'Moderada',
                            ),
                            const SizedBox(width: 8),
                            intensidadeButton(
                              label: 'Forte',
                              emoji: '😣',
                              bgColor: AppColors.statPink(context),
                              textColor: const Color(0xFF72243E),
                              selected: intensidade == 'Forte',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'OBSERVAÇÃO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: observacoesController,
                          maxLines: 4,
                          style: TextStyle(color: AppColors.textPrimary(context)),
                          decoration: InputDecoration(
                            hintText: 'Adicione uma anotação...',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                            filled: true,
                            fillColor: AppColors.statPurple(context),
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: BorderSide(
                                color: AppTheme.primaryPurple.withOpacity(0.12),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: BorderSide(
                                color: AppTheme.primaryPurple.withOpacity(0.12),
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
                navBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}