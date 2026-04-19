"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.notificarRemocaoHorarioFixo = exports.notificarResultadoAtestado = exports.notificarMovimentoConquistado = exports.notificarStatusMigracaoPlano = exports.notificarSolicitacaoMigracaoPlanoPendente = exports.notificarStatusCadastro = exports.notificarNovoCadastroPendente = exports.enviarLembretesRenovacaoPlano = exports.enviarLembretesAulasDoDia = exports.notificarCancelamentosDeAula = exports.sincronizarMinhasAulasPassadas = exports.contratarPlano = exports.obterOcupacaoHorarios = exports.sincronizarInativas = exports.excluirAluna = exports.darBaixaDiariaAulas = void 0;
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
function mapearDiaSemanaJavaScriptParaApp(diaSemana) {
    return diaSemana === 0 ? 7 : diaSemana;
}
function partesDataHoraRR(data) {
    const partes = new Intl.DateTimeFormat("en-CA", {
        timeZone: TIME_ZONE,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hourCycle: "h23",
    }).formatToParts(data);
    const lerParte = (tipo) => {
        const valor = partes.find((parte) => parte.type === tipo)?.value;
        return Number.parseInt(valor ?? "0", 10);
    };
    return {
        ano: lerParte("year"),
        mes: lerParte("month"),
        dia: lerParte("day"),
        hora: lerParte("hour"),
        minuto: lerParte("minute"),
        segundo: lerParte("second"),
    };
}
function criarDataVirtualRR(ano, mes, dia, hora = 0, minuto = 0, segundo = 0) {
    return new Date(Date.UTC(ano, mes - 1, dia, hora, minuto, segundo, 0));
}
function obterAgoraRR() {
    const partes = partesDataHoraRR(new Date());
    return criarDataVirtualRR(partes.ano, partes.mes, partes.dia, partes.hora, partes.minuto, partes.segundo);
}
function formatarIsoLocalRR(data) {
    const pad = (valor) => valor.toString().padStart(2, "0");
    return `${data.getUTCFullYear()}-${pad(data.getUTCMonth() + 1)}-${pad(data.getUTCDate())}T${pad(data.getUTCHours())}:${pad(data.getUTCMinutes())}:${pad(data.getUTCSeconds())}.000`;
}
function calcularProximasOcorrenciasRR(diaSemana, horario, semanas = 4) {
    const horarioMatch = /^(\d{2}):(\d{2})$/.exec(horario);
    if (!horarioMatch) {
        throw new https_1.HttpsError("failed-precondition", `Horário inválido na grade: ${horario}.`);
    }
    const hora = Number.parseInt(horarioMatch[1], 10);
    const minuto = Number.parseInt(horarioMatch[2], 10);
    const agora = obterAgoraRR();
    let base = criarDataVirtualRR(agora.getUTCFullYear(), agora.getUTCMonth() + 1, agora.getUTCDate(), agora.getUTCHours(), agora.getUTCMinutes(), agora.getUTCSeconds());
    while (mapearDiaSemanaJavaScriptParaApp(base.getUTCDay()) !== diaSemana) {
        base.setUTCDate(base.getUTCDate() + 1);
    }
    let primeira = criarDataVirtualRR(base.getUTCFullYear(), base.getUTCMonth() + 1, base.getUTCDate(), hora, minuto, 0);
    if (primeira.getTime() <= agora.getTime()) {
        primeira.setUTCDate(primeira.getUTCDate() + 7);
    }
    return Array.from({ length: semanas }, (_, index) => {
        const data = new Date(primeira.getTime());
        data.setUTCDate(data.getUTCDate() + index * 7);
        return data;
    });
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
exports.obterOcupacaoHorarios = (0, https_1.onCall)({ region: REGION }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Login obrigatório.");
    }
    const payload = request.data;
    const gradeHorarioIds = Array.isArray(payload?.gradeHorarioIds)
        ? payload.gradeHorarioIds
            .filter((item) => typeof item === "string")
            .map((item) => item.trim())
            .filter((item) => item.length > 0)
        : [];
    const gradeDocs = gradeHorarioIds.length > 0
        ? await Promise.all([...new Set(gradeHorarioIds)].map((id) => db.collection("grade_horarios").doc(id).get()))
        : (await db.collection("grade_horarios").where("ativo", "==", true).get())
            .docs;
    const gradesAtivas = gradeDocs
        .filter((doc) => doc.exists && doc.data()?.ativo === true)
        .map((doc) => ({
        id: doc.id,
        diaSemana: doc.data()?.diaSemana,
        horario: doc.data()?.horario,
    }));
    const horariosAtivosSnap = await db
        .collection("horarios_fixos")
        .where("ativo", "==", true)
        .get();
    const ocupacaoPorSlot = new Map();
    for (const doc of horariosAtivosSnap.docs) {
        const dados = doc.data();
        const diaSemana = dados.diaSemana;
        const horario = dados.horario;
        if (typeof diaSemana !== "number" || typeof horario !== "string") {
            continue;
        }
        const chave = `${diaSemana}|${horario}`;
        ocupacaoPorSlot.set(chave, (ocupacaoPorSlot.get(chave) ?? 0) + 1);
    }
    const ocupacaoPorGradeHorarioId = {};
    for (const grade of gradesAtivas) {
        ocupacaoPorGradeHorarioId[grade.id] =
            ocupacaoPorSlot.get(`${grade.diaSemana}|${grade.horario}`) ?? 0;
    }
    return { ocupacaoPorGradeHorarioId };
});
exports.contratarPlano = (0, https_1.onCall)({ region: REGION }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Login obrigatório.");
    }
    const payload = request.data;
    const planoId = typeof payload?.planoId === "string" ? payload.planoId.trim() : "";
    const gradeHorarioIds = Array.isArray(payload?.gradeHorarioIds)
        ? payload.gradeHorarioIds
            .filter((item) => typeof item === "string")
            .map((item) => item.trim())
            .filter((item) => item.length > 0)
        : [];
    if (!planoId) {
        throw new https_1.HttpsError("invalid-argument", "planoId é obrigatório.");
    }
    const gradeIdsUnicos = [...new Set(gradeHorarioIds)];
    if (gradeIdsUnicos.length === 0) {
        throw new https_1.HttpsError("invalid-argument", "Selecione ao menos um horário para contratar o plano.");
    }
    const alunaId = request.auth.uid;
    const usuarioRef = db.collection("usuarios").doc(alunaId);
    const assinaturaRef = db.collection("assinaturas").doc();
    const agoraReal = new Date();
    const agoraTimestamp = admin.firestore.Timestamp.fromDate(agoraReal);
    const agoraRR = obterAgoraRR();
    const agoraRRIso = formatarIsoLocalRR(agoraRR);
    const horarioFixoIds = [];
    await db.runTransaction(async (transaction) => {
        const usuarioSnap = await transaction.get(usuarioRef);
        if (!usuarioSnap.exists || !usuarioSnap.data()) {
            throw new https_1.HttpsError("not-found", "Usuária não encontrada.");
        }
        const usuarioData = usuarioSnap.data();
        if (usuarioData.tipoUsuario !== "aluna") {
            throw new https_1.HttpsError("permission-denied", "Somente alunas podem contratar planos por este fluxo.");
        }
        if (usuarioData.ativo !== true) {
            throw new https_1.HttpsError("failed-precondition", "Sua conta está inativa. Entre em contato com o estúdio.");
        }
        if (usuarioData.statusCadastro && usuarioData.statusCadastro !== "aprovado") {
            throw new https_1.HttpsError("failed-precondition", "Seu cadastro ainda não está aprovado para contratação.");
        }
        const assinaturaAtivaSnap = await transaction.get(db
            .collection("assinaturas")
            .where("alunaId", "==", alunaId)
            .where("status", "==", "ativa")
            .limit(1));
        if (!assinaturaAtivaSnap.empty) {
            throw new https_1.HttpsError("failed-precondition", "Você já possui um plano ativo.");
        }
        const planoSnap = await transaction.get(db.collection("planos").doc(planoId));
        if (!planoSnap.exists || !planoSnap.data()) {
            throw new https_1.HttpsError("not-found", "Plano não encontrado.");
        }
        const planoData = planoSnap.data();
        if (planoData.ativo !== true) {
            throw new https_1.HttpsError("failed-precondition", "O plano selecionado não está disponível no momento.");
        }
        const aulasSemanais = typeof planoData.aulasSemanais === "number" ? planoData.aulasSemanais : 1;
        const aulasPorMes = typeof planoData.aulasPorMes === "number"
            ? planoData.aulasPorMes
            : typeof planoData.quantidadeAulas === "number"
                ? planoData.quantidadeAulas
                : 0;
        const duracaoDias = typeof planoData.duracaoDias === "number" ? planoData.duracaoDias : 30;
        if (gradeIdsUnicos.length !== aulasSemanais) {
            throw new https_1.HttpsError("invalid-argument", `Este plano exige ${aulasSemanais} horário(s) fixo(s).`);
        }
        const gradeSnaps = await Promise.all(gradeIdsUnicos.map((id) => transaction.get(db.collection("grade_horarios").doc(id))));
        const gradesSelecionadas = gradeSnaps.map((snap) => {
            if (!snap.exists || !snap.data()) {
                throw new https_1.HttpsError("failed-precondition", "Um dos horários selecionados não existe mais.");
            }
            const dados = snap.data();
            if (dados.ativo !== true) {
                throw new https_1.HttpsError("failed-precondition", "Um dos horários selecionados não está mais disponível.");
            }
            return {
                id: snap.id,
                diaSemana: dados.diaSemana,
                horario: dados.horario,
                modalidade: dados.modalidade,
                capacidadeMaxima: typeof dados.capacidadeMaxima === "number" ? dados.capacidadeMaxima : 3,
            };
        });
        const slotsUnicos = new Set();
        for (const grade of gradesSelecionadas) {
            const chave = `${grade.diaSemana}|${grade.horario}`;
            if (slotsUnicos.has(chave)) {
                throw new https_1.HttpsError("invalid-argument", "Selecione horários diferentes para concluir a contratação.");
            }
            slotsUnicos.add(chave);
        }
        const horariosAtivosSnap = await transaction.get(db.collection("horarios_fixos").where("ativo", "==", true));
        const ocupacaoPorSlot = new Map();
        for (const doc of horariosAtivosSnap.docs) {
            const dados = doc.data();
            const diaSemana = dados.diaSemana;
            const horario = dados.horario;
            if (typeof diaSemana !== "number" || typeof horario !== "string") {
                continue;
            }
            const chave = `${diaSemana}|${horario}`;
            ocupacaoPorSlot.set(chave, (ocupacaoPorSlot.get(chave) ?? 0) + 1);
        }
        for (const grade of gradesSelecionadas) {
            const chave = `${grade.diaSemana}|${grade.horario}`;
            const vagasOcupadas = ocupacaoPorSlot.get(chave) ?? 0;
            if (vagasOcupadas >= grade.capacidadeMaxima) {
                throw new https_1.HttpsError("failed-precondition", `O horário de ${nomeDiaSemana(grade.diaSemana)} às ${grade.horario} lotou agora. Selecione outro.`);
            }
            ocupacaoPorSlot.set(chave, vagasOcupadas + 1);
        }
        transaction.set(assinaturaRef, {
            alunaId,
            planoId,
            status: "ativa",
            creditosDisponiveis: aulasPorMes,
            dataInicio: agoraTimestamp,
            dataRenovacao: admin.firestore.Timestamp.fromDate(new Date(agoraReal.getTime() + duracaoDias * UM_DIA_EM_MS)),
            dataCancelamento: null,
            horarioFixoIds: [],
            aulasRealizadas: 0,
            reposicoesDisponiveis: 0,
        });
        for (const grade of gradesSelecionadas) {
            const horarioRef = db.collection("horarios_fixos").doc();
            horarioFixoIds.push(horarioRef.id);
            transaction.set(horarioRef, {
                alunaId,
                assinaturaId: assinaturaRef.id,
                diaSemana: grade.diaSemana,
                horario: grade.horario,
                modalidade: grade.modalidade,
                ativo: true,
                criadoEm: agoraTimestamp,
                desativadoEm: null,
                motivoDesativacao: null,
            });
            const ocorrencias = calcularProximasOcorrenciasRR(grade.diaSemana, grade.horario, 4);
            for (const ocorrencia of ocorrencias) {
                const aulaRef = db.collection("aulas").doc();
                transaction.set(aulaRef, {
                    alunaId,
                    horarioFixoId: horarioRef.id,
                    dataHora: formatarIsoLocalRR(ocorrencia),
                    modalidade: grade.modalidade,
                    status: "agendada",
                    motivoCancelamento: null,
                    dataCancelamento: null,
                    dentroDosPrazo: true,
                    criadaEm: agoraRRIso,
                    titulo: null,
                    duracaoMinutos: null,
                    capacidadeMaxima: null,
                    vagasOcupadas: null,
                    instrutora: null,
                });
            }
        }
        transaction.update(assinaturaRef, {
            horarioFixoIds,
        });
        transaction.set(usuarioRef, {
            planoId,
            atualizadoEm: agoraTimestamp,
        }, { merge: true });
    });
    return {
        assinaturaId: assinaturaRef.id,
        horarioFixoIds,
        quantidadeAulasGeradas: horarioFixoIds.length * 4,
    };
});
exports.sincronizarMinhasAulasPassadas = (0, https_1.onCall)({ region: REGION }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Login obrigatório.");
    }
    const alunaId = request.auth.uid;
    const agoraRR = formatarIsoLocalRR(obterAgoraRR());
    const aulasSnap = await db
        .collection("aulas")
        .where("alunaId", "==", alunaId)
        .where("status", "==", "agendada")
        .where("dataHora", "<", agoraRR)
        .get();
    if (aulasSnap.empty) {
        return { baixas: 0 };
    }
    const assinaturaSnap = await db
        .collection("assinaturas")
        .where("alunaId", "==", alunaId)
        .where("status", "==", "ativa")
        .limit(1)
        .get();
    const batch = db.batch();
    for (const doc of aulasSnap.docs) {
        batch.update(doc.ref, { status: "realizada" });
    }
    if (!assinaturaSnap.empty) {
        batch.update(assinaturaSnap.docs[0].ref, {
            creditosDisponiveis: admin.firestore.FieldValue.increment(-aulasSnap.size),
            aulasRealizadas: admin.firestore.FieldValue.increment(aulasSnap.size),
        });
    }
    await batch.commit();
    return { baixas: aulasSnap.size };
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
exports.notificarSolicitacaoMigracaoPlanoPendente = (0, firestore_1.onDocumentWritten)({
    document: "solicitacoes_migracao_plano/{solicitacaoId}",
    region: REGION,
}, async (event) => {
    const antes = event.data?.before.data();
    const depois = event.data?.after.data();
    if (!depois)
        return;
    if (depois.status !== "pendente")
        return;
    if (antes?.status === "pendente")
        return;
    const adminIds = await listarAdminsAtivos();
    if (adminIds.length === 0)
        return;
    const nomeAluna = typeof depois.alunaNome === "string" && depois.alunaNome.trim().length > 0
        ? depois.alunaNome
        : "Uma aluna";
    const planoAtual = typeof depois.planoAtualNome === "string" &&
        depois.planoAtualNome.trim().length > 0
        ? depois.planoAtualNome
        : "plano atual";
    const planoDestino = typeof depois.planoDestinoNome === "string" &&
        depois.planoDestinoNome.trim().length > 0
        ? depois.planoDestinoNome
        : "novo plano";
    await notificarUsuarios(adminIds, {
        titulo: "Nova migração de plano pendente",
        mensagem: `${nomeAluna} solicitou migração de ${planoAtual} para ${planoDestino}.`,
        tipo: "migracao_plano_pendente",
        referenciaId: event.params.solicitacaoId,
        dados: {
            tipo: "migracao_plano_pendente",
            solicitacaoId: event.params.solicitacaoId,
        },
    });
});
exports.notificarStatusMigracaoPlano = (0, firestore_1.onDocumentUpdated)({
    document: "solicitacoes_migracao_plano/{solicitacaoId}",
    region: REGION,
}, async (event) => {
    const antes = event.data?.before.data();
    const depois = event.data?.after.data();
    if (!antes || !depois)
        return;
    if (antes.status === depois.status)
        return;
    if (typeof depois.alunaId !== "string" || depois.alunaId.trim().length === 0) {
        return;
    }
    const planoDestino = typeof depois.planoDestinoNome === "string" &&
        depois.planoDestinoNome.trim().length > 0
        ? depois.planoDestinoNome
        : "novo plano";
    if (depois.status === "aprovada") {
        await notificarUsuario(depois.alunaId, {
            titulo: "Migração de plano aprovada",
            mensagem: `Seu plano foi atualizado para ${planoDestino}. O acesso já segue as regras do novo plano.`,
            tipo: "migracao_plano_status",
            referenciaId: event.params.solicitacaoId,
            dados: {
                tipo: "migracao_plano_status",
                status: "aprovada",
                solicitacaoId: event.params.solicitacaoId,
            },
        });
        return;
    }
    if (depois.status === "rejeitada") {
        const respostaAdmin = typeof depois.respostaAdmin === "string" &&
            depois.respostaAdmin.trim().length > 0
            ? ` Motivo: ${depois.respostaAdmin}`
            : "";
        await notificarUsuario(depois.alunaId, {
            titulo: "Migração de plano não aprovada",
            mensagem: `Sua solicitação para ${planoDestino} não foi aprovada.${respostaAdmin}`,
            tipo: "migracao_plano_status",
            referenciaId: event.params.solicitacaoId,
            dados: {
                tipo: "migracao_plano_status",
                status: "rejeitada",
                solicitacaoId: event.params.solicitacaoId,
            },
        });
    }
});
exports.notificarMovimentoConquistado = (0, firestore_1.onDocumentWritten)({
    document: "jornada_movimentos/{registroId}",
    region: REGION,
}, async (event) => {
    const antes = event.data?.before.data();
    const depois = event.data?.after.data();
    if (!depois)
        return;
    if (antes)
        return;
    if (typeof depois.alunaId !== "string" || depois.alunaId.trim().length === 0) {
        return;
    }
    const movimentoNome = typeof depois.movimentoNome === "string" &&
        depois.movimentoNome.trim().length > 0
        ? depois.movimentoNome
        : "novo movimento";
    await notificarUsuario(depois.alunaId, {
        titulo: "Que lindo!",
        mensagem: `Você conquistou o movimento ${movimentoNome}. Que tal registrar isso com sua foto?`,
        tipo: "movimento_conquistado",
        referenciaId: event.params.registroId,
        dados: {
            tipo: "movimento_conquistado",
            registroId: event.params.registroId,
        },
    });
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