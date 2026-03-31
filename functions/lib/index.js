"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sincronizarInativas = exports.excluirAluna = exports.criarContasImportadas = exports.darBaixaDiariaAulas = void 0;
const admin = require("firebase-admin");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const https_1 = require("firebase-functions/v2/https");
const v2_1 = require("firebase-functions/v2");
admin.initializeApp();
const db = admin.firestore();
/**
 * Roda todo dia à meia-noite (horário de Brasília).
 * Busca todas as aulas com status 'agendada' cuja dataHora já passou,
 * marca como 'realizada' e desconta crédito da assinatura ativa da aluna.
 */
exports.darBaixaDiariaAulas = (0, scheduler_1.onSchedule)({
    schedule: "0 0 * * *",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
}, async () => {
    const agora = new Date().toISOString();
    // 1. Buscar todas as aulas agendadas com dataHora no passado
    const aulasSnap = await db
        .collection("aulas")
        .where("status", "==", "agendada")
        .where("dataHora", "<", agora)
        .get();
    if (aulasSnap.empty) {
        v2_1.logger.info("Nenhuma aula para dar baixa.");
        return;
    }
    v2_1.logger.info(`${aulasSnap.size} aula(s) encontrada(s) para dar baixa.`);
    // 2. Agrupar docs por alunaId
    const porAluna = new Map();
    for (const doc of aulasSnap.docs) {
        const alunaId = doc.data().alunaId;
        if (!porAluna.has(alunaId))
            porAluna.set(alunaId, []);
        porAluna.get(alunaId).push(doc);
    }
    // 3. Para cada aluna, buscar assinatura ativa e commitar batch
    const tarefas = Array.from(porAluna.entries()).map(async ([alunaId, docs]) => {
        const assinaturaSnap = await db
            .collection("assinaturas")
            .where("alunaId", "==", alunaId)
            .where("status", "==", "ativa")
            .limit(1)
            .get();
        if (assinaturaSnap.empty) {
            // Sem assinatura ativa: apenas marca as aulas como realizadas
            const batch = db.batch();
            for (const doc of docs) {
                batch.update(doc.ref, { status: "realizada" });
            }
            await batch.commit();
            v2_1.logger.warn(`Aluna ${alunaId}: sem assinatura ativa, aulas marcadas sem debitar crédito.`);
            return;
        }
        const assinaturaRef = assinaturaSnap.docs[0].ref;
        const batch = db.batch();
        for (const doc of docs) {
            batch.update(doc.ref, { status: "realizada" });
        }
        batch.update(assinaturaRef, {
            creditosDisponiveis: admin.firestore.FieldValue.increment(-docs.length),
            aulasRealizadas: admin.firestore.FieldValue.increment(docs.length),
        });
        await batch.commit();
        v2_1.logger.info(`Aluna ${alunaId}: ${docs.length} aula(s) realizada(s), crédito(s) descontado(s).`);
    });
    await Promise.all(tarefas);
    v2_1.logger.info(`Baixa diária concluída. ${porAluna.size} aluna(s) processada(s).`);
});
// ─── Helpers ─────────────────────────────────────────────────────────────────
/** Remove acentos, espaços e caracteres especiais do nome → email placeholder. */
function normalizarNome(nome) {
    return nome
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/\s+/g, "")
        .replace(/[^a-z0-9]/g, "");
}
/** Calcula a próxima data de vencimento dado o dia do mês. */
function proximoVencimento(dia) {
    const hoje = new Date();
    if (hoje.getDate() < dia) {
        return new Date(hoje.getFullYear(), hoje.getMonth(), dia);
    }
    const proximo = new Date(hoje.getFullYear(), hoje.getMonth() + 1, 1);
    const ultimoDia = new Date(proximo.getFullYear(), proximo.getMonth() + 1, 0).getDate();
    return new Date(proximo.getFullYear(), proximo.getMonth(), dia > ultimoDia ? ultimoDia : dia);
}
/**
 * Cria contas no Firebase Auth e documentos no Firestore para as alunas
 * importadas da planilha. Só pode ser chamada por um admin autenticado.
 *
 * Email placeholder: nome@fenixpole.local  |  Senha padrão: Fenix@2026
 */
