// Node 18+/20+, no external deps. Produces /tmp/hpl-web-data/{data,raw}/…

/* eslint-disable no-console */
import fs from "fs/promises";
import path from "path";

const CWD = process.cwd();
const SUITES = ["HPL", "HPL_NVIDIA"];
const SRC_ROOT = path.join(CWD, "src", "output");
const OUT_ROOT = "/tmp/hpl-web-data";
const DATA_ROOT = path.join(OUT_ROOT, "data");
const RAW_ROOT = path.join(OUT_ROOT, "raw");

function toWebRawPath(parts) {
    return "/" + path.posix.join("raw", ...parts);
}
function toDataPath(parts) {
    return path.join(DATA_ROOT, ...parts);
}
function toRawPathFS(parts) {
    return path.join(RAW_ROOT, ...parts);
}

async function ensureDir(p) {
    await fs.mkdir(p, { recursive: true });
}
async function exists(p) {
    try {
        await fs.stat(p);
        return true;
    } catch {
        return false;
    }
}

async function listDirs(dir) {
    const ents = await fs.readdir(dir, { withFileTypes: true });
    return ents.filter((e) => e.isDirectory()).map((e) => e.name);
}
async function listFiles(dir) {
    const ents = await fs.readdir(dir, { withFileTypes: true });
    return ents.filter((e) => e.isFile()).map((e) => e.name);
}

async function readFileSafe(p) {
    try {
        return await fs.readFile(p, "utf8");
    } catch {
        return null;
    }
}
async function copyFileSafe(src, dest) {
    try {
        await ensureDir(path.dirname(dest));
        await fs.copyFile(src, dest);
        return true;
    } catch {
        return false;
    }
}

