"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.notificarRemocaoHorarioFixo = exports.notificarResultadoAtestado = exports.notificarStatusCadastro = exports.notificarNovoCadastroPendente = exports.enviarLembretesRenovacaoPlano = exports.enviarLembretesAulasDoDia = exports.notificarCancelamentosDeAula = exports.sincronizarInativas = exports.excluirAluna = exports.darBaixaDiariaAulas = void 0;
const admin = require("firebase-admin");
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const https_1 = require("firebase-functions/v2/https");
const v2_1 = require("firebase-functions/v2");
admin.initializeApp();
const db = admin.firestore();
const REGION = "southamerica-east1";
const TIME_ZONE = "America/Boa_Vista";
const RR_UTC_OFFSET = "-04:00";
const MINUTOS_CANCELAMENTO_TARDIO = 120;
const UM_DIA_EM_MS = 24 * 60 * 60 * 1000;
/**
 * Roda todo dia à meia-noite (horário de Brasília).
 * Busca todas as aulas com status 'agendada' cuja dataHora já passou,
 * marca como 'realizada' e desconta crédito da assinatura ativa da aluna.
 */
exports.darBaixaDiariaAulas = (0, scheduler_1.onSchedule)({
    schedule: "0 0 * * *",
    timeZone: TIME_ZONE,
    region: REGION,
}, async () => {
    // Roraima usa UTC-4 fixo (sem horário de verão).
    // O app salva dataHora como ISO sem sufixo Z (horário local),
    // por isso subtraímos 4h do UTC para obter a string comparável.
    const agoraUtc = new Date();
    const agoraRR = new Date(agoraUtc.getTime() - 4 * 60 * 60 * 1000)
        .toISOString()
        .replace("Z", "");
    // 1. Buscar todas as aulas agendadas com dataHora no passado
    const aulasSnap = await db
        .collection("aulas")
        .where("status", "==", "agendada")
        .where("dataHora", "<", agoraRR)
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
function parseDataApp(valor) {
    if (valor instanceof admin.firestore.Timestamp)
        return valor.toDate();
    if (valor instanceof Date)
        return valor;
    if (typeof valor === "string") {
        const possuiTimezone = /(Z|[+-]\d{2}:\d{2})$/.test(valor);
        const texto = possuiTimezone ? valor : `${valor}${RR_UTC_OFFSET}`;
        const data = new Date(texto);
        if (!Number.isNaN(data.getTime()))
            return data;
    }
    return null;
}
function chaveDataRR(data) {
    const partes = new Intl.DateTimeFormat("en-CA", {
        timeZone: TIME_ZONE,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
    }).formatToParts(data);
    const ano = partes.find((parte) => parte.type === "year")?.value;
    const mes = partes.find((parte) => parte.type === "month")?.value;
    const dia = partes.find((parte) => parte.type === "day")?.value;
    return `${ano}-${mes}-${dia}`;
}
function diferencaDiasCalendarioRR(destino, origem) {
    const destinoMs = Date.parse(`${chaveDataRR(destino)}T00:00:00Z`);
    const origemMs = Date.parse(`${chaveDataRR(origem)}T00:00:00Z`);
    return Math.round((destinoMs - origemMs) / UM_DIA_EM_MS);
}
function mesmoDiaRR(a, b) {
    return chaveDataRR(a) === chaveDataRR(b);
}
function formatarDataHoraRR(data) {
    return new Intl.DateTimeFormat("pt-BR", {
        timeZone: TIME_ZONE,
        day: "2-digit",
        month: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
    }).format(data);
}
function formatarDataRR(data) {
    return new Intl.DateTimeFormat("pt-BR", {
        timeZone: TIME_ZONE,
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
    }).format(data);
}
function formatarHoraRR(data) {
    return new Intl.DateTimeFormat("pt-BR", {
        timeZone: TIME_ZONE,
        hour: "2-digit",
        minute: "2-digit",
    }).format(data);
}
function nomeDiaSemana(diaSemana) {
    switch (diaSemana) {
        case 1:
            return "segunda-feira";
        case 2:
            return "terça-feira";
        case 3:
            return "quarta-feira";
        case 4:
            return "quinta-feira";
        case 5:
            return "sexta-feira";
        case 6:
            return "sábado";
        case 7:
            return "domingo";
        default:
            return "dia informado";
    }
}
async function listarAdminsAtivos() {
    const snapshot = await db
        .collection("usuarios")
        .where("tipoUsuario", "==", "admin")
        .where("ativo", "==", true)
        .get();
    return snapshot.docs.map((doc) => doc.id);
}
async function obterNomeUsuario(usuarioId) {
    const snapshot = await db.collection("usuarios").doc(usuarioId).get();
    const nome = snapshot.data()?.nome;
    return typeof nome === "string" && nome.trim().length > 0 ? nome : null;
}
async function enviarPushParaUsuarios(usuarioIds, conteudo) {
    const ids = [...new Set(usuarioIds.filter((id) => id.trim().length > 0))];
    if (ids.length === 0)
        return;
    const snapshots = await Promise.all(ids.map((usuarioId) => db.collection("usuarios").doc(usuarioId).get()));
    const tokens = new Set();
    for (const snapshot of snapshots) {
        const valores = snapshot.data()?.fcmTokens;
        if (!Array.isArray(valores))
            continue;
        for (const valor of valores) {
            if (typeof valor === "string" && valor.trim().length > 0) {
                tokens.add(valor);
            }
        }
    }
    if (tokens.size === 0)
        return;
    try {
        await admin.messaging().sendEachForMulticast({
            tokens: [...tokens],
            notification: {
                title: conteudo.titulo,
                body: conteudo.mensagem,
            },
            data: conteudo.dados ?? { tipo: conteudo.tipo },
        });
    }
    catch (erro) {
        v2_1.logger.warn(`Falha ao enviar push: ${String(erro)}`);
    }
}
async function notificarUsuarios(usuarioIds, conteudo) {
    const ids = [...new Set(usuarioIds.filter((id) => id.trim().length > 0))];
    if (ids.length === 0)
        return;
    const batch = db.batch();
    const criadaEm = new Date().toISOString();
    for (const usuarioId of ids) {
        const notificacaoRef = db.collection("notificacoes").doc();
        batch.set(notificacaoRef, {
            usuarioId,
            titulo: conteudo.titulo,
            mensagem: conteudo.mensagem,
            tipo: conteudo.tipo,
            referenciaId: conteudo.referenciaId ?? null,
            lida: false,
            criadaEm,
        });
    }
    await batch.commit();
    await enviarPushParaUsuarios(ids, conteudo);
}
async function notificarUsuario(usuarioId, conteudo) {
    await notificarUsuarios([usuarioId], conteudo);
}
function construirMensagemLembreteAula(aulas) {
    if (aulas.length === 1) {
        const aula = aulas[0];
        return `Sua aula de ${aula.modalidade} é hoje às ${formatarHoraRR(aula.dataHora)}.`;
    }
    const horarios = aulas.map((aula) => formatarHoraRR(aula.dataHora)).join(", ");
    return `Você tem ${aulas.length} aulas hoje. Horários: ${horarios}.`;
}
/** Calcula a próxima data de vencimento dado o dia do mês. */
/**
 * Exclui uma aluna de forma completa:
 *  1. Desabilita a conta no Firebase Auth (impede login imediatamente)
 *  2. Marca ativo: false no documento Firestore
 *  3. Desativa todos os horários fixos dela
 *  4. Cancela a assinatura ativa (se houver)
 */
exports.excluirAluna = (0, https_1.onCall)({ region: REGION }, async (request) => {
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
exports.sincronizarInativas = (0, https_1.onCall)({ region: REGION }, async (request) => {
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
exports.notificarCancelamentosDeAula = (0, firestore_1.onDocumentWritten)({ document: "aulas/{aulaId}", region: REGION }, async (event) => {
    const antes = event.data?.before.data();
    const depois = event.data?.after.data();
    if (!depois)
        return;
    if (depois.status !== "cancelada" || antes?.status === "cancelada") {
        return;
    }
    const origem = typeof depois.origemCancelamento === "string"
        ? depois.origemCancelamento
        : null;
    const alunaId = typeof depois.alunaId === "string" ? depois.alunaId : null;
    const dataHora = parseDataApp(depois.dataHora);
    if (!origem || !alunaId || !dataHora)
        return;
    if (origem === "aluna") {
        const dataCancelamento = parseDataApp(depois.dataCancelamento) ?? new Date();
        const minutosAteAula = Math.floor((dataHora.getTime() - dataCancelamento.getTime()) / (60 * 1000));
        if (minutosAteAula < 0 ||
            minutosAteAula >= MINUTOS_CANCELAMENTO_TARDIO) {
            return;
        }
        const adminIds = await listarAdminsAtivos();
        if (adminIds.length === 0)
            return;
        const nomeAluna = await obterNomeUsuario(alunaId);
        await notificarUsuarios(adminIds, {
            titulo: "Cancelamento com menos de 2h",
            mensagem: `${nomeAluna ?? "Uma aluna"} cancelou a aula de ` +
                `${formatarDataHoraRR(dataHora)} com menos de 2 horas de antecedência.`,
            tipo: "cancelamento_tardio",
            dados: {
                tipo: "cancelamento_tardio",
                aulaId: event.params.aulaId,
                alunaId,
            },
        });
        return;
    }
    if (origem !== "admin")
        return;
    const modalidade = typeof depois.modalidade === "string" ? depois.modalidade : "sua modalidade";
    await notificarUsuario(alunaId, {
        titulo: "Aula cancelada pelo estúdio",
        mensagem: `O estúdio cancelou sua aula de ${modalidade} em ` +
            `${formatarDataHoraRR(dataHora)}.`,
        tipo: "aula_cancelada",
        dados: {
            tipo: "aula_cancelada",
            aulaId: event.params.aulaId,
        },
    });
});
exports.enviarLembretesAulasDoDia = (0, scheduler_1.onSchedule)({
    schedule: "0 * * * *",
    timeZone: TIME_ZONE,
    region: REGION,
}, async () => {
    const snapshot = await db
        .collection("aulas")
        .where("status", "==", "agendada")
        .get();
    if (snapshot.empty)
        return;
    const hoje = new Date();
    const grupos = new Map();
    for (const doc of snapshot.docs) {
        const dados = doc.data();
        if (dados.notificacaoDiaAulaEnviadaEm != null)
            continue;
        const alunaId = typeof dados.alunaId === "string" ? dados.alunaId : null;
        const dataHora = parseDataApp(dados.dataHora);
        const modalidade = typeof dados.modalidade === "string" ? dados.modalidade : "Pole";
        if (!alunaId || !dataHora || !mesmoDiaRR(dataHora, hoje))
            continue;
        const grupo = grupos.get(alunaId) ?? { docs: [], aulas: [] };
        grupo.docs.push(doc);
        grupo.aulas.push({ dataHora, modalidade });
        grupos.set(alunaId, grupo);
    }
    for (const [alunaId, grupo] of grupos.entries()) {
        grupo.aulas.sort((a, b) => a.dataHora.getTime() - b.dataHora.getTime());
        await notificarUsuario(alunaId, {
            titulo: "Lembrete de aula",
            mensagem: construirMensagemLembreteAula(grupo.aulas),
            tipo: "lembrete_aula",
            dados: {
                tipo: "lembrete_aula",
                data: chaveDataRR(grupo.aulas[0].dataHora),
            },
        });
        const batch = db.batch();
        const enviadaEm = new Date().toISOString();
        for (const doc of grupo.docs) {
            batch.update(doc.ref, { notificacaoDiaAulaEnviadaEm: enviadaEm });
        }
        await batch.commit();
    }
});
exports.enviarLembretesRenovacaoPlano = (0, scheduler_1.onSchedule)({
    schedule: "0 8 * * *",
    timeZone: TIME_ZONE,
    region: REGION,
}, async () => {
    const snapshot = await db
        .collection("assinaturas")
        .where("status", "==", "ativa")
        .get();
    if (snapshot.empty)
        return;
    const hoje = new Date();
    for (const doc of snapshot.docs) {
        const dados = doc.data();
        const alunaId = typeof dados.alunaId === "string" ? dados.alunaId : null;
        const dataRenovacao = parseDataApp(dados.dataRenovacao);
        if (!alunaId || !dataRenovacao)
            continue;
        const dias = diferencaDiasCalendarioRR(dataRenovacao, hoje);
        if (dias === 3 && dados.notificacaoRenovacao3DiasEm == null) {
            await notificarUsuario(alunaId, {
                titulo: "Renovação do plano chegando",
                mensagem: `Seu plano renova em 3 dias, no dia ${formatarDataRR(dataRenovacao)}.`,
                tipo: "renovacao_plano",
                dados: {
                    tipo: "renovacao_plano",
                    assinaturaId: doc.id,
                    marco: "3_dias",
                },
            });
            await doc.ref.update({
                notificacaoRenovacao3DiasEm: new Date().toISOString(),
            });
        }
        if (dias === 0 && dados.notificacaoRenovacaoUltimoDiaEm == null) {
            await notificarUsuario(alunaId, {
                titulo: "Último dia do plano atual",
                mensagem: `Hoje é o último dia do seu ciclo atual. A renovação está prevista para ${formatarDataRR(dataRenovacao)}.`,
                tipo: "renovacao_plano",
                dados: {
                    tipo: "renovacao_plano",
                    assinaturaId: doc.id,
                    marco: "ultimo_dia",
                },
            });
            await doc.ref.update({
                notificacaoRenovacaoUltimoDiaEm: new Date().toISOString(),
            });
        }
    }
});
exports.notificarNovoCadastroPendente = (0, firestore_1.onDocumentWritten)({ document: "usuarios/{usuarioId}", region: REGION }, async (event) => {
    const antes = event.data?.before.data();
    const depois = event.data?.after.data();
    if (!depois)
        return;
    if (depois.tipoUsuario !== "aluna")
        return;
    if (depois.statusCadastro !== "pendente")
        return;
    if (antes?.statusCadastro === "pendente")
        return;
    const adminIds = await listarAdminsAtivos();
    if (adminIds.length === 0)
        return;
    const nomeAluna = typeof depois.nome === "string" && depois.nome.trim().length > 0
        ? depois.nome
        : "Uma nova aluna";
    await notificarUsuarios(adminIds, {
        titulo: "Novo cadastro aguardando aprovação",
        mensagem: `${nomeAluna} solicitou cadastro e está aguardando aprovação.`,
        tipo: "cadastro_pendente",
        referenciaId: event.params.usuarioId,
        dados: {
            tipo: "cadastro_pendente",
            usuarioId: event.params.usuarioId,
        },
    });
});
exports.notificarStatusCadastro = (0, firestore_1.onDocumentUpdated)({ document: "usuarios/{usuarioId}", region: REGION }, async (event) => {
    const antes = event.data?.before.data();
    const depois = event.data?.after.data();
    if (!antes || !depois)
        return;
    if (depois.tipoUsuario !== "aluna")
        return;
    if (antes.statusCadastro === depois.statusCadastro)
        return;
    if (depois.statusCadastro === "aprovado") {
        await notificarUsuario(event.params.usuarioId, {
            titulo: "Cadastro aprovado",
            mensagem: "Seu cadastro foi aprovado. Você já pode acessar o app normalmente.",
            tipo: "cadastro_status",
            dados: {
                tipo: "cadastro_status",
                status: "aprovado",
            },
        });
        return;
    }
    if (depois.statusCadastro === "rejeitado") {
        await notificarUsuario(event.params.usuarioId, {
            titulo: "Cadastro não aprovado",
            mensagem: typeof depois.motivoRejeicao === "string" &&
                depois.motivoRejeicao.trim().length > 0
                ? `Seu cadastro foi rejeitado. Motivo: ${depois.motivoRejeicao}`
                : "Seu cadastro foi rejeitado. Entre em contato com o estúdio para mais detalhes.",
            tipo: "cadastro_status",
            dados: {
                tipo: "cadastro_status",
                status: "rejeitado",
            },
        });
    }
});
exports.notificarResultadoAtestado = (0, firestore_1.onDocumentUpdated)({ document: "aulas/{aulaId}", region: REGION }, async (event) => {
    const antes = event.data?.before.data();
    const depois = event.data?.after.data();
    if (!antes || !depois)
        return;
    if (antes.atestadoPendente != true || depois.atestadoPendente != false) {
        return;
    }
    if (typeof depois.atestadoValidado !== "boolean")
        return;
    const alunaId = typeof depois.alunaId === "string" ? depois.alunaId : null;
    const dataHora = parseDataApp(depois.dataHora);
    if (!alunaId || !dataHora)
        return;
    await notificarUsuario(alunaId, {
        titulo: depois.atestadoValidado
            ? "Atestado aprovado"
            : "Atestado rejeitado",
        mensagem: depois.atestadoValidado
            ? `Seu atestado da aula de ${formatarDataHoraRR(dataHora)} foi aprovado e a reposição já está disponível.`
            : `Seu atestado da aula de ${formatarDataHoraRR(dataHora)} foi rejeitado.`,
        tipo: "atestado",
        dados: {
            tipo: "atestado",
            aulaId: event.params.aulaId,
            resultado: depois.atestadoValidado ? "aprovado" : "rejeitado",
        },
    });
});
exports.notificarRemocaoHorarioFixo = (0, firestore_1.onDocumentUpdated)({ document: "horarios_fixos/{horarioFixoId}", region: REGION }, async (event) => {
    const antes = event.data?.before.data();
    const depois = event.data?.after.data();
    if (!antes || !depois)
        return;
    if (antes.ativo !== true || depois.ativo !== false)
        return;
    const motivo = typeof depois.motivoDesativacao === "string"
        ? depois.motivoDesativacao
        : "";
    if (!motivo.toLowerCase().includes("administrador"))
        return;
    const alunaId = typeof depois.alunaId === "string" ? depois.alunaId : null;
    const horario = typeof depois.horario === "string" ? depois.horario : null;
    const diaSemana = typeof depois.diaSemana === "number" ? depois.diaSemana : null;
    if (!alunaId || !horario || diaSemana == null)
        return;
    await notificarUsuario(alunaId, {
        titulo: "Horário alterado pelo estúdio",
        mensagem: `Seu horário fixo de ${nomeDiaSemana(diaSemana)} às ${horario} ` +
            `foi removido pela administração.`,
        tipo: "horario",
        dados: {
            tipo: "horario",
            horarioFixoId: event.params.horarioFixoId,
        },
    });
});
//# sourceMappingURL=index.js.map