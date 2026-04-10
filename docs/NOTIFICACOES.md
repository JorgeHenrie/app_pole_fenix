# Notificacoes automaticas

## Implementado nesta branch

- Persistencia de notificacoes em Firestore na colecao notificacoes.
- Registro de tokens FCM por usuaria em usuarios.fcmTokens.
- Tela unica de notificacoes para aluna e admin, com badge de nao lidas.
- Aviso para admin quando uma nova aluna solicitar cadastro.
- Alerta para admin quando a aluna cancela uma aula com menos de 2 horas.
- Lembrete automatico no dia da aula.
- Lembretes de renovacao do plano com 3 dias de antecedencia e no ultimo dia.
- Aviso para a aluna quando o horario fixo e removido pela administracao.
- Aviso para a aluna quando o cadastro e aprovado ou rejeitado.
- Aviso para a aluna quando o atestado e aprovado ou rejeitado.

## Gatilhos ja mapeados para proxima etapa

- Reposicao prestes a expirar.
- Creditos baixos no plano.
- Lembrete de evento publicado na vespera.
- Aviso quando uma vaga abrir em turma antes lotada.
- Confirmacao e pendencia de pagamento.

## Estrutura usada

- App: Provider + Firebase Messaging + stream da colecao notificacoes.
- Backend: Cloud Functions para disparo push e persistencia da notificacao in-app.
- Dedupe: campos auxiliares em aulas e assinaturas para evitar reenvio de lembretes agendados.