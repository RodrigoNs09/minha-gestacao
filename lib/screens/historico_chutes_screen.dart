import 'package:flutter/material.dart';
import '../models/chute_sessao.dart';
import '../services/chutes_storage.dart';
import '../services/firestore_error.dart';
import '../theme/app_theme.dart';

/// Duração da sessão a partir de horaInicio/horaFim (strings "HH:mm").
///
/// Função pura, testável isoladamente — [ChuteSessao] não guarda a duração
/// como campo, então ela é derivada aqui, no mesmo espírito de outras
/// derivações em memória já usadas no projeto (ex: os cálculos de intervalo
/// em HistoricoScreen).
///
/// Retorna `null` quando os horários não são interpretáveis, ou quando o
/// fim aparenta ser anterior ao início — sessões de chutes não cruzam a
/// meia-noite, então isso indica dado malformado, não duração negativa.
Duration? duracaoDaSessao(ChuteSessao sessao) {
  final inicio = _minutosDoDia(sessao.horaInicio);
  final fim = _minutosDoDia(sessao.horaFim);
  if (inicio == null || fim == null) return null;

  final diferenca = fim - inicio;
  if (diferenca < 0) return null;
  return Duration(minutes: diferenca);
}

int? _minutosDoDia(String horaHHmm) {
  final partes = horaHHmm.split(':');
  if (partes.length != 2) return null;
  final h = int.tryParse(partes[0]);
  final m = int.tryParse(partes[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

class HistoricoChutesScreen extends StatefulWidget {
  const HistoricoChutesScreen({super.key});

  @override
  State<HistoricoChutesScreen> createState() => _HistoricoChutesScreenState();
}

class _HistoricoChutesScreenState extends State<HistoricoChutesScreen> {
  List<ChuteSessao> _sessoes = [];
  bool _carregando = true;

  static const _meses = [
    'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
    'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'
  ];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dados = await ChutesStorage.carregarSessoes();
      if (!mounted) return;
      setState(() {
        _sessoes = dados;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FirestoreErro.mensagemAmigavel(erro))),
      );
    }
  }

  DateTime? _parseData(String data) {
    final partes = data.split('-');
    if (partes.length != 3) return null;
    final ano = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final dia = int.tryParse(partes[2]);
    if (ano == null || mes == null || dia == null) return null;
    return DateTime(ano, mes, dia);
  }

  /// Sessões agrupadas por dia, mais recentes primeiro; dentro de cada dia,
  /// horário de início mais recente primeiro. Mesmo padrão de
  /// HistoricoScreen.gruposPorDia.
  List<MapEntry<String, List<ChuteSessao>>> get _gruposPorDia {
    final Map<String, List<ChuteSessao>> grupos = {};
    for (final s in _sessoes) {
      grupos.putIfAbsent(s.data, () => []).add(s);
    }

    for (final lista in grupos.values) {
      lista.sort((a, b) => b.horaInicio.compareTo(a.horaInicio));
    }

    final entradas = grupos.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return entradas;
  }

  String _rotuloDia(String data) {
    final d = _parseData(data);
    if (d == null) return data;
    final hoje = DateTime.now();
    final hojeData = DateTime(hoje.year, hoje.month, hoje.day);

    if (d == hojeData) return 'HOJE — ${d.day} ${_meses[d.month - 1]}';
    if (d == hojeData.subtract(const Duration(days: 1))) {
      return 'ONTEM — ${d.day} ${_meses[d.month - 1]}';
    }
    return '${d.day} ${_meses[d.month - 1]}';
  }

  String _formatarDuracao(Duration d) {
    final totalMinutos = d.inMinutes;
    if (totalMinutos < 60) return '${totalMinutos}min';
    final horas = totalMinutos ~/ 60;
    final minutos = totalMinutos % 60;
    if (minutos == 0) return '${horas}h';
    return '${horas}h${minutos}min';
  }

  Widget _linhaSessao(BuildContext context, ChuteSessao s) {
    final duracao = duracaoDaSessao(s);
    final corStatus = s.completa ? const Color(0xFF1D9E75) : const Color(0xFFEF9F27);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: corStatus, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.horaInicio} – ${s.horaFim}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context))),
                const SizedBox(height: 1),
                Text(
                  duracao != null
                      ? '${s.totalChutes} chutes · ${_formatarDuracao(duracao)}'
                      : '${s.totalChutes} chutes',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: s.completa ? AppColors.statGreen(context) : AppColors.statOrange(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              s.completa ? 'Completa' : 'Incompleta',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: s.completa ? const Color(0xFF085041) : const Color(0xFF633806),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _gruposPorDia;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Center(
        child: Container(
          width: 300,
          constraints: const BoxConstraints(minHeight: 620),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: AppColors.borderStrong(context), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  border: Border(bottom: BorderSide(color: AppColors.border(context), width: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left_rounded, color: AppColors.purpleLabel(context), size: 18),
                          const SizedBox(width: 4),
                          Text('Voltar', style: TextStyle(color: AppColors.purpleLabel(context), fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Histórico de Chutes',
                        style: TextStyle(color: AppColors.textPrimary(context), fontSize: 20, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Text('Sessões registradas',
                        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: _carregando
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        children: [
                          if (grupos.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border(context), width: 0.5),
                              ),
                              child: Text('Nenhuma sessão registrada.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                            )
                          else
                            ...grupos.expand((grupo) {
                              return [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                                  child: Text(
                                    _rotuloDia(grupo.key),
                                    style: TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.textMuted(context)),
                                  ),
                                ),
                                ...grupo.value.map((s) => _linhaSessao(context, s)),
                                const SizedBox(height: 6),
                              ];
                            }),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
