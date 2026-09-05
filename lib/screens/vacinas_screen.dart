import 'package:flutter/material.dart';

import '../data/gestacao_data.dart';
import '../data/vacinas_calendario_2026.dart';
import '../data/vacinas_ui.dart';
import '../models/registro_vacinacao.dart';
import '../services/firestore_error.dart';
import '../services/vacinas_engine.dart';
import '../services/vacinas_storage.dart';
import '../theme/app_theme.dart';

class VacinasScreen extends StatefulWidget {
  const VacinasScreen({super.key});

  @override
  State<VacinasScreen> createState() => _VacinasScreenState();
}

class _VacinasScreenState extends State<VacinasScreen> {
  bool _carregando = true;
  String? _erro;

  List<RegistroVacinacao>? _historico;

  // Referência temporal única desta avaliação: DUM e data corrente saem do
  // mesmo instante, para que semana e intervalo não se contradigam.
  DateTime? _avaliadoEm;
  DateTime? _dum;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final registros = await VacinasStorage.carregarRegistros();
      if (!mounted) return;

      final agora = DateTime.now();
      setState(() {
        _historico = registros;
        _avaliadoEm = agora;
        _dum = gestacaoAtual.dum;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      // Sem histórico confirmado a engine não é chamada: avaliar com lista
      // vazia produziria recomendação a partir de uma falha de rede.
      setState(() {
        _historico = null;
        _erro = FirestoreErro.mensagemAmigavel(erro);
        _carregando = false;
      });
    }
  }

  List<StatusVacinacao> _avaliar() {
    final historico = _historico!;
    final avaliadoEm = _avaliadoEm!;
    final dum = _dum!;

    return VacinasEngine.avaliar(
      diasGestacaoBruto: avaliadoEm.difference(dum).inDays,
      dum: dum,
      dataAtual: avaliadoEm,
      historico: historico,
      calendario: calendarioPni2026,
      temporadaInfluenza: null,
    );
  }

  String _nomeDaVacina(String codigo) =>
      regraPorCodigo(codigo)?.nomeExibicao ?? codigo;

  String _formatarData(DateTime d) {
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    return '$dia/$mes/${d.year}';
  }

  Widget _cardVacina(BuildContext context, StatusVacinacao status) {
    final apresentacao = apresentacaoDe(status.estado);
    final janela = status.proximaJanela;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: apresentacao.fundo(context),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              apresentacao.icone,
              size: 17,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _nomeDaVacina(status.vacinaCodigo),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: apresentacao.fundo(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        apresentacao.rotulo,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Texto clínico é sempre o da engine; a tela não redige nem
                // reescreve nenhuma orientação.
                Text(
                  status.mensagem,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                if (janela != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.event_outlined,
                          size: 11, color: AppColors.textMuted(context)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Semana ${janela.semanaGestacional} · '
                          'previsto para ${_formatarData(janela.dataEstimada)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _painelDeErro(BuildContext context, String mensagem) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 36, color: AppColors.textMuted(context)),
            const SizedBox(height: 14),
            Text(
              'Não foi possível carregar seus registros',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sem eles, o calendário não pode ser apresentado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _carregar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Tentar novamente',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    final erro = _erro;
    if (erro != null) return _painelDeErro(context, erro);

    // A ordem de saída da engine acompanha a ordem do calendário.
    final status = _avaliar();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        ...status.map((s) => _cardVacina(context, s)),
        const SizedBox(height: 6),
        Text(
          mensagemGeralVacinas,
          style: TextStyle(
            fontSize: 10,
            height: 1.45,
            color: AppColors.textMuted(context),
          ),
        ),
      ],
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
            border:
                Border.all(color: AppColors.borderStrong(context), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  border: Border(
                    bottom: BorderSide(
                        color: AppColors.border(context), width: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left_rounded,
                              color: AppColors.purpleLabel(context), size: 18),
                          const SizedBox(width: 4),
                          Text('Voltar',
                              style: TextStyle(
                                  color: AppColors.purpleLabel(context),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Vacinas da Gestação',
                        style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 20,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Text('Calendário e seus registros',
                        style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 12)),
                  ],
                ),
              ),
              Expanded(child: _conteudo(context)),
            ],
          ),
        ),
      ),
    );
  }
}