exports.criarContasImportadas = (0, https_1.onCall)({ region: "southamerica-east1" }, async (request) => {
    // Verifica autenticação
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Login obrigatório.");
    }
    // Verifica se o chamador é admin
    const callerSnap = await db
        .collection("usuarios")
        .doc(request.auth.uid)
        .get();
    if (callerSnap.data()?.tipoUsuario !== "admin") {
        throw new https_1.HttpsError("permission-denied", "Apenas administradores podem criar contas em lote.");
    }
    const alunas = request.data.alunas;
    if (!Array.isArray(alunas) || alunas.length === 0) {
        throw new https_1.HttpsError("invalid-argument", "Lista de alunas vazia.");
    }
    const resultados = [];
    for (const aluna of alunas) {
        const emailPlaceholder = `${normalizarNome(aluna.nome)}@fenixpole.local`;
        try {
            // Cria usuária no Firebase Auth
            const userRecord = await admin.auth().createUser({
                email: emailPlaceholder,
                password: "Fenix@2026",
                displayName: aluna.nome,
            });
            const agora = new Date();
            const batch = db.batch();
            // Documento na coleção usuarios com UID como id
            const usuarioRef = db.collection("usuarios").doc(userRecord.uid);
            batch.set(usuarioRef, {
                nome: aluna.nome,
                email: emailPlaceholder,
                tipoUsuario: "aluna",
                telefone: null,
                dataCadastro: agora.toISOString(),
                ativo: true,
                fotoUrl: null,
                atualizadoEm: null,
                statusCadastro: "aprovado",
                dataAprovacao: agora.toISOString(),
                aprovadoPor: "importacao_planilha",
                motivoRejeicao: null,
                planoId: null,
                nivel: aluna.nivel,
                primeiroAcesso: true,
            });
            // Cria assinatura se houver plano
            if (aluna.mensalidade && aluna.vencimentoDia) {
                const planoSnap = await db
                    .collection("planos")
                    .where("aulasPorMes", "==", aluna.aulasPorMes)
                    .where("ativo", "==", true)
                    .limit(1)
                    .get();
                if (!planoSnap.empty) {
                    const planoId = planoSnap.docs[0].id;
                    const dataRenovacao = proximoVencimento(aluna.vencimentoDia);
                    batch.update(usuarioRef, { planoId });
                    const assinaturaRef = db.collection("assinaturas").doc();
                    batch.set(assinaturaRef, {
                        alunaId: userRecord.uid,
                        planoId,
                        status: "ativa",
                        creditosDisponiveis: aluna.aulasPorMes,
                        aulasRealizadas: 0,
                        reposicoesDisponiveis: 0,
                        horarioFixoIds: [],
                        dataInicio: admin.firestore.Timestamp.fromDate(agora),
                        dataRenovacao: admin.firestore.Timestamp.fromDate(dataRenovacao),
                        dataCancelamento: null,
                    });
                }
            }
            await batch.commit();
            resultados.push({ nome: aluna.nome, ok: true, email: emailPlaceholder });
            v2_1.logger.info(`Conta criada: ${aluna.nome} → ${emailPlaceholder}`);
        }
        catch (e) {
            const mensagem = e instanceof Error ? e.message : String(e);
            resultados.push({ nome: aluna.nome, ok: false, erro: mensagem });
            v2_1.logger.error(`Erro ao criar conta para ${aluna.nome}: ${mensagem}`);
        }
    }
    return { resultados };
});
/**
 * Exclui uma aluna de forma completa:
 *  1. Desabilita a conta no Firebase Auth (impede login imediatamente)
 *  2. Marca ativo: false no documento Firestore
 *  3. Desativa todos os horários fixos dela
 *  4. Cancela a assinatura ativa (se houver)
 */
exports.excluirAluna = (0, https_1.onCall)({ region: "southamerica-east1" }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Login obrigatório.");
    }
    // Verifica se o chamador é admin
    const callerSnap = await db
        .collection("usuarios")
        .doc(request.auth.uid)
        .get();
    if (callerSnap.data()?.tipoUsuario !== "admin") {
        throw new https_1.HttpsError("permission-denied", "Apenas administradores podem excluir alunas.");
    }
    const { alunaId } = request.data;
    if (!alunaId) {
        throw new https_1.HttpsError("invalid-argument", "alunaId é obrigatório.");
    }
    const agora = new Date();
    // 1. Desabilita conta no Firebase Auth (bloqueia login imediatamente)
    await admin.auth().updateUser(alunaId, { disabled: true });
    const batch = db.batch();
    // 2. Marca ativo: false no documento da aluna
    const alunaRef = db.collection("usuarios").doc(alunaId);
    batch.update(alunaRef, {
        ativo: false,
        atualizadoEm: agora.toISOString(),
    });
    // 3. Desativa todos os horários fixos da aluna
    const horariosSnap = await db
        .collection("horarios_fixos")
        .where("alunaId", "==", alunaId)
        .where("ativo", "==", true)
        .get();
    for (const doc of horariosSnap.docs) {
        batch.update(doc.ref, { ativo: false });
    }
    // 4. Cancela assinatura ativa (se houver)
    const assinaturaSnap = await db
        .collection("assinaturas")
        .where("alunaId", "==", alunaId)
        .where("status", "==", "ativa")
        .get();
    for (const doc of assinaturaSnap.docs) {
        batch.update(doc.ref, {
            status: "cancelada",
            dataCancelamento: admin.firestore.Timestamp.fromDate(agora),
        });
    }
    await batch.commit();
    v2_1.logger.info(`Aluna ${alunaId} excluída com sucesso.`);
    return { ok: true };
});
/**
 * Percorre todos os usuários com ativo: false e executa a limpeza completa:
 * desabilita Auth, desativa horários fixos e cancela assinaturas ativas.
 * Útil para corrigir registros que foram soft-deletados pelo método antigo.
 */
exports.sincronizarInativas = (0, https_1.onCall)({ region: "southamerica-east1" }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Login obrigatório.");
    }
    const callerSnap = await db
        .collection("usuarios")
        .doc(request.auth.uid)
        .get();
    if (callerSnap.data()?.tipoUsuario !== "admin") {
        throw new https_1.HttpsError("permission-denied", "Apenas administradores.");
    }
    // Busca todas as alunas inativas
    const inativasSnap = await db
        .collection("usuarios")
        .where("ativo", "==", false)
        .where("tipoUsuario", "==", "aluna")
        .get();
    if (inativasSnap.empty) {
        return { corrigidas: 0 };
    }
    const agora = new Date();
    let corrigidas = 0;
    for (const doc of inativasSnap.docs) {
        const alunaId = doc.id;
        try {
            // 1. Desabilita conta no Auth (ignora se já estiver desabilitada ou inexistente)
            try {
                await admin.auth().updateUser(alunaId, { disabled: true });
            }
            catch (authErr) {
                // auth/user-not-found → ignora
                const code = authErr.code;
                if (code !== "auth/user-not-found")
                    throw authErr;
            }
            const batch = db.batch();
            // 2. Desativa horários fixos ainda ativos
            const horariosSnap = await db
                .collection("horarios_fixos")
                .where("alunaId", "==", alunaId)
                .where("ativo", "==", true)
                .get();
            for (const h of horariosSnap.docs) {
                batch.update(h.ref, { ativo: false });
            }
            // 3. Cancela assinaturas ativas
            const assinaturaSnap = await db
                .collection("assinaturas")
                .where("alunaId", "==", alunaId)
                .where("status", "==", "ativa")
                .get();
            for (const a of assinaturaSnap.docs) {
                batch.update(a.ref, {
                    status: "cancelada",
                    dataCancelamento: admin.firestore.Timestamp.fromDate(agora),
                });
            }
            await batch.commit();
            corrigidas++;
            v2_1.logger.info(`Aluna inativa ${alunaId} sincronizada.`);
        }
        catch (e) {
            v2_1.logger.error(`Erro ao sincronizar ${alunaId}: ${e}`);
        }
    }
    return { corrigidas };
});
//# sourceMappingURL=index.js.map