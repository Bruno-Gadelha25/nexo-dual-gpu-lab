#!/usr/bin/env node
// Demonstração para vídeo: a Julinha responde na tela, mostrando placa, tempo e tokens/s.
//   node demo-ia.mjs --etapa 970|750|duas
// Não é medição oficial (o OBS grava junto); os números oficiais estão em data/ai-dual-gpu/.
import fs from 'node:fs';

const arg = {}; const a = process.argv.slice(2);
for (let i = 0; i < a.length; i += 2) arg[a[i].replace(/^--/, '')] = a[i + 1];
const U970 = arg.u970 || 'http://127.0.0.1:11437'; const U750 = arg.u750 || 'http://127.0.0.1:11436';
const model = arg.model || 'qwen3:1.7b';
const persona = arg.personaFile ? fs.readFileSync(arg.personaFile, 'utf8') : 'Você é a Julinha, assistente do Bruno. Responda em português do Brasil.';
const C = { amb: '\x1b[38;2;242;165;65m', cia: '\x1b[38;2;79;193;201m', dim: '\x1b[38;2;140;151;164m', b: '\x1b[1m', r: '\x1b[0m' };
const perguntas = ['Julinha, explica em três frases o que é uma chave estrangeira em banco de dados.', 'Julinha, me dá três dicas para estudar SQL sozinho.', 'Julinha, por que duas placas de vídeo diferentes podem trabalhar juntas?'];

async function responder(url, rot, cor, pergunta, quiet = false) {
  const t0 = Date.now(); let first = 0; let fim = null; let texto = '';
  const res = await fetch(`${url}/api/chat`, { method: 'POST', body: JSON.stringify({ model, stream: true, think: false, keep_alive: '30m',
    messages: [{ role: 'system', content: persona }, { role: 'user', content: pergunta }], options: { num_ctx: 4096, num_predict: Number(arg.max || 120), temperature: 0.6 } }) });
  const reader = res.body.getReader(); const dec = new TextDecoder(); let buf = '';
  if (!quiet) process.stdout.write(`\n${cor}${C.b}[${rot}]${C.r} ${C.dim}${pergunta}${C.r}\n${cor}`);
  for (;;) {
    const { done, value } = await reader.read(); if (done) break;
    buf += dec.decode(value, { stream: true }); let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const e = JSON.parse(buf.slice(0, i)); buf = buf.slice(i + 1);
      if (e.message?.content) { if (!first) first = Date.now() - t0; texto += e.message.content; if (!quiet) process.stdout.write(e.message.content); }
      if (e.done) fim = e;
    }
  }
  const tps = (fim.eval_count / (fim.eval_duration / 1e9)).toFixed(1);
  const resumo = `${cor}${C.b}[${rot}]${C.r} primeira palavra ${(first / 1000).toFixed(2)} s · ${tps} tokens/s · ${fim.eval_count} tokens em ${((Date.now() - t0) / 1000).toFixed(1)} s`;
  if (!quiet) process.stdout.write(`${C.r}\n${resumo}\n`);
  return { resumo, texto, rot, cor };
}

const titulo = (t) => process.stdout.write(`\n${C.b}══ ${t} ══${C.r}\n`);
const etapa = arg.etapa;
if (etapa === '970') { titulo(`Julinha só na GTX 970 (${model})`); for (const p of perguntas.slice(0, Number(arg.n || 1))) await responder(U970, 'GTX 970', C.amb, p); }
if (etapa === '750') { titulo(`Julinha só na GTX 750 Ti (${model})`); for (const p of perguntas.slice(0, Number(arg.n || 1))) await responder(U750, 'GTX 750 Ti', C.cia, p); }
if (etapa === 'nexo') {
  const U2 = arg.uduas || 'http://127.0.0.1:11438';
  titulo('Nexo (qwen3 8b, 5 GB) espalhado nas duas placas');
  process.stdout.write(`${C.dim}Não cabe em nenhuma placa sozinha (4 GB cada). Medido sem OBS: 7,35 tok/s nas duas contra 5,15 só na 970 (+43%).${C.r}\n`);
  const nexo = async (url, pergunta) => {
    const t0 = Date.now(); let first = 0; let fim = null;
    const res = await fetch(`${url}/api/chat`, { method: 'POST', body: JSON.stringify({ model: 'nexo:latest', stream: true, think: false, keep_alive: '30m', messages: [{ role: 'user', content: pergunta }], options: { num_ctx: 4096, num_predict: 160 } }) });
    const reader = res.body.getReader(); const dec = new TextDecoder(); let buf = '';
    process.stdout.write(`\n${C.b}[Nexo · 970 + 750 Ti]${C.r} ${C.dim}${pergunta}${C.r}\n`);
    for (;;) { const { done, value } = await reader.read(); if (done) break; buf += dec.decode(value, { stream: true }); let i;
      while ((i = buf.indexOf('\n')) >= 0) { const e = JSON.parse(buf.slice(0, i)); buf = buf.slice(i + 1); if (e.message?.content) { if (!first) first = Date.now() - t0; process.stdout.write(e.message.content); } if (e.done) fim = e; } }
    process.stdout.write(`\n${C.b}[Nexo]${C.r} ${(fim.eval_count / (fim.eval_duration / 1e9)).toFixed(1)} tokens/s · ${fim.eval_count} tokens em ${((Date.now() - t0) / 1000).toFixed(1)} s\n`);
  };
  await nexo(U2, 'Nexo, explique em poucas frases por que dividir um modelo de IA entre duas placas de vídeo pode deixá-lo mais rápido.');
}
if (etapa === 'duas') {
  titulo('Duas conversas ao mesmo tempo: uma em cada placa');
  for (let k = 0; k < Number(arg.rodadas || 1); k += 1) {
    process.stdout.write(`\n${C.dim}Pergunta para a 970: ${perguntas[k]}\nPergunta para a 750 Ti: ${perguntas[(k + 1) % 3]}\n(respondendo juntas...)${C.r}\n`);
    const t0 = Date.now();
    const rs = await Promise.all([responder(U970, 'GTX 970', C.amb, perguntas[k], true), responder(U750, 'GTX 750 Ti', C.cia, perguntas[(k + 1) % 3], true)]);
    for (const r of rs) process.stdout.write(`\n${r.cor}${C.b}[${r.rot}]${C.r} ${r.cor}${r.texto.trim()}${C.r}\n${r.resumo}\n`);
    process.stdout.write(`${C.b}As duas respostas ficaram prontas em ${((Date.now() - t0) / 1000).toFixed(1)} s${C.r}\n`);
  }
}
