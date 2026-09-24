import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sessao.dart';
import '../services/auth_service.dart';
import '../services/exclusao_de_conta.dart';
import '../services/firestore_error.dart';
import '../services/links_publicos.dart';
import '../theme/app_theme.dart';
import '../widgets/moldura_responsiva.dart';
import 'login_screen.dart';

class ContaScreen extends StatefulWidget {
  const ContaScreen({super.key});

  @override
  State<ContaScreen> createState() => _ContaScreenState();
}

class _ContaScreenState extends State<ContaScreen> {
  bool _saindo = false;
  bool _excluindo = false;
  String? _erro;
  String? _email;

  bool get _ocupado => _saindo || _excluindo;

  final TextEditingController _senha = TextEditingController();

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    try {
      _email = AuthService.usuarioAtual?.email;
    } catch (_) {
      _email = null;
    }
  }

  Future<bool> _confirmarSaida(BuildContext context) async {
    final resposta = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sair da conta?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(ctx),
            ),
          ),
          content: Text(
            'Seus registros continuam salvos e voltam quando você entrar '
            'de novo neste ou em outro aparelho.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary(ctx),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textPrimary(ctx)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Sair',
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

    return resposta == true;
  }

  Future<void> _sairDaConta() async {
    if (_ocupado) return;

    final confirmado = await _confirmarSaida(context);
    if (!confirmado || !mounted) return;

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

  Future<bool> _confirmarExclusao(BuildContext context) async {
    final resposta = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: AppColors.surface(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Excluir minha conta?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(ctx),
            ),
          ),
          content: Text(
            'Isto apaga de vez suas contrações, seus chutes, seus sintomas, '
            'humor e peso, suas consultas, suas vacinas, a data da última '
            'menstruação e o seu login. A exclusão é permanente: não há como '
            'desfazer nem recuperar depois. Na próxima etapa, você vai '
            'confirmar sua senha.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary(ctx),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textPrimary(ctx)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Excluir',
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

    return resposta == true;
  }

  Future<String?> _pedirSenha(BuildContext context) async {
    _senha.clear();

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: AppColors.surface(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Confirme sua senha',
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
                'Digite a senha da sua conta para confirmar que é você.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _senha,
                obscureText: true,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (valor) => Navigator.pop(ctx, valor),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary(ctx),
                ),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted(ctx),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textPrimary(ctx)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _senha.text),
              child: Text(
                'Excluir conta',
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
  }

  Future<void> _excluirConta() async {
    if (_ocupado) return;

    final confirmado = await _confirmarExclusao(context);
    if (!confirmado || !mounted) return;

    final senha = await _pedirSenha(context);
    if (senha == null || !mounted) return;

    if (senha.isEmpty) {
      setState(() => _erro = 'Digite sua senha para confirmar a exclusão.');
      return;
    }

    setState(() {
      _excluindo = true;
      _erro = null;
    });

    ResultadoDaExclusao resultado;
    try {
      resultado = await ExclusaoDeConta.executar(senha: senha);
    } catch (erro) {
      resultado = ResultadoDaExclusao.falha(
        FirestoreErro.mensagemAmigavel(erro),
      );
    }

    if (!mounted) return;

    _senha.clear();

    if (!resultado.sucesso) {
      setState(() {
        _excluindo = false;
        _erro = resultado.erro;
      });
      return;
    }

    limparEstadoDaSessao();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _cabecalho(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(context),
        border: Border(
          bottom: BorderSide(color: AppColors.border(context), width: 0.5),
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
            'Conta',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Sessão neste aparelho',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoDoEmail(BuildContext context) {
    final email = _email;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'E-MAIL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textMuted(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email == null || email.isEmpty ? 'Não disponível' : email,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botaoSair(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _ocupado ? null : _sairDaConta,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryPurple,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _saindo
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Sair da conta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
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
                  color: AppTheme.primaryPurple,
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

  Widget _linkDaPolitica(BuildContext context) {
    return Semantics(
      link: true,
      child: InkWell(
        onTap: _abrirPolitica,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
                  'Política de Privacidade',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary(context),
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

  Widget _botaoExcluir(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _ocupado ? null : _excluirConta,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.pink, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _excluindo
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: AppTheme.pink,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Excluir minha conta',
                style: TextStyle(
                  color: AppTheme.pink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _cartaoDoEmail(context),
                    const SizedBox(height: 20),
                    if (_erro != null) ...[
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
                    ],
                    _botaoSair(context),
                    const SizedBox(height: 8),
                    Text(
                      'Sair não apaga nada: seus dados ficam guardados na '
                      'sua conta.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Divider(
                      color: AppColors.border(context),
                      height: 1,
                      thickness: 0.5,
                    ),
                    const SizedBox(height: 20),
                    _botaoExcluir(context),
                    const SizedBox(height: 8),
                    Text(
                      'Excluir apaga de vez seus registros e o seu login. '
                      'É permanente e não dá para desfazer.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Divider(
                      color: AppColors.border(context),
                      height: 1,
                      thickness: 0.5,
                    ),
                    const SizedBox(height: 8),
                    _linkDaPolitica(context),
                  ],
                ),
              ),
            ],
        ),
      ),
    );
  }
}
