#!/usr/bin/env python3
"""Reanálise independente dos CSVs históricos da Fase 3 (somente leitura).

Usa apenas a biblioteca padrão do Python 3.8+. Não altera nenhum CSV de
benchmarks/. Grava os resultados derivados em analysis/output/.

Uso (na raiz do repositório):
    python -I analysis/reanalyze_phase3.py

O que é calculado:
  1. Recontagem de linhas, aquecimentos, medições e PASS/FAIL.
  2. Recalculo de média, mediana, desvio-padrão amostral e p95 nearest-rank
     e comparação com summary-statistics.csv / transfer-summary-statistics.csv.
  3. Redução da mediana (melhor divisão paralela vs. GTX 970 sozinha) com
     intervalo de confiança bootstrap de 95% (percentil, 10.000 reamostragens,
     semente fixa 20261119).
  4. Taxa efetiva implícita (bytes de resultado / tempo total), para testar a
     hipótese de que o tempo medido é dominado pela cópia GPU->memória do host.
  5. Consistência do baseline: tempo da GTX 970 para N elementos sozinha vs.
     tempo da mesma GTX 970 para o mesmo N dentro de execuções duais.
  6. Tendência temporal dentro de cada grupo (Spearman entre repetição e tempo).
"""
import csv
import math
import os
import random
import statistics as st
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P3 = os.path.join(ROOT, "benchmarks", "phase3")
OUT = os.path.join(ROOT, "analysis", "output")
SEED = 20261119
BOOT = 10000
TOL = 0.00051  # CSVs publicados arredondam para 4 casas


def read(name):
    with open(os.path.join(P3, name), encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def p95(xs):
    s = sorted(xs)
    return s[math.ceil(0.95 * len(s)) - 1]


def stats(xs):
    return st.mean(xs), st.median(xs), st.stdev(xs), p95(xs)


def spearman(x, y):
    def ranks(v):
        order = sorted(range(len(v)), key=lambda i: v[i])
        r = [0.0] * len(v)
        i = 0
        while i < len(v):
            j = i
            while j + 1 < len(v) and v[order[j + 1]] == v[order[i]]:
                j += 1
            for k in range(i, j + 1):
                r[order[k]] = (i + j) / 2 + 1
            i = j + 1
        return r
    rx, ry = ranks(x), ranks(y)
    mx, my = st.mean(rx), st.mean(ry)
    num = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    den = math.sqrt(sum((a - mx) ** 2 for a in rx) * sum((b - my) ** 2 for b in ry))
    return num / den if den else float("nan")


def write(name, header, rows):
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    failures = []
    b = read("benchmark.csv")
    t = read("transfer-benchmark.csv")
    S = read("summary-statistics.csv")
    TS = read("transfer-summary-statistics.csv")
    D = read("optimization-decision.csv")

    # 1. Contagens
    def counts(rows):
        return (len(rows), sum(r["warmup"] == "1" for r in rows),
                sum(r["warmup"] == "0" for r in rows),
                sum(r["validation"] == "PASS" for r in rows))
    cb, ct = counts(b), counts(t)
    print("compute rows/warmup/measured/PASS:", cb)
    print("transfer rows/warmup/measured/PASS:", ct)
    if cb != (1200, 240, 960, 1200):
        failures.append(f"contagem compute inesperada {cb}")
    if ct != (500, 100, 400, 500):
        failures.append(f"contagem transfer inesperada {ct}")

    g = defaultdict(list)
    for r in b:
        if r["warmup"] == "0":
            g[(int(r["elements"]), r["mode"], int(r["gpu970_share_percent"]))].append(r)
    gt = defaultdict(list)
    for r in t:
        if r["warmup"] == "0":
            gt[(int(r["elements"]), int(r["gpu970_share_percent"]))].append(r)
    if len(g) != 48 or any(len(v) != 20 for v in g.values()):
        failures.append("grupos compute != 48x20")
    if len(gt) != 20 or any(len(v) != 20 for v in gt.values()):
        failures.append("grupos transfer != 20x20")

    # 2. Estatísticas publicadas
    mism = 0
    for s in S:
        k = (int(s["Elements"]), s["Mode"], int(s["GPU970SharePercent"]))
        calc = stats([float(x["total_ms"]) for x in g[k]])
        pub = [float(s[c]) for c in ("TotalMeanMs", "TotalMedianMs", "TotalStdDevMs", "TotalP95Ms")]
        if any(abs(a - c) > TOL for a, c in zip(calc, pub)):
            mism += 1
            failures.append(f"summary diverge {k}")
    for s in TS:
        k = (int(s["Elements"]), int(s["GPU970SharePercent"]))
        calc = stats([float(x["transfer_ms"]) for x in gt[k]])
        pub = [float(s[c]) for c in ("TransferMeanMs", "TransferMedianMs", "TransferStdDevMs", "TransferP95Ms")]
        if any(abs(a - c) > TOL for a, c in zip(calc, pub)):
            mism += 1
            failures.append(f"transfer summary diverge {k}")
    print("divergências em estatísticas publicadas:", mism)

    rng = random.Random(SEED)

    def boot_median(xs):
        n = len(xs)
        return [st.median([xs[rng.randrange(n)] for _ in range(n)]) for _ in range(BOOT)]

    # 3. Redução com IC bootstrap
    red_rows = []
    for d in D:
        n = int(d["Elements"])
        pct = int(d["BestParallelRatio970Percent"])
        solo = [float(x["total_ms"]) for x in g[(n, "gtx970_solo", 100)]]
        par = [float(x["total_ms"]) for x in g[(n, "dual_parallel", pct)]]
        point = 1 - st.median(par) / st.median(solo)
        bs, bp = boot_median(solo), boot_median(par)
        reds = sorted(1 - p / s for s, p in zip(bs, bp))
        lo, hi = reds[int(0.025 * BOOT)], reds[int(0.975 * BOOT) - 1]
        red_rows.append([n, pct, f"{st.median(solo):.4f}", f"{st.median(par):.4f}",
                         f"{100*point:.1f}", f"{100*lo:.1f}", f"{100*hi:.1f}"])
    write("phase3-reduction-bootstrap.csv",
          ["elements", "best_parallel_970_share", "gtx970_solo_median_ms", "best_parallel_median_ms",
           "median_reduction_pct", "ci95_low_pct", "ci95_high_pct"], red_rows)
    print("\nRedução da mediana (IC95% bootstrap):")
    for r in red_rows:
        print(f"  {r[0]:>8}  {r[1]}/{100-r[1]}  {r[4]}%  [{r[5]}%, {r[6]}%]")

    # 4. Taxa efetiva implícita (resultado copiado para READBACK dentro do tempo)
    bw_rows = []
    for (n, mode, pct), rows in sorted(g.items()):
        if mode not in ("gtx970_solo", "gtx750_solo"):
            continue
        med = st.median(float(x["total_ms"]) for x in rows)
        gbps = (n * 4) / (med / 1000) / 1e9
        bw_rows.append([n, mode, f"{med:.4f}", n * 4, f"{gbps:.3f}"])
    for (n, pct), rows in sorted(gt.items()):
        med = st.median(float(x["transfer_ms"]) for x in rows)
        by = int(rows[0]["transfer_payload_bytes"])
        bw_rows.append([n, f"transfer_750_to_970_{pct}", f"{med:.4f}", by, f"{by/(med/1000)/1e9:.3f}"])
    write("phase3-implied-throughput.csv",
          ["elements", "mode", "median_ms", "result_bytes", "implied_GBps_decimal"], bw_rows)
    print("\nTaxa implícita (bytes de resultado / mediana do tempo total):")
    for r in bw_rows:
        if "transfer" not in r[1] or r[1].endswith("_50"):
            print(f"  {r[0]:>8} {r[1]:<26} {r[2]:>9} ms  {r[4]} GB/s")

    # 5. Consistência do baseline da GTX 970
    cons_rows = []
    solo970 = {n: st.median(float(x["gpu970_ms"]) for x in g[(n, "gtx970_solo", 100)])
               for n in (1000000, 2000000, 4000000, 8000000)}
    for (n, mode, pct), rows in sorted(g.items()):
        if mode != "dual_parallel":
            continue
        na = n * pct // 100
        if na in solo970:
            dual = st.median(float(x["gpu970_ms"]) for x in rows)
            cons_rows.append([na, n, pct, f"{solo970[na]:.4f}", f"{dual:.4f}",
                              f"{100*(dual/solo970[na]-1):+.1f}"])
    write("phase3-gtx970-baseline-consistency.csv",
          ["gtx970_elements", "dual_total_elements", "share", "gtx970_solo_median_ms",
           "gtx970_ms_inside_dual_median", "dual_vs_solo_pct"], cons_rows)
    print("\nGTX 970 com o mesmo número de elementos: sozinha vs. dentro do dual:")
    for r in cons_rows:
        print(f"  {r[0]:>8} elem (dual {r[1]} {r[2]}/{100-r[2]}): solo {r[3]} ms, no dual {r[4]} ms ({r[5]}%)")

    # 6. Tendência temporal
    trend_rows = []
    for (n, mode, pct), rows in sorted(g.items()):
        reps = [int(x["rep"]) for x in rows]
        ys = [float(x["total_ms"]) for x in rows]
        trend_rows.append([n, mode, pct, f"{spearman(reps, ys):+.3f}"])
    write("phase3-rep-trend-spearman.csv", ["elements", "mode", "share", "spearman_rep_vs_total_ms"], trend_rows)
    strong = [r for r in trend_rows if abs(float(r[3])) >= 0.6]
    print(f"\nGrupos com |Spearman(rep, tempo)| >= 0,6: {len(strong)} de {len(trend_rows)}")
    for r in strong:
        print("  ", r)

    if failures:
        print("\nRESULT=FAIL")
        for f in failures:
            print("  -", f)
        return 1
    print("\nRESULT=PASS (dados conferem; interpretação está no relatório de auditoria)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
