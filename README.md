# 🎪 Fênix Pole Dance - Sistema de Agendamento

Sistema mobile para automatização de agendamento de aulas de pole dance, desenvolvido em Flutter.

## 📋 Sobre o Projeto

O **Fênix Pole Dance App** substitui o processo manual de agendamento via WhatsApp por uma solução completa que permite:

- ✅ Cadastro e gerenciamento de alunas
- ✅ Agendamento de aulas com controle de vagas
- ✅ Sistema de lista de espera automática
- ✅ Controle de planos e créditos
- ✅ Pagamentos e renovações
- ✅ Notificações push automáticas
- ✅ Painel administrativo completo

## 🚀 Stack Tecnológica

### Frontend
- **Flutter** (Dart)
- **Plataformas**: Android (MVP) | iOS (Fase 2)

### Backend & Infraestrutura
- **Firebase**
  - Firestore (Banco de dados NoSQL)
  - Authentication (Autenticação)
  - Cloud Storage (Armazenamento de arquivos)
  - Cloud Functions (Backend serverless)
  - Cloud Messaging (Push notifications)

### Integrações Futuras
- Gateway de pagamento (Mercado Pago/Asaas/Stripe)
- WhatsApp Business API (notificações)

## 📁 Estrutura do Repositório

```
app_pole_fenix/
├── docs/                           # Documentação
│   ├── ESPECIFICACAO_TECNICA.md   # Especificação completa
│   ├── MODELO_DADOS.md            # Estrutura do banco
│   ├── FLUXOGRAMAS.md             # Fluxos de usuário
│   └── TELAS.md                   # Mockups de interface
├── lib/                           # Código Flutter
│   ├── models/                    # Modelos de dados
│   ├── services/                  # Serviços (Firebase, etc)
│   ├── screens/                   # Telas do app
│   ├── widgets/                   # Componentes reutilizáveis
│   └── utils/                     # Utilitários
├── functions/                     # Cloud Functions
└── README.md
```

## 🎯 Funcionalidades Principais

### Para Alunas
- Cadastro com escolha de plano
- Visualização de horários disponíveis
- Agendamento de aulas
- Lista de espera automática
- Cancelamento com regras de prazo
- Controle de créditos e histórico
- Visualização de eventos (workshops)
- Renovação de plano

### Para Administradores
- Aprovação de cadastros
- Confirmação de pagamentos
- Liberação de horários semanais
- Gerenciamento de aulas
- Cancelamento de aulas
- Ajuste manual de créditos
- Gestão de eventos
- Relatórios e notificações

## 📦 Planos Disponíveis

### Plano 1x por semana
- **Valor**: R$ 160,00/mês
- **Créditos**: 4 aulas por mês
- **Limite**: 1 aula por semana

### Plano 2x por semana
- **Valor**: R$ 250,00/mês
- **Créditos**: 8 aulas por mês
- **Limite**: 2 aulas por semana

## 🔧 Configuração do Ambiente

### Pré-requisitos
- Flutter SDK (3.0+)
- Dart SDK (3.0+)
- Firebase CLI
- Android Studio / Xcode
- Git

### Instalação

1. Clone o repositório:
```bash
git clone https://github.com/JorgeHenrie/app_pole_fenix.git
cd app_pole_fenix
```

2. Instale as dependências:
```bash
flutter pub get
```

3. Configure o Firebase:
```bash
firebase login
flutterfire configure
```

4. Execute o app:
```bash
flutter run
```

## 📱 Regras de Negócio

### Agendamento
- Cada aula comporta 3 alunas
- Sistema de lista de espera automático
- Validação de limite semanal por plano
- Controle automático de créditos

### Cancelamento
- **Aluna**: até 2h antes (devolve crédito)
- **Professor**: até 1h antes (devolve crédito para todas)
- Fora do prazo: perde crédito (professor pode restaurar)

### Horários
- Professor cria grade padrão semanal
- Liberação manual a cada semana
- Pode ajustar horários específicos

### Pagamentos
- **MVP**: Manual (PIX/Transferência) + confirmação admin
- **Fase 2**: Gateway de pagamento automático
- Renovação mensal com notificações (7 e 3 dias antes)

## 📚 Documentação

- [Especificação Técnica Completa](docs/ESPECIFICACAO_TECNICA.md)
- [Modelo de Dados](docs/MODELO_DADOS.md)
- [Fluxogramas](docs/FLUXOGRAMAS.md)
- [Estrutura de Telas](docs/TELAS.md)

## 🗓️ Roadmap

### MVP (Fase 1) - Em Desenvolvimento
- [x] Especificação técnica
- [ ] Setup do projeto Flutter
- [ ] Configuração do Firebase
- [ ] Autenticação e cadastro
- [ ] Sistema de agendamento
- [ ] Painel administrativo
- [ ] Notificações push

### Fase 2 - Melhorias
- [ ] Integração com gateway de pagamento
- [ ] App iOS
- [ ] Notificações SMS
- [ ] Relatórios avançados

### Fase 3 - Futuro
- [ ] WhatsApp Business API
- [ ] Sistema de fidelidade
- [ ] Múltiplas professoras
- [ ] Agendamento de eventos

## 👥 Equipe

- **Proprietários**: Jorge Henrie + Professora
- **Desenvolvimento**: Em andamento

## 📄 Licença

Este projeto é proprietário e confidencial.

## 📞 Contato

Para mais informações sobre o Fênix Pole Dance Studio:
- WhatsApp: (11) 99999-9999
- Email: contato@fenixpoledance.com.br

---

**Desenvolvido com ❤️ para automatizar e melhorar a experiência das alunas do Fênix Pole Dance** 🎪💪