import 'package:flutter/material.dart';
import '../services/ia_service.dart';

class AssistenteScreen extends StatefulWidget {
  const AssistenteScreen({super.key});

  @override
  State<AssistenteScreen> createState() => _AssistenteScreenState();
}

class _AssistenteScreenState extends State<AssistenteScreen> {
  final TextEditingController mensagemController = TextEditingController();
  final List<Map<String, String>> mensagens = [
    {
      'tipo': 'ia',
      'texto':
          'Olá! Sou sua assistente. Posso ajudar com dúvidas sobre contrações, trabalho de parto e sinais de atenção.',
      'hora': 'Agora',
    },
  ];

  @override
  void dispose() {
    mensagemController.dispose();
    super.dispose();
  }

  Future<void> enviarMensagem() async {
    final texto = mensagemController.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      mensagens.add({
        'tipo': 'usuario',
        'texto': texto,
        'hora': 'Agora',
      });
    });

    mensagemController.clear();

    final resposta = await IaService.perguntar(texto);

    setState(() {
      mensagens.add({
        'tipo': 'ia',
        'texto': resposta,
        'hora': 'Agora',
      });
    });
  }

  Widget bubbleIA(String texto, String hora) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: const BoxDecoration(
                color: Color(0xFFEEEDFE),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                texto,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF3C3489),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              hora,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFB4B2A9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget bubbleUsuario(String texto, String hora) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF534AB7), Color(0xFF7F77DD)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                texto,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              hora,
              style: const TextStyle(
                fontSize: 10,
                color: Color.fromRGBO(83, 74, 183, 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color.fromRGBO(0, 0, 0, 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: mensagemController,
              decoration: InputDecoration(
                hintText: 'Digite sua dúvida...',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888780),
                ),
                filled: true,
                fillColor: const Color(0xFFF7F5FF),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color.fromRGBO(83, 74, 183, 0.15),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color.fromRGBO(83, 74, 183, 0.15),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color(0xFF534AB7),
                  ),
                ),
              ),
              onSubmitted: (_) => enviarMensagem(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: enviarMensagem,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF534AB7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
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
                padding: const EdgeInsets.fromLTRB(20, 36, 20, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF534AB7), Color(0xFF7F77DD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color.fromRGBO(255, 255, 255, 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smart_toy_outlined,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assistente IA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 3,
                                backgroundColor: Color(0xFF5DCAA5),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Online',
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
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color.fromRGBO(255, 255, 255, 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  itemCount: mensagens.length,
                  itemBuilder: (context, index) {
                    final msg = mensagens[index];
                    if (msg['tipo'] == 'usuario') {
                      return bubbleUsuario(msg['texto']!, msg['hora']!);
                    }
                    return bubbleIA(msg['texto']!, msg['hora']!);
                  },
                ),
              ),
              inputBar(),
            ],
          ),
        ),
      ),
    );
  }
}