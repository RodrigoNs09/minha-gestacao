import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Estrutura externa das telas: o cartão branco arredondado sobre o fundo
/// da aplicação.
///
/// Substitui o molde antigo `Center > Container(width: 300|360, minHeight:
/// 620|760)`, que prendia o conteúdo a uma moldura de "celular": não usava a
/// largura disponível, não cabia em paisagem e, com o `Clip.antiAlias`,
/// cortava em silêncio o que sobrasse.
///
/// Aqui a largura vem das constraints — o cartão ocupa o que há, até um teto
/// — e a altura é livre. É o mesmo arranjo já validado em aparelho real
/// (Motorola G10) na Agenda e na Login: 387,43 dp de cartão em retrato numa
/// tela de 411,43 dp, e 400 dp de teto em telas largas.
///
/// Cuida apenas da moldura. O conteúdo — cabeçalho, rolagem, restrições de
/// texto — é responsabilidade de cada tela.
class MolduraResponsiva extends StatelessWidget {
  const MolduraResponsiva({super.key, required this.child, this.maxWidth = 400});

  /// O conteúdo do cartão, normalmente a `Column` da tela.
  final Widget child;

  /// Largura máxima do cartão. O padrão de 400 evita que o conteúdo estique
  /// em telas largas; abaixo disso vale a largura disponível.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: AppColors.borderStrong(context),
                  width: 0.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
