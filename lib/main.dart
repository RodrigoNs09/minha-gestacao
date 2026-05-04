import 'package:flutter/material.dart';
import 'screens/contracao_screen.dart';
import 'screens/historico_screen.dart';
import 'screens/analise_screen.dart';
import 'screens/assistente_screen.dart';
import 'screens/modo_acompanhante_screen.dart';
import 'data/contracoes_data.dart';
import 'services/contracoes_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  listaContracoes = await ContracoesStorage.carregarContracoes();
  runApp(const SuaContracaoApp());
}

class SuaContracaoApp extends StatelessWidget {
  const SuaContracaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sua Contração',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF0EEFF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF534AB7),
          brightness: Brightness.light,
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void abrirTela(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  int get totalHoje => listaContracoes.length;

  String get ultimaDuracao {
    if (listaContracoes.isEmpty) return '—';
    final obs = listaContracoes.last.observacoes;
    final match = RegExp(r'Duração:\s*([0-9]{2}:[0-9]{2})').firstMatch(obs);
    return match?.group(1) ?? '—';
  }

  String get intervaloMedio {
    if (listaContracoes.length < 2) return '—';

    final horarios = listaContracoes.map((c) {
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

  Widget statCard({
    required String valor,
    required String label,
    required Color bg,
    required Color valorCor,
    required Color labelCor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: valorCor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: labelCor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget menuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget screen,
    required Color iconBg,
    required Color iconColor,
    String? badge,
    Color? badgeBg,
    Color? badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => abrirTela(context, screen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color.fromRGBO(0, 0, 0, 0.07),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF26215C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF888780),
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg ?? const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: badgeColor ?? const Color(0xFF0F6E56),
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFFB4B2A9),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget bigActionButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => abrirTela(context, const ContracaoScreen()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF534AB7), Color(0xFF7F77DD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrar Contração',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Toque para iniciar o monitoramento',
                  style: TextStyle(
                    color: Color.fromRGBO(255, 255, 255, 0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget bottomNav(BuildContext context) {
    Widget navItem({
      required IconData icon,
      required bool active,
      VoidCallback? onTap,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFF534AB7) : const Color(0xFF888780),
              size: 20,
            ),
            const SizedBox(height: 3),
            if (active)
              const CircleAvatar(
                radius: 2,
                backgroundColor: Color(0xFF534AB7),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      );
    }

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          navItem(
            icon: Icons.home_rounded,
            active: true,
          ),
          navItem(
            icon: Icons.access_time_rounded,
            active: false,
            onTap: () => abrirTela(context, const ContracaoScreen()),
          ),
          navItem(
            icon: Icons.auto_graph_rounded,
            active: false,
            onTap: () => abrirTela(context, const AnaliseScreen()),
          ),
          navItem(
            icon: Icons.chat_bubble_outline_rounded,
            active: false,
            onTap: () => abrirTela(context, const AssistenteScreen()),
          ),
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
          width: 360,
          constraints: const BoxConstraints(minHeight: 760),
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
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
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
                  children: [
                    Row(
                      children: [
                        Row(
                          children: const [
                            CircleAvatar(
                              radius: 5,
                              backgroundColor: Color(0xFFD4537E),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Sua Contração',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF3C3489),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEEEDFE), Color(0xFFFBEAF0)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color.fromRGBO(83, 74, 183, 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                            color: Color(0xFF534AB7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Olá, mamãe 👋',
                        style: TextStyle(
                          color: Color(0xFF26215C),
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Seu apoio inteligente para entender contrações',
                        style: TextStyle(
                          color: Color(0xFF888780),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        statCard(
                          valor: '$totalHoje',
                          label: 'Hoje',
                          bg: const Color(0xFFEEEDFE),
                          valorCor: const Color(0xFF3C3489),
                          labelCor: const Color(0xFF7F77DD),
                        ),
                        const SizedBox(width: 10),
                        statCard(
                          valor: intervaloMedio,
                          label: 'Intervalo',
                          bg: const Color(0xFFE1F5EE),
                          valorCor: const Color(0xFF085041),
                          labelCor: const Color(0xFF1D9E75),
                        ),
                        const SizedBox(width: 10),
                        statCard(
                          valor: ultimaDuracao,
                          label: 'Última',
                          bg: const Color(0xFFFBEAF0),
                          valorCor: const Color(0xFF72243E),
                          labelCor: const Color(0xFFD4537E),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'AÇÃO PRINCIPAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                          color: Color(0xFFB4B2A9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    bigActionButton(context),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'EXPLORAR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                          color: Color(0xFFB4B2A9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    menuCard(
                      context: context,
                      icon: Icons.description_outlined,
                      title: 'Histórico de Contrações',
                      subtitle: 'Acompanhe os registros',
                      screen: const HistoricoScreen(),
                      iconBg: const Color(0xFFEEEDFE),
                      iconColor: const Color(0xFF534AB7),
                    ),
                    menuCard(
                      context: context,
                      icon: Icons.auto_graph_rounded,
                      title: 'Análise Inteligente',
                      subtitle: 'Padrões e insights com IA',
                      screen: const AnaliseScreen(),
                      iconBg: const Color(0xFFFBEAF0),
                      iconColor: const Color(0xFF993556),
                    ),
                    menuCard(
                      context: context,
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Assistente de Dúvidas',
                      subtitle: 'Tire dúvidas com apoio de IA',
                      screen: const AssistenteScreen(),
                      iconBg: const Color(0xFFFAEEDA),
                      iconColor: const Color(0xFF854F0B),
                    ),
                    menuCard(
                      context: context,
                      icon: Icons.group_outlined,
                      title: 'Modo Acompanhante',
                      subtitle: 'Compartilhe com quem você ama',
                      screen: const ModoAcompanhanteScreen(),
                      iconBg: const Color(0xFFE1F5EE),
                      iconColor: const Color(0xFF0F6E56),
                      badge: 'NOVO',
                      badgeBg: const Color(0xFFE1F5EE),
                      badgeColor: const Color(0xFF0F6E56),
                    ),
                  ],
                ),
              ),
              bottomNav(context),
            ],
          ),
        ),
      ),
    );
  }
}