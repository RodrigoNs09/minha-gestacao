# AI Context — Minha Gestação

## Regra principal
O código, configurações e documentação atual do repositório são a fonte de verdade. O README pode estar desatualizado e não deve ser usado para inferir o estado atual do projeto.

## Objetivo do projeto
Aplicativo Flutter de acompanhamento da gestação, com foco em gestantes e acompanhantes, incluindo monitoramento de contrações e funcionalidades de acompanhamento ao longo da gravidez.

## Stack observada no repositório
- Flutter / Dart
- flutter_localizations (pt-BR)
- Firebase Core
- Firebase Authentication
- Cloud Firestore
- Firebase Hosting (site público em `public/`)

## Estrutura funcional observada
- Autenticação: login, cadastro e recuperação de senha
- Onboarding/configuração da gestação
- Registro e histórico de contrações
- Contador e histórico de chutes
- Diário de sintomas
- Agenda de consultas/exames
- Vacinação e histórico de vacinação
- Conta/sessão
- Tema claro/escuro

## Evidências de implementação atuais
- `lib/main.dart` inicializa Firebase e, sem sessão, mostra o login; com sessão, entrega a navegação à `PortaDeEntrada` (`lib/screens/porta_de_entrada.dart`), que também é usada pelo login e pelo cadastro. Ela decide o destino com `ProximoDestino.calcular()`: sem o consentimento vigente para dados de saúde, abre a tela de consentimento; com ele, segue para o Onboarding ou para a Home.
- `lib/services/auth_service.dart` implementa cadastro, login, recuperação de senha e logout com Firebase Authentication.
- `lib/services/gestacao_storage.dart` persiste dados da gestação no Cloud Firestore por usuário autenticado.
- Existem serviços e telas adicionais para vacinação, sintomas, consultas, chutes e conta.

## Regras para agentes
1. Não confiar em documentação antiga quando houver conflito com o código.
2. Antes de alterar arquitetura, localizar as dependências reais e os fluxos existentes.
3. Não remover funcionalidade existente para simplificar uma tarefa sem registrar a decisão.
4. Toda mudança funcional deve preservar compilação e, quando aplicável, adicionar/atualizar testes.
5. Alterações relacionadas à saúde devem evitar linguagem de diagnóstico ou orientação clínica indevida e devem preservar mecanismos de alerta/triagem definidos pelo projeto.
6. Documentação deve descrever o comportamento realmente implementado, não o comportamento planejado.
7. Não adicionar credenciais, chaves privadas, tokens ou segredos ao repositório.
8. Em caso de incerteza técnica, registrar a hipótese e verificar no código antes de decidir.

## Forma de trabalho
- ChatGPT: arquitetura, priorização, revisão técnica, requisitos, documentação acadêmica e auditoria.
- Claude Code: execução no ambiente local, implementação, testes, refactors e commits/PRs.
- GitHub: fonte compartilhada de código, histórico, issues, PRs e documentação operacional.

## Não alterar sem validação
- Requisitos acadêmicos definidos pelo orientador.
- Escopo clínico do produto.
- Decisões de arquitetura que afetem persistência, autenticação ou segurança sem revisão.