function firstToken(line) {
    const m = line.trim().match(/^(\S+)/);
    return m ? m[1] : "";
}
function numbersIn(line) {
    // capture ints/floats incl. scientific
    const re = /[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?/g;
    return (line.match(re) || []).map((s) => Number(s));
}
function intToken(line) {
    const t = firstToken(line);
    const n = Number(t);
    return Number.isFinite(n) ? Math.trunc(n) : null;
}
function floatToken(line) {
    const t = firstToken(line);
    const n = Number(t);
    return Number.isFinite(n) ? n : null;
}

// HPL.dat parser (covers classic layout)
function parseHplDat(raw) {
    const lines = raw.split(/\r?\n/);
    const out = {
        header: [],
        outputFilename: null,
        deviceOut: null,
        numProblemSizes: null,
        Ns: [],
        numNBs: null,
        NBs: [],
        pmap: null,
        numGrids: null,
        Ps: [],
        Qs: [],
        threshold: null,
        numPFACT: null,
        PFACTs: [],
        numNBMIN: null,
        NBMINs: [],
        numPanelsInRecursion: null,
        NDIVs: [],
        numRFACT: null,
        RFACTs: [],
        numBCAST: null,
        BCASTs: [],
        numDEPTH: null,
        DEPTHs: [],
        swapMode: null,
        swapThreshold: null,
        L1: null,
        U: null,
        equilibration: null,
        memoryAlignment: null,
    };

    // First 1-2 lines are often title/comments; keep as header up to 2 lines
    for (let i = 0; i < Math.min(lines.length, 2); i++) {
        if (lines[i].trim()) out.header.push(lines[i].trim());
    }

    for (const line of lines) {
        const l = line.trim();
        if (!l) continue;

        // Output file name
        if (!out.outputFilename && l.includes("output file name")) {
            out.outputFilename = firstToken(l);
            continue;
        }
        // Device out
        if (!out.deviceOut && l.includes("device out")) {
            out.deviceOut = intToken(l);
            continue;
        }
        // Number of problem sizes
        if (!out.numProblemSizes && l.includes("# of problems sizes")) {
            out.numProblemSizes = intToken(l);
            continue;
        }
        if (out.numProblemSizes && out.Ns.length === 0 && /\bNs\b/.test(l)) {
            out.Ns = numbersIn(l);
            continue;
        }
        // NBs
        if (!out.numNBs && l.includes("# of NBs")) {
            out.numNBs = intToken(l);
            continue;
        }
        if (out.numNBs && out.NBs.length === 0 && /\bNBs\b/.test(l)) {
            out.NBs = numbersIn(l);
            continue;
        }
        // PMAP
        if (out.pmap === null && /PMAP.*process mapping/i.test(l)) {
            out.pmap = intToken(l);
            continue;
        }
        // Process grids
        if (!out.numGrids && l.includes("# of process grids")) {
            out.numGrids = intToken(l);
            continue;
        }
        if (out.numGrids && out.Ps.length === 0 && /^\d+(\s+\d+)*/.test(l) &&
            /\bPs\b/.test(l)) {
            out.Ps = numbersIn(l);
            continue;
        }
        if (out.numGrids && out.Qs.length === 0 && /^\d+(\s+\d+)*/.test(l) &&
            /\bQs\b/.test(l)) {
            out.Qs = numbersIn(l);
            continue;
        }
        // Threshold (not swapping threshold)
        if (out.threshold === null &&
            /threshold/i.test(l) &&
            !/swapping threshold/i.test(l)) {
            out.threshold = floatToken(l);
            continue;
        }
        // PFACT
        if (!out.numPFACT && /# of panel fact/i.test(l)) {
            out.numPFACT = intToken(l);
            continue;
        }
        if (out.numPFACT && out.PFACTs.length === 0 && /PFACTs/i.test(l)) {
            out.PFACTs = numbersIn(l);
            continue;
        }
        // NBMIN
        if (!out.numNBMIN && /# of recursive stopping criterium/i.test(l)) {
            out.numNBMIN = intToken(l);
            continue;
        }
        if (out.numNBMIN && out.NBMINs.length === 0 && /NBMINs/i.test(l)) {
            out.NBMINs = numbersIn(l);
            continue;
        }
        // Panels in recursion
        if (out.numPanelsInRecursion === null &&
            /# of panels in recursion/i.test(l)) {
            out.numPanelsInRecursion = intToken(l);
            continue;
        }
        // NDIVs
        if (out.NDIVs.length === 0 && /\bNDIVs\b/i.test(l)) {
            out.NDIVs = numbersIn(l);
            continue;
        }
        // RFACT
        if (!out.numRFACT && /# of recursive panel fact/i.test(l)) {
            out.numRFACT = intToken(l);
            continue;
        }
        if (out.numRFACT && out.RFACTs.length === 0 && /RFACTs/i.test(l)) {
            out.RFACTs = numbersIn(l);
            continue;
        }
        // BCAST
        if (!out.numBCAST && /# of broadcast/i.test(l)) {
            out.numBCAST = intToken(l);
            continue;
        }
        if (out.numBCAST && out.BCASTs.length === 0 && /BCASTs/i.test(l)) {
            out.BCASTs = numbersIn(l);
            continue;
        }
        // DEPTHs
        if (!out.numDEPTH && /# of lookahead depth/i.test(l)) {
            out.numDEPTH = intToken(l);
            continue;
        }
        if (out.numDEPTH && out.DEPTHs.length === 0 && /DEPTHs/i.test(l)) {
            out.DEPTHs = numbersIn(l);
            continue;
        }
        // SWAP
        if (out.swapMode === null && /\bSWAP\b/.test(l)) {
            out.swapMode = intToken(l);
            continue;
        }
        if (out.swapThreshold === null && /swapping threshold/i.test(l)) {
            out.swapThreshold = intToken(l);
            continue;
        }
        // L1/U/equil/memory alignment
        if (out.L1 === null && /L1 .*form/i.test(l)) {
            out.L1 = intToken(l);
            continue;
        }
        if (out.U === null && /\bU\s+.*form/i.test(l)) {
            out.U = intToken(l);
            continue;
        }
        if (out.equilibration === null && /Equilibration/i.test(l)) {
            out.equilibration = intToken(l);
            continue;
        }
        if (out.memoryAlignment === null && /memory alignment/i.test(l)) {
            out.memoryAlignment = intToken(l);
            continue;
        }
    }

    return out;
}

// Parse SBATCH lines from .sh
function parseSbatch(shRaw) {
    const sb = {};
    const lines = shRaw.split(/\r?\n/);
    for (const l of lines) {
        const m = l.match(/^#SBATCH\s+--([^=\s]+)(?:=(.+))?/);
        if (m) {
            const key = m[1].trim();
            const val = (m[2] || "").trim();
            sb[key] = key === "nodes" ||
            key === "ntasks" ||
            key === "ntasks-per-node" ||
            key === "cpus-per-task"
                ? Number(val)
                : val || true;
        }
    }
    return sb;
}

// CPU HPL out parser
function parseOutCpu(raw) {
    const lines = raw.split(/\r?\n/);
    const runs = [];
    let cur = null;

    const tvRe =
        /^\s*([A-Z]{2}[^\s]*)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([0-9.]+)\s+([0-9.eE+\-]+)/;

    for (let i = 0; i < lines.length; i++) {
        const l = lines[i];

        const m = l.match(tvRe);
        if (m) {
            if (cur) runs.push(cur);
            cur = {
                tv: m[1],
                N: Number(m[2]),
                NB: Number(m[3]),
                P: Number(m[4]),
                Q: Number(m[5]),
                timeSec: Number(m[6]),
                gflops: Number(m[7]),
                startTime: null,
                endTime: null,
                residual: null,
                residualPassed: null,
            };
            continue;
        }

        if (cur) {
            const s = l.match(/HPL_pdgesv\(\)\s+start time\s+(.+)/);
            if (s) cur.startTime = s[1].trim();
            const e = l.match(/HPL_pdgesv\(\)\s+end time\s+(.+)/);
            if (e) cur.endTime = e[1].trim();
            const r = l.match(
                /\|\|Ax-b\|\|_oo.*=\s*([0-9.eE+\-]+).*?(PASSED|FAILED)/
            );
            if (r) {
                cur.residual = Number(r[1]);
                cur.residualPassed = r[2] === "PASSED";
            }
        }
    }
    if (cur) runs.push(cur);

    const summary = {
        testsTotal: null,
        testsPassed: null,
        testsFailed: null,
        testsSkipped: null,
    };
    const m = raw.match(
        /Finished\s+(\d+)\s+tests[\s\S]*?(\d+)\s+tests completed and passed[\s\S]*?(\d+)\s+tests completed and failed[\s\S]*?(\d+)\s+tests skipped/i
    );
    if (m) {
        summary.testsTotal = Number(m[1]);
        summary.testsPassed = Number(m[2]);
        summary.testsFailed = Number(m[3]);
        summary.testsSkipped = Number(m[4]);
    }

    return { runs, summary };
}

// NVIDIA HPL out parser
function parseOutNvidia(raw) {
    const lines = raw.split(/\r?\n/);
    const runs = [];
    let deviceInfo = {};
    const memInfo = { DEVICE: {}, HOST: {} };
    const traces = [];
    let section = null;

    const tvRe =
        /^\s*([A-Z]{2}[^\s]*)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([0-9.]+)\s+([0-9.eE+\-]+)\s+\(\s*([0-9.eE+\-]+)\s*\)/;

    for (let i = 0; i < lines.length; i++) {
        const l = lines[i];
        const tv = l.match(tvRe);
        if (tv) {
            runs.push({
                tv: tv[1],
                N: Number(tv[2]),
                NB: Number(tv[3]),
                P: Number(tv[4]),
                Q: Number(tv[5]),
                timeSec: Number(tv[6]),
                gflops: Number(tv[7]),
                gflopsPerGpu: Number(tv[8]),
            });
            continue;
        }

        if (/--- DEVICE INFO ---/.test(l)) {
            section = "DEVICE_INFO";
            continue;
        }
        if (/--- MEMORY INFO ---/.test(l)) {
            section = "MEM_INFO";
            continue;
        }
        if (/^DEVICE\s*$/.test(l)) {
            section = "MEM_DEVICE";
            continue;
        }
        if (/^HOST\s*$/.test(l)) {
            section = "MEM_HOST";
            continue;
        }
        if (/^\[HPL TRACE\]/.test(l)) {
            traces.push(l.trim());
            continue;
        }

        if (section === "DEVICE_INFO") {
            const p = l.match(/Peak clock frequency:\s+(\d+)\s*MHz/i);
            if (p) deviceInfo.peakClockMHz = Number(p[1]);
            const sm = l.match(/SM version\s*:\s*(\d+)/i);
            if (sm) deviceInfo.smVersion = Number(sm[1]);
            const nsm = l.match(/Number of SMs\s*:\s*(\d+)/i);
            if (nsm) deviceInfo.numSms = Number(nsm[1]);
        }

        if (section === "MEM_DEVICE" || section === "MEM_HOST") {
            const mm = l.match(
                /^\s*(System|HPL buffers|Used|Total)\s*=\s*([0-9.]+)\s*GiB\s*\(MIN\)\s*([0-9.]+)\s*GiB\s*\(MAX\)\s*([0-9.]+)\s*GiB\s*\(AVG\)/
            );
            if (mm) {
                const key = mm[1];
                const rec = {
                    minGiB: Number(mm[2]),
                    maxGiB: Number(mm[3]),
                    avgGiB: Number(mm[4]),
                };
                if (section === "MEM_DEVICE") memInfo.DEVICE[key] = rec;
                else memInfo.HOST[key] = rec;
            }
        }
    }

    let startTime = null;
    let endTime = null;
    const s = raw.match(/HPL_pdgesv\(\)\s+start time\s+(.+)/);
    if (s) startTime = s[1].trim();
    const e = raw.match(/HPL_pdgesv\(\)\s+end time\s+(.+)/);
    if (e) endTime = e[1].trim();

    let residual = null;
    let residualPassed = null;
    const r = raw.match(
        /\|\|Ax-b\|\|_oo.*=\s*([0-9.eE+\-]+).*?(PASSED|FAILED)/
    );
    if (r) {
        residual = Number(r[1]);
        residualPassed = r[2] === "PASSED";
    }

    const summary = {
        testsTotal: null,
        testsPassed: null,
        testsFailed: null,
        testsSkipped: null,
    };
    const m = raw.match(
        /Finished\s+(\d+)\s+tests[\s\S]*?(\d+)\s+tests completed and passed[\s\S]*?(\d+)\s+tests completed and failed[\s\S]*?(\d+)\s+tests skipped/i
    );
    if (m) {
        summary.testsTotal = Number(m[1]);
        summary.testsPassed = Number(m[2]);
        summary.testsFailed = Number(m[3]);
        summary.testsSkipped = Number(m[4]);
    }

    return {
        runs,
        summary,
        deviceInfo,
        memInfo,
        traces,
        startTime,
        endTime,
        residual,
        residualPassed,
    };
}

function bestFromRuns(runs) {
    if (!runs || !runs.length) return null;
    let best = runs[0];
    for (const r of runs) {
        if ((r.gflops ?? 0) > (best.gflops ?? 0)) best = r;
    }
    return {
        gflops: best.gflops ?? null,
        N: best.N ?? null,
        NB: best.NB ?? null,
        timeSec: best.timeSec ?? null,
    };
}

async function processSuite(suite, index) {
    const suiteRoot = path.join(SRC_ROOT, suite);
    if (!(await exists(suiteRoot))) return;

    const groups = await listDirs(suiteRoot);

    for (const group of groups) {
        const groupDir = path.join(suiteRoot, group);
        const runs = await listDirs(groupDir);
        for (const run of runs) {
            const runDir = path.join(groupDir, run);
            const files = await listFiles(runDir);

            // Variations: HPL.dat or HPT.dat, one .sh, .out, optional .err
            const datName =
                files.find((f) => /^HPL\.dat$/i.test(f)) ||
                files.find((f) => /^HPT\.dat$/i.test(f));
            const shName = files.find((f) => /\.sh$/i.test(f));
            const outName =
                files.find((f) => /\.out$/i.test(f)) || files.find((f) => /out/i.test(f));
            const errName =
                files.find((f) => /\.err$/i.test(f)) || files.find((f) => /err/i.test(f));

            const datRaw =
                datName ? await readFileSafe(path.join(runDir, datName)) : null;
            const shRaw = shName ? await readFileSafe(path.join(runDir, shName)) : null;
            const outRaw =
                outName ? await readFileSafe(path.join(runDir, outName)) : null;
            const errRaw =
                errName ? await readFileSafe(path.join(runDir, errName)) : null;

            const id = [suite, group, run].join("/");
            const baseParts = [suite, group, run];

            // Copy raw files to /tmp tree for publication
            if (datName) {
                await copyFileSafe(
                    path.join(runDir, datName),
                    toRawPathFS([...baseParts, datName])
                );
            }
            if (shName) {
                await copyFileSafe(
                    path.join(runDir, shName),
                    toRawPathFS([...baseParts, shName])
                );
            }
            if (outName) {
                await copyFileSafe(
                    path.join(runDir, outName),
                    toRawPathFS([...baseParts, outName])
                );
            }
            if (errName) {
                await copyFileSafe(
                    path.join(runDir, errName),
                    toRawPathFS([...baseParts, errName])
                );
            }

            const datParsed = datRaw ? parseHplDat(datRaw) : null;
            const sbatch = shRaw ? parseSbatch(shRaw) : null;

            let outParsed = null;
            if (outRaw) {
                outParsed =
                    suite === "HPL" ? parseOutCpu(outRaw) : parseOutNvidia(outRaw);
            }

            const runJson = {
                id,
                suite,
                group,
                run,
                dat: datRaw
                    ? {
                        raw: datRaw,
                        parsed: datParsed,
                        path: toWebRawPath([...baseParts, datName || "HPL.dat"]),
                    }
                    : null,
                job: shRaw
                    ? {
                        filename: shName,
                        raw: shRaw,
                        sbatch,
                        path: toWebRawPath([...baseParts, shName]),
                    }
                    : null,
                out: outRaw
                    ? {
                        path: toWebRawPath([...baseParts, outName]),
                        ...(outParsed || {}),
                    }
                    : null,
                err: errRaw
                    ? {
                        path: toWebRawPath([...baseParts, errName]),
                        size: errRaw.length,
                    }
                    : null,
                best: outParsed ? bestFromRuns(outParsed.runs) : null,
            };

            // Write per-run JSON
            const runJsonPath = toDataPath(["runs", ...baseParts, "run.json"]);
            await ensureDir(path.dirname(runJsonPath));
            await fs.writeFile(runJsonPath, JSON.stringify(runJson, null, 2));

            // Add to index
            index.push({
                id,
                suite,
                group,
                run,
                best: runJson.best,
                outSummary: runJson.out ? runJson.out.summary : null,
                hasErr: !!errRaw && errRaw.trim().length > 0,
            });
        }
    }
}

async function main() {
    await ensureDir(DATA_ROOT);
    await ensureDir(RAW_ROOT);
    const index = [];

    for (const suite of SUITES) {
        await processSuite(suite, index);
    }

    // Sort index by suite, then group, then run
    index.sort((a, b) => {
        if (a.suite !== b.suite) return a.suite < b.suite ? -1 : 1;
        if (a.group !== b.group) return a.group < b.group ? -1 : 1;
        return a.run < b.run ? -1 : 1;
    });

    await fs.writeFile(
        path.join(DATA_ROOT, "index.json"),
        JSON.stringify({ generatedAt: new Date().toISOString(), runs: index }, null, 2)
    );

    console.log("Collected data ->", OUT_ROOT);
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});