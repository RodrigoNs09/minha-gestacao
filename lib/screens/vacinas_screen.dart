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

  DateTime? _avaliadoEm;
  DateTime? _dum;

  String? _idPendente;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _abrirNovaAvaliacao() {
    _avaliadoEm = DateTime.now();
    _dum = gestacaoAtual.dum;
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final registros = await VacinasStorage.carregarRegistros();
      if (!mounted) return;

      setState(() {
        _historico = registros;
        _abrirNovaAvaliacao();
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
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
      temporadaInfluenza: temporadaInfluenzaPni2026,
    );
  }

  String _nomeDaVacina(String codigo) =>
      regraPorCodigo(codigo)?.nomeExibicao ?? codigo;

  String _formatarData(DateTime d) {
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    return '$dia/$mes/${d.year}';
  }

  String _rotuloDaSituacao(SituacaoInformada situacao) {
    switch (situacao) {
      case SituacaoInformada.aplicadaComData:
        return 'Aplicada com data';
      case SituacaoInformada.aplicadaDataDesconhecida:
        return 'Aplicada, mas não sei a data';
      case SituacaoInformada.naoAplicadaInformado:
        return 'Não aplicada';
      case SituacaoInformada.situacaoDesconhecida:
        return 'Não sei informar';
    }
  }

  bool _declaraAplicacao(SituacaoInformada? situacao) =>
      situacao == SituacaoInformada.aplicadaComData ||
      situacao == SituacaoInformada.aplicadaDataDesconhecida;

  List<RegistroVacinacao> _registrosDaVacina(String codigo) {
    final historico = _historico;
    if (historico == null) return const [];

    return historico
        .where((r) => r.vacinaCodigo == codigo && r.id != null)
        .toList(growable: false);
  }

  String _resumoDoRegistro(RegistroVacinacao registro) {
    final partes = <String>[_rotuloDaSituacao(registro.situacaoInformada)];

    final data = registro.dataAplicacao;
    if (data != null) partes.add(_formatarData(data));

    final numero = registro.numeroDaDose;
    if (numero != null) partes.add('dose $numero');

    return partes.join(' · ');
  }

  Future<void> _excluirRegistro(
    BuildContext context,
    RegistroVacinacao registro,
  ) async {
    // Sem id não há documento a remover: a ação não segue.
    final id = registro.id;
    if (id == null) return;

    bool excluindo = false;
    String? erroDaExclusao;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> confirmar() async {
              if (excluindo) return;

              setDialogState(() {
                excluindo = true;
                erroDaExclusao = null;
              });

              bool? removeu;
              Object? falha;
              try {
                removeu = await VacinasStorage.remover(id);
              } catch (erro) {
                falha = erro;
              }

              if (!ctx.mounted) return;

              if (removeu == true) {
                Navigator.pop(ctx, true);
                return;
              }

              // Falha ou recusa: nada sai da lista e o diálogo continua
              // aberto para uma nova tentativa.
              setDialogState(() {
                excluindo = false;
                erroDaExclusao = falha != null
                    ? FirestoreErro.mensagemAmigavel(falha)
                    : 'Não foi possível excluir: sessão expirada. Entre novamente.';
              });
            }

            return PopScope(
              canPop: !excluindo,
              child: AlertDialog(
                backgroundColor: AppColors.surface(ctx),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  'Excluir registro?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(ctx),
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Esse registro será removido do seu histórico de '
                      'vacinação.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary(ctx),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _resumoDoRegistro(registro),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted(ctx),
                      ),
                    ),
                    if (erroDaExclusao != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        erroDaExclusao!,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: AppColors.textSecondary(ctx),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: excluindo
                        ? null
                        : () => Navigator.pop(ctx, false),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: AppColors.textPrimary(ctx)),
                    ),
                  ),
                  TextButton(
                    onPressed: excluindo ? null : confirmar,
                    child: excluindo
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Excluir',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.pink,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || confirmado != true) return;

    setState(() {
      // Só o documento confirmado pelo storage sai da lista.
      _historico = [...?_historico]..removeWhere((r) => r.id == id);
      _abrirNovaAvaliacao();
    });
  }

  Future<void> _abrirFormulario(
    BuildContext context,
    String vacinaCodigo, {
    RegistroVacinacao? edicaoDe,
  }) async {
    final pedeNumeroDaDose =
        regraPorCodigo(vacinaCodigo) is RegraDependeHistorico;

    // A temporada só existe para regras avaliadas por temporada, e o valor
    // vem declarado pelo calendário — nunca da data da aplicação.
    final temporadaDeNovoRegistro =
        regraPorCodigo(vacinaCodigo) is RegraDependeTemporada
        ? temporadaInfluenzaPni2026
        : null;

    // Edição escreve no documento que já existe; só um cadastro novo gera id.
    _idPendente = edicaoDe?.id ?? VacinasStorage.novoId();

    SituacaoInformada? situacao = edicaoDe?.situacaoInformada;
    DateTime? dataAplicacao = edicaoDe?.dataAplicacao;
    int? numeroDaDose = edicaoDe?.numeroDaDose;
    bool salvando = false;
    String? erroDoSalvamento;

    final salvo = await showModalBottomSheet<RegistroVacinacao>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final mostraNumero =
                pedeNumeroDaDose && _declaraAplicacao(situacao);

            final podeSalvar =
                situacao != null &&
                (situacao != SituacaoInformada.aplicadaComData ||
                    dataAplicacao != null);

            Future<void> escolherData() async {
              final hoje = DateTime.now();
              final escolhida = await showDatePicker(
                context: ctx,
                initialDate: dataAplicacao ?? hoje,
                firstDate: DateTime(hoje.year - 60),
                lastDate: hoje,
                locale: const Locale('pt', 'BR'),
                helpText: 'Data da aplicação',
                cancelText: 'Cancelar',
                confirmText: 'OK',
              );
              if (escolhida != null) {
                setModalState(() => dataAplicacao = escolhida);
              }
            }

            Future<void> salvar() async {
              if (salvando || !podeSalvar) return;

              setModalState(() {
                salvando = true;
                erroDoSalvamento = null;
              });

              final registro = RegistroVacinacao(
                id: _idPendente,
                vacinaCodigo: vacinaCodigo,
                situacaoInformada: situacao!,
                versaoCalendario:
                    edicaoDe?.versaoCalendario ?? versaoCalendarioPni2026,
                origemRegistro:
                    edicaoDe?.origemRegistro ??
                    OrigemRegistro.registradoPelaUsuaria,
                dataAplicacao: situacao == SituacaoInformada.aplicadaComData
                    ? dataAplicacao
                    : null,
                numeroDaDose: mostraNumero ? numeroDaDose : null,
                dumNoRegistro: edicaoDe?.dumNoRegistro ?? gestacaoAtual.dum,
                temporadaNoRegistro: edicaoDe != null
                    ? edicaoDe.temporadaNoRegistro
                    : temporadaDeNovoRegistro,
                criadoEm: edicaoDe?.criadoEm ?? DateTime.now(),
                observacao: edicaoDe?.observacao,
              );

              RegistroVacinacao? gravado;
              Object? falha;
              try {
                gravado = await VacinasStorage.adicionar(registro);
              } catch (erro) {
                falha = erro;
              }

              if (!ctx.mounted) return;

              if (gravado != null) {
                Navigator.pop(ctx, gravado);
                return;
              }

              setModalState(() {
                salvando = false;
                erroDoSalvamento = falha != null
                    ? FirestoreErro.mensagemAmigavel(falha)
                    : 'Não foi possível salvar: sessão expirada. Entre novamente.';
              });
            }

            return PopScope(
              canPop: !salvando,
              child: Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface(ctx),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      edicaoDe == null
                          ? 'Registrar vacinação'
                          : 'Editar registro',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(ctx),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _nomeDaVacina(vacinaCodigo),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(ctx),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Situação da vacinação',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: AppColors.textMuted(ctx),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...SituacaoInformada.values.map((opcao) {
                      final marcada = situacao == opcao;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: salvando
                              ? null
                              : () => setModalState(() {
                                  situacao = opcao;
                                  if (opcao !=
                                      SituacaoInformada.aplicadaComData) {
                                    dataAplicacao = null;
                                  }
                                  if (!_declaraAplicacao(opcao)) {
                                    numeroDaDose = null;
                                  }
                                }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: marcada
                                  ? AppColors.statPurple(ctx)
                                  : AppColors.surfaceVariant(ctx),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: marcada
                                    ? AppColors.accent(ctx)
                                    : AppColors.border(ctx),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  marcada
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: marcada
                                      ? AppColors.accent(ctx)
                                      : AppColors.textMuted(ctx),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _rotuloDaSituacao(opcao),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textPrimary(ctx),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (situacao == SituacaoInformada.aplicadaComData) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Data da aplicação',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: AppColors.textMuted(ctx),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: salvando ? null : escolherData,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant(ctx),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border(ctx),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: AppColors.accent(ctx),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                dataAplicacao == null
                                    ? 'Escolher data'
                                    : _formatarData(dataAplicacao!),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: dataAplicacao == null
                                      ? AppColors.textSecondary(ctx)
                                      : AppColors.textPrimary(ctx),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (mostraNumero) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Número da dose',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: AppColors.textMuted(ctx),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final numero in [1, 2, 3])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: salvando
                                    ? null
                                    : () => setModalState(() {
                                        numeroDaDose = numeroDaDose == numero
                                            ? null
                                            : numero;
                                      }),
                                child: Container(
                                  width: 44,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: numeroDaDose == numero
                                        ? AppColors.statPurple(ctx)
                                        : AppColors.surfaceVariant(ctx),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: numeroDaDose == numero
                                          ? AppColors.accent(ctx)
                                          : AppColors.border(ctx),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    '$numero',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary(ctx),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Deixe em branco se não souber.',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted(ctx),
                        ),
                      ),
                    ],
                    if (erroDoSalvamento != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 14,
                            color: AppColors.textMuted(ctx),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              erroDoSalvamento!,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                color: AppColors.textSecondary(ctx),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: salvando
                                ? null
                                : () => Navigator.pop(ctx, null),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: AppColors.border(ctx)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                color: AppColors.textPrimary(ctx),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (salvando || !podeSalvar)
                                ? null
                                : salvar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: salvando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Salvar',
                                    style: TextStyle(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    setState(() {
      if (salvo != null) {
        final lista = [...?_historico];
        final indice = lista.indexWhere((r) => r.id == salvo.id);
        // Mesmo id: substitui no lugar. Id novo: entra no fim da lista.
        if (indice >= 0) {
          lista[indice] = salvo;
        } else {
          lista.add(salvo);
        }
        _historico = lista;
        _abrirNovaAvaliacao();
      }
      _idPendente = null;
    });
  }

  Widget _cardVacina(BuildContext context, StatusVacinacao status) {
    final apresentacao = apresentacaoDe(status.estado);
    final janela = status.proximaJanela;
    // A associação é pelo código da vacina do próprio card.
    final registros = _registrosDaVacina(status.vacinaCodigo);

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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
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
                      Icon(
                        Icons.event_outlined,
                        size: 11,
                        color: AppColors.textMuted(context),
                      ),
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

                if (registros.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...registros.map(
                    (registro) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _resumoDoRegistro(registro),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _abrirFormulario(
                              context,
                              registro.vacinaCodigo,
                              edicaoDe: registro,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                'Editar',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.purpleLabel(context),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _excluirRegistro(context, registro),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 15,
                                color: AppColors.textMuted(context),
                                semanticLabel: 'Excluir',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (status.podeRegistrar) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _abrirFormulario(context, status.vacinaCodigo),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: AppColors.purpleLabel(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Registrar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.purpleLabel(context),
                            ),
                          ),
                        ],
                      ),
                    ),
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
            Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: AppColors.textMuted(context),
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Tentar novamente',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
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
            border: Border.all(
              color: AppColors.borderStrong(context),
              width: 0.5,
            ),
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
                      color: AppColors.border(context),
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
                        children: [
                          Icon(
                            Icons.chevron_left_rounded,
                            color: AppColors.purpleLabel(context),
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Voltar',
                            style: TextStyle(
                              color: AppColors.purpleLabel(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Vacinas da Gestação',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Calendário e seus registros',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
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
