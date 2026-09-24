import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sessao.dart';
import '../services/auth_service.dart';
import '../services/consentimento_storage.dart';
import '../services/firestore_error.dart';
import '../services/links_publicos.dart';
import '../theme/app_theme.dart';
import '../widgets/moldura_responsiva.dart';
import 'conta_screen.dart';
import 'login_screen.dart';

const String consentimentoDados =
    'Para funcionar, o app guarda dados sobre a sua saúde: a data da última '
    'menstruação, contrações, movimentos do bebê, sintomas, humor, peso, '
    'consultas e vacinas.';

const String consentimentoFinalidade =
    'Eles servem para registrar o seu acompanhamento e mostrar os seus '
    'registros, inclusive quando você entra em outro aparelho.';

const String consentimentoArmazenamento =
    'Ficam no Cloud Firestore, serviço do Firebase (Google), na região de São '
    'Paulo. Nenhuma outra conta do aplicativo tem acesso a eles.';

const String consentimentoExclusao =
    'Você pode excluir a conta e todos esses dados quando quiser, na tela '
    'Conta do aplicativo.';

const String textoDoAceite =
    'Li a Política de Privacidade e autorizo o tratamento dos meus dados de '
    'saúde para essas finalidades.';

enum _Recusa { sair, excluir }

class ConsentimentoScreen extends StatefulWidget {
  const ConsentimentoScreen({
    super.key,
    required this.aoAceitar,
    this.registrarAceite = ConsentimentoStorage.registrarAceite,
  });

  final VoidCallback aoAceitar;
  final Future<bool> Function() registrarAceite;

  @override
  State<ConsentimentoScreen> createState() => _ConsentimentoScreenState();
}

class _ConsentimentoScreenState extends State<ConsentimentoScreen> {
  bool _aceito = false;
  bool _salvando = false;
  bool _saindo = false;
  String? _erro;

  bool get _ocupado => _salvando || _saindo;

  Future<void> _continuar() async {
    if (!_aceito || _ocupado) return;

    setState(() {
      _salvando = true;
      _erro = null;
    });

    var gravou = false;
    Object? falha;
    try {
      gravou = await widget.registrarAceite();
    } catch (erro) {
      falha = erro;
    }

    if (!mounted) return;

    if (!gravou) {
      setState(() {
        _salvando = false;
        _erro = falha != null
            ? FirestoreErro.mensagemAmigavel(falha)
            : AuthService.sessaoExpirada;
      });
      return;
    }

    setState(() => _salvando = false);
    widget.aoAceitar();
  }

  Future<void> _naoConcordo() async {
    if (_ocupado) return;

    final escolha = await showDialog<_Recusa>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: AppColors.surface(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sem autorização, o app não funciona',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(ctx),
            ),
          ),
          content: Text(
            'O Minha Gestação existe para registrar esses dados. Sem a sua '
            'autorização, ele não pode guardá-los nem mostrá-los. Você pode '
            'sair da conta e voltar quando quiser, ou excluir a conta e os '
            'dados já guardados.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary(ctx),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Voltar',
                style: TextStyle(color: AppColors.textPrimary(ctx)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _Recusa.sair),
              child: Text(
                'Sair da conta',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent(ctx),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _Recusa.excluir),
              child: Text(
                'Excluir minha conta',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.pink,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || escolha == null) return;

    switch (escolha) {
      case _Recusa.sair:
        await _sairDaConta();
      case _Recusa.excluir:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ContaScreen()));
    }
  }

  Future<void> _sairDaConta() async {
    if (_ocupado) return;

    setState(() {
      _saindo = true;
      _erro = null;
    });

    limparEstadoDaSessao();

    try {
      await AuthService.logout();
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _saindo = false;
        _erro = FirestoreErro.mensagemAmigavel(erro);
      });
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _abrirPolitica() async {
    final abriu = await LinksPublicos.abrir(
      LinksPublicos.politicaDePrivacidade,
    );
    if (abriu || !mounted) return;
    await _mostrarLinkDaPolitica();
  }

  Future<void> _mostrarLinkDaPolitica() {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: AppColors.surface(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Política de Privacidade',
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
                'Não foi possível abrir o navegador. Acesse o endereço abaixo:',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                LinksPublicos.politicaDePrivacidade,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary(ctx),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _copiarLinkDaPolitica(ctx),
              child: Text(
                'Copiar link',
                style: TextStyle(color: AppColors.textPrimary(ctx)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Fechar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent(ctx),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _copiarLinkDaPolitica(BuildContext dialogo) async {
    var copiou = true;
    try {
      await Clipboard.setData(
        const ClipboardData(text: LinksPublicos.politicaDePrivacidade),
      );
    } catch (_) {
      copiou = false;
    }

    if (dialogo.mounted) Navigator.pop(dialogo);
    if (!copiou || !mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copiado.')));
  }

  Widget _cabecalho(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(context),
        border: Border(
          bottom: BorderSide(color: AppColors.border(context), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seus dados de saúde',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Antes de começar, precisamos da sua autorização',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icone,
    String titulo,
    String texto,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.statPurple(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, size: 17, color: AppColors.accent(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkDaPolitica(BuildContext context) {
    return Semantics(
      link: true,
      child: InkWell(
        onTap: _ocupado ? null : _abrirPolitica,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                size: 18,
                color: AppColors.purpleLabel(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ler a Política de Privacidade',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent(context),
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: AppColors.textMuted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _caixaDeAceite(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _aceito ? AppColors.accent(context) : AppColors.border(context),
          width: _aceito ? 1 : 0.5,
        ),
      ),
      child: CheckboxListTile(
        value: _aceito,
        onChanged: _ocupado
            ? null
            : (valor) => setState(() {
                _aceito = valor ?? false;
                _erro = null;
              }),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.accent(context),
        checkColor: AppColors.surface(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          textoDoAceite,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _botaoContinuar(BuildContext context) {
    final habilitado = _aceito && !_ocupado;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: habilitado ? _continuar : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryPurple,
          disabledBackgroundColor: AppColors.statPurple(context),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _salvando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Continuar',
                style: TextStyle(
                  color: habilitado ? Colors.white : AppColors.textMuted(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _botaoNaoConcordo(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _ocupado ? null : _naoConcordo,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: _saindo
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: AppColors.textSecondary(context),
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Não concordo',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 13,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: MolduraResponsiva(
        child: Column(
          children: [
            _cabecalho(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                children: [
                  _item(
                    context,
                    Icons.favorite_border_rounded,
                    'O que é guardado',
                    consentimentoDados,
                  ),
                  _item(
                    context,
                    Icons.event_note_outlined,
                    'Para quê',
                    consentimentoFinalidade,
                  ),
                  _item(
                    context,
                    Icons.cloud_outlined,
                    'Onde fica',
                    consentimentoArmazenamento,
                  ),
                  _item(
                    context,
                    Icons.delete_outline_rounded,
                    'Como excluir',
                    consentimentoExclusao,
                  ),
                  _linkDaPolitica(context),
                  const SizedBox(height: 12),
                  _caixaDeAceite(context),
                  const SizedBox(height: 16),
                  if (_erro != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.statPink(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _erro!,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  _botaoContinuar(context),
                  const SizedBox(height: 6),
                  _botaoNaoConcordo(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
