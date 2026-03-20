# Documentação do Modelo de Dados Firestore

## 1. Coleções

### 1.1 Usuários
- **Campo:** `uid`
  - **Descrição:** Identificador único do usuário.
  - **Exemplo:** `abc123`

- **Campo:** `nome`
  - **Descrição:** Nome completo do usuário.
  - **Exemplo:** `João da Silva`

- **Campo:** `email`
  - **Descrição:** Endereço de email do usuário.
  - **Exemplo:** `joão.silva@example.com`

### 1.2 Assinaturas
- **Campo:** `userId`
  - **Descrição:** ID do usuário associado à assinatura.
  - **Exemplo:** `abc123`

- **Campo:** `dataInicio`
  - **Descrição:** Data de início da assinatura.
  - **Exemplo:** `2026-03-20`

- **Campo:** `dataFim`
  - **Descrição:** Data de término da assinatura.
  - **Exemplo:** `2026-04-20`

### 1.3 Pagamentos
- **Campo:** `userId`
  - **Descrição:** ID do usuário que realizou o pagamento.
  - **Exemplo:** `abc123`

- **Campo:** `valor`
  - **Descrição:** Valor do pagamento.
  - **Exemplo:** `99.90`

- **Campo:** `dataPagamento`
  - **Descrição:** Data em que o pagamento foi realizado.
  - **Exemplo:** `2026-03-20`

### 1.4 Planos
- **Campo:** `nome`
  - **Descrição:** Nome do plano.
  - **Exemplo:** `Plano Mensal`

- **Campo:** `valor`
  - **Descrição:** Custo do plano.
  - **Exemplo:** `99.90`

- **Campo:** `duracao`
  - **Descrição:** Duração do plano em dias.
  - **Exemplo:** `30`

### 1.5 Grade Padrão
- **Campo:** `semana`
  - **Descrição:** Dia da semana da grade.
  - **Exemplo:** `Segunda-feira`

- **Campo:** `aulaId`
  - **Descrição:** ID da aula associada à grade.
  - **Exemplo:** `aula_01`

### 1.6 Aulas
- **Campo:** `titulo`
  - **Descrição:** Título da aula.
  - **Exemplo:** `Introdução ao Firestore`

- **Campo:** `descricao`
  - **Descrição:** Descrição detalhada da aula.
  - **Exemplo:** `Aula sobre como utilizar o Firestore`

### 1.7 Matrículas
- **Campo:** `userId`
  - **Descrição:** ID do usuário matriculado.
  - **Exemplo:** `abc123`

- **Campo:** `aulaId`
  - **Descrição:** ID da aula em que o usuário está matriculado.
  - **Exemplo:** `aula_01`

### 1.8 Eventos
- **Campo:** `tipo`
  - **Descrição:** Tipo de evento (ex: `notificação`, `alerta`).
  - **Exemplo:** `notificação`

- **Campo:** `data`
  - **Descrição:** Data do evento.
  - **Exemplo:** `2026-03-20`

### 1.9 Notificações
- **Campo:** `titulo`
  - **Descrição:** Título da notificação.
  - **Exemplo:** `Novo pagamento recebido`

- **Campo:** `mensagem`
  - **Descrição:** Mensagem da notificação.
  - **Exemplo:** `Seu pagamento foi processado com sucesso.`

### 1.10 Ajustes de Crédito
- **Campo:** `userId`
  - **Descrição:** ID do usuário relacionado ao ajuste de crédito.
  - **Exemplo:** `abc123`

- **Campo:** `valor`
  - **Descrição:** Valor do ajuste de crédito.
  - **Exemplo:** `-20.00`

### 1.11 Configurações
- **Campo:** `chave`
  - **Descrição:** Nome da configuração.
  - **Exemplo:** `modoTeste`

- **Campo:** `valor`
  - **Descrição:** Valor da configuração.
  - **Exemplo:** `true`

## 2. Regras de Segurança do Firestore
As regras de segurança controlam o acesso às coleções. Aqui está um exemplo básico:
```
service cloud.firestore {
  match /databases/{database}/documents {
    match /usuarios/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /associados/{docId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## 3. Índices Compuestos
Os índices compostos são necessários para consultas que utilizam múltiplos campos. Exemplo de configurações:
- Coleção: `usuarios`
- Campos: `email`, `nome`

## 4. Gatilhos do Cloud Functions
Exemplo de trigger para lidar com novas inscrições:
```
exports.onUserCreate = functions.auth.user().onCreate((user) => {
    // lógica a ser executada quando um usuário é criado
});
```

## Considerações Finais
Essa documentação abrange todas as coleções e suas respectivas estruturas no Firestore, bem como regras de segurança, índices compostos e gatilhos do Cloud Functions. É importante manter esta documentação atualizada conforme as mudanças no modelo de dados ocorrem.
