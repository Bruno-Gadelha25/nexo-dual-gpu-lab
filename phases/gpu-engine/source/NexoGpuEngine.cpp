// NEXO GPU ENGINE v0.1.0 (2026-11-19)
//
// Consome scheduler-policy.json (schemaVersion 1) gravado pelo NEXO GPU CONTROL,
// publica engine-status.json (ACK/erro) e, em modo --run, executa um job de
// computação do próprio NEXO dividido entre as GPUs permitidas pela política.
//
// O que ele faz:      distribui trabalho NEXO (shader determinístico) entre GTX 970 e GTX 750 Ti,
//                     com divisão calibrada pela velocidade medida de cada placa, e valida tudo no CPU.
// O que ele NÃO faz:  não altera jogos, drivers, dispositivos PnP, registro nem clocks.
//
// Uso:
//   NexoGpuEngine.exe [--policy <arq>] [--status <arq>] [--shader-dir <pasta>]
//                     [--run] [--elements N] [--iterations K] [--reps R] [--runs-csv <arq>] [--sustain S]
//   --sustain S: depois da medição, mantém trabalho distribuído por S segundos (demonstração visual; fora das estatísticas).
//   Sem --run: DRY RUN (lê e valida a política, encontra as GPUs, calcula o plano; nada é submetido).
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <dxgi1_6.h>
#include <d3d12.h>
#include <d3dcompiler.h>
#include <wrl/client.h>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>
#include <map>
#include <memory>
#include <stdexcept>
#include <algorithm>
#include <fstream>
#include <sstream>
#include <thread>
#include <atomic>
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "d3dcompiler.lib")
using Microsoft::WRL::ComPtr;

static const char* kEngineVersion = "0.1.0";

// ------------------------------------------------------------------ utilidades
static void check(HRESULT h, const char* what) {
    if (FAILED(h)) { char b[256]; sprintf_s(b, "%s falhou (HRESULT 0x%08X)", what, (unsigned)h); throw std::runtime_error(b); }
}
static double qpc() {
    static LARGE_INTEGER f = [] { LARGE_INTEGER x; QueryPerformanceFrequency(&x); return x; }();
    LARGE_INTEGER x; QueryPerformanceCounter(&x); return (double)x.QuadPart / (double)f.QuadPart;
}
static std::string nowIso() {
    SYSTEMTIME st; GetLocalTime(&st);
    TIME_ZONE_INFORMATION tz; DWORD r = GetTimeZoneInformation(&tz);
    long bias = -(tz.Bias + (r == TIME_ZONE_ID_DAYLIGHT ? tz.DaylightBias : 0));
    char b[64]; sprintf_s(b, "%04d-%02d-%02dT%02d:%02d:%02d.%03d%c%02ld:%02ld", st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute,
                          st.wSecond, st.wMilliseconds, bias >= 0 ? '+' : '-', labs(bias) / 60, labs(bias) % 60);
    return b;
}
static std::string narrow(const std::wstring& w) {
    if (w.empty()) return {};
    int n = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(), nullptr, 0, nullptr, nullptr);
    std::string s(n, '\0'); WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(), s.data(), n, nullptr, nullptr); return s;
}
static std::string jsonEscape(const std::string& s) {
    std::string o; o.reserve(s.size() + 8);
    for (unsigned char c : s) {
        switch (c) { case '"': o += "\\\""; break; case '\\': o += "\\\\"; break; case '\n': o += "\\n"; break; case '\r': o += "\\r"; break; case '\t': o += "\\t"; break;
            default: if (c < 0x20) { char b[8]; sprintf_s(b, "\\u%04x", c); o += b; } else o += (char)c; }
    }
    return o;
}
static double median(std::vector<double> v) {
    if (v.empty()) return 0; std::sort(v.begin(), v.end()); size_t n = v.size();
    return n % 2 ? v[n / 2] : (v[n / 2 - 1] + v[n / 2]) / 2;
}

// ------------------------------------------------------------------ JSON mínimo (leitura)
struct JVal {
    enum T { Null, Bool, Num, Str, Arr, Obj } t = Null;
    bool b = false; double n = 0; std::string s; std::vector<JVal> a; std::map<std::string, JVal> o;
    const JVal* get(const char* k) const { auto it = o.find(k); return it == o.end() ? nullptr : &it->second; }
};
struct JParser {
    const std::string& s; size_t i = 0;
    explicit JParser(const std::string& x) : s(x) {}
    [[noreturn]] void fail(const char* m) { char b[128]; sprintf_s(b, "JSON inválido na posição %zu: %s", i, m); throw std::runtime_error(b); }
    void ws() { while (i < s.size() && (s[i] == ' ' || s[i] == '\n' || s[i] == '\r' || s[i] == '\t')) ++i; }
    JVal parse() { ws(); JVal v = value(); ws(); if (i != s.size()) fail("conteúdo extra"); return v; }
    JVal value() {
        ws(); if (i >= s.size()) fail("fim inesperado");
        char c = s[i]; JVal v;
        if (c == '{') { v.t = JVal::Obj; ++i; ws(); if (s[i] == '}') { ++i; return v; }
            for (;;) { ws(); std::string k = str(); ws(); if (s[i++] != ':') fail("esperava ':'"); v.o[k] = value(); ws();
                if (s[i] == ',') { ++i; continue; } if (s[i] == '}') { ++i; return v; } fail("esperava ',' ou '}'"); } }
        if (c == '[') { v.t = JVal::Arr; ++i; ws(); if (s[i] == ']') { ++i; return v; }
            for (;;) { v.a.push_back(value()); ws(); if (s[i] == ',') { ++i; continue; } if (s[i] == ']') { ++i; return v; } fail("esperava ',' ou ']'"); } }
        if (c == '"') { v.t = JVal::Str; v.s = str(); return v; }
        if (!s.compare(i, 4, "true")) { i += 4; v.t = JVal::Bool; v.b = true; return v; }
        if (!s.compare(i, 5, "false")) { i += 5; v.t = JVal::Bool; return v; }
        if (!s.compare(i, 4, "null")) { i += 4; return v; }
        size_t st = i; if (s[i] == '-') ++i; while (i < s.size() && (isdigit((unsigned char)s[i]) || s[i] == '.' || s[i] == 'e' || s[i] == 'E' || s[i] == '+' || s[i] == '-')) ++i;
        if (st == i) fail("valor desconhecido"); v.t = JVal::Num; v.n = atof(s.substr(st, i - st).c_str()); return v;
    }
    static void utf8(std::string& o, unsigned cp) {
        if (cp < 0x80) o += (char)cp; else if (cp < 0x800) { o += (char)(0xC0 | (cp >> 6)); o += (char)(0x80 | (cp & 0x3F)); }
        else { o += (char)(0xE0 | (cp >> 12)); o += (char)(0x80 | ((cp >> 6) & 0x3F)); o += (char)(0x80 | (cp & 0x3F)); }
    }
    std::string str() {
        if (s[i] != '"') fail("esperava string"); ++i; std::string o;
        while (i < s.size() && s[i] != '"') {
            if (s[i] == '\\') { ++i; char e = s[i++];
                switch (e) { case 'n': o += '\n'; break; case 't': o += '\t'; break; case 'r': o += '\r'; break; case 'b': o += '\b'; break; case 'f': o += '\f'; break;
                    case 'u': { unsigned cp = (unsigned)strtoul(s.substr(i, 4).c_str(), nullptr, 16); i += 4; utf8(o, cp); break; }
                    default: o += e; } }
            else o += s[i++];
        }
        if (i >= s.size()) fail("string sem fim"); ++i; return o;
    }
};

// ------------------------------------------------------------------ política
struct Policy {
    std::string mode, primaryGpu, updatedAt;
    bool distributionEnabled = false, hardwareChangesAllowed = false;
    std::vector<std::string> allowedDeviceIds; // "13C2", "1380"
};
static Policy loadPolicy(const std::wstring& path) {
    std::ifstream f(path, std::ios::binary);
    if (!f) throw std::runtime_error("política não encontrada: " + narrow(path) + " (clique num modo no NEXO GPU CONTROL)");
    std::stringstream ss; ss << f.rdbuf(); std::string txt = ss.str();
    if (txt.size() >= 3 && (unsigned char)txt[0] == 0xEF && (unsigned char)txt[1] == 0xBB && (unsigned char)txt[2] == 0xBF) txt.erase(0, 3);
    JVal j = JParser(txt).parse();
    if (j.t != JVal::Obj) throw std::runtime_error("política: raiz não é objeto");
    auto req = [&](const char* k, JVal::T t) -> const JVal& { const JVal* v = j.get(k); if (!v || v->t != t) throw std::runtime_error(std::string("política: campo ausente ou com tipo errado: ") + k); return *v; };
    if ((int)req("schemaVersion", JVal::Num).n != 1) throw std::runtime_error("política: schemaVersion não suportada (esperado 1)");
    Policy p;
    p.mode = req("mode", JVal::Str).s; p.primaryGpu = req("primaryGpu", JVal::Str).s; p.updatedAt = req("updatedAt", JVal::Str).s;
    p.distributionEnabled = req("distributionEnabled", JVal::Bool).b; p.hardwareChangesAllowed = req("hardwareDeviceChangesAllowed", JVal::Bool).b;
    for (const JVal& a : req("allowedAdapters", JVal::Arr).a) { const JVal* d = a.get("deviceId"); if (!d || d->t != JVal::Str) throw std::runtime_error("política: adapter sem deviceId"); p.allowedDeviceIds.push_back(d->s); }
    static const char* modes[] = {"DUAL_ON", "DUAL_OFF", "GTX970_ONLY", "GTX750TI_ONLY"};
    if (std::find_if(std::begin(modes), std::end(modes), [&](const char* m) { return p.mode == m; }) == std::end(modes)) throw std::runtime_error("política: modo desconhecido " + p.mode);
    if (p.hardwareChangesAllowed) throw std::runtime_error("política pede hardwareDeviceChangesAllowed=true; o Engine recusa mudanças de hardware");
    if (p.allowedDeviceIds.empty()) throw std::runtime_error("política sem adaptadores permitidos");
    if (p.mode == "DUAL_ON" && (!p.distributionEnabled || p.allowedDeviceIds.size() < 2)) throw std::runtime_error("política DUAL_ON inconsistente (distribuição desligada ou menos de 2 adaptadores)");
    if (p.mode != "DUAL_ON" && (p.distributionEnabled || p.allowedDeviceIds.size() != 1)) throw std::runtime_error("política " + p.mode + " inconsistente (esperado 1 adaptador e distribuição desligada)");
    return p;
}

// ------------------------------------------------------------------ GPU
static uint32_t refValue(uint32_t index, uint32_t seed, uint32_t iters) {
    uint32_t v = index ^ seed;
    for (uint32_t i = 0; i < iters; ++i) { v ^= v >> 13; v *= 0x85ebca6b; v ^= v << 7; v += (i ^ index) * 0xc2b2ae35; }
    return v;
}
struct Gpu {
    std::string key, name; unsigned deviceId = 0;
    ComPtr<IDXGIAdapter1> adapter;
    ComPtr<ID3D12Device> dev; ComPtr<ID3D12CommandQueue> queue; ComPtr<ID3D12CommandAllocator> alloc; ComPtr<ID3D12GraphicsCommandList> list;
    ComPtr<ID3D12Fence> fence; HANDLE ev = nullptr; UINT64 fv = 0;
    ComPtr<ID3D12RootSignature> root; ComPtr<ID3D12PipelineState> pso; ComPtr<ID3D12DescriptorHeap> heap;
    ComPtr<ID3D12Resource> output, readback; UINT capacity = 0;
    ~Gpu() { if (fence && ev && fv) { if (fence->GetCompletedValue() < fv) { fence->SetEventOnCompletion(fv, ev); WaitForSingleObject(ev, 5000); } } if (ev) CloseHandle(ev); }
    void init(ID3DBlob* cs, UINT maxN) {
        capacity = maxN;
        check(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&dev)), "D3D12CreateDevice");
        D3D12_COMMAND_QUEUE_DESC q{}; q.Type = D3D12_COMMAND_LIST_TYPE_COMPUTE;
        check(dev->CreateCommandQueue(&q, IID_PPV_ARGS(&queue)), "CreateCommandQueue");
        check(dev->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_COMPUTE, IID_PPV_ARGS(&alloc)), "CreateCommandAllocator");
        check(dev->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_COMPUTE, alloc.Get(), nullptr, IID_PPV_ARGS(&list)), "CreateCommandList");
        check(list->Close(), "Close");
        check(dev->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&fence)), "CreateFence");
        ev = CreateEventW(nullptr, FALSE, FALSE, nullptr); if (!ev) throw std::runtime_error("CreateEvent");
        D3D12_DESCRIPTOR_RANGE range{}; range.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV; range.NumDescriptors = 1;
        D3D12_ROOT_PARAMETER rp[2]{};
        rp[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS; rp[0].Constants = {0, 0, 4};
        rp[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE; rp[1].DescriptorTable = {1, &range};
        D3D12_ROOT_SIGNATURE_DESC rs{}; rs.NumParameters = 2; rs.pParameters = rp;
        ComPtr<ID3DBlob> blob, err; check(D3D12SerializeRootSignature(&rs, D3D_ROOT_SIGNATURE_VERSION_1, &blob, &err), "SerializeRootSignature");
        check(dev->CreateRootSignature(0, blob->GetBufferPointer(), blob->GetBufferSize(), IID_PPV_ARGS(&root)), "CreateRootSignature");
        D3D12_COMPUTE_PIPELINE_STATE_DESC pd{}; pd.pRootSignature = root.Get(); pd.CS = {cs->GetBufferPointer(), cs->GetBufferSize()};
        check(dev->CreateComputePipelineState(&pd, IID_PPV_ARGS(&pso)), "CreateComputePipelineState");
        D3D12_DESCRIPTOR_HEAP_DESC dh{}; dh.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV; dh.NumDescriptors = 1; dh.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
        check(dev->CreateDescriptorHeap(&dh, IID_PPV_ARGS(&heap)), "CreateDescriptorHeap");
        auto buffer = [&](D3D12_HEAP_TYPE t, D3D12_RESOURCE_FLAGS fl, D3D12_RESOURCE_STATES st, ComPtr<ID3D12Resource>& r, const char* w) {
            D3D12_HEAP_PROPERTIES hp{}; hp.Type = t;
            D3D12_RESOURCE_DESC rd{}; rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER; rd.Width = (UINT64)maxN * 4; rd.Height = 1; rd.DepthOrArraySize = 1;
            rd.MipLevels = 1; rd.SampleDesc.Count = 1; rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR; rd.Flags = fl;
            check(dev->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd, st, nullptr, IID_PPV_ARGS(&r)), w);
        };
        buffer(D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_UNORDERED_ACCESS, output, "buffer de saída");
        buffer(D3D12_HEAP_TYPE_READBACK, D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_COPY_DEST, readback, "buffer de leitura");
        D3D12_UNORDERED_ACCESS_VIEW_DESC uv{}; uv.ViewDimension = D3D12_UAV_DIMENSION_BUFFER; uv.Buffer.NumElements = maxN; uv.Buffer.StructureByteStride = 4;
        dev->CreateUnorderedAccessView(output.Get(), nullptr, &uv, heap->GetCPUDescriptorHandleForHeapStart());
    }
    void encode(UINT base, UINT count, UINT seed, UINT iters) {
        if (count > capacity) throw std::runtime_error(name + ": partição maior que o buffer");
        check(alloc->Reset(), "alloc Reset"); check(list->Reset(alloc.Get(), pso.Get()), "list Reset");
        list->SetComputeRootSignature(root.Get());
        ID3D12DescriptorHeap* hs[] = {heap.Get()}; list->SetDescriptorHeaps(1, hs);
        UINT c[4] = {base, count, seed, iters}; list->SetComputeRoot32BitConstants(0, 4, c, 0);
        list->SetComputeRootDescriptorTable(1, heap->GetGPUDescriptorHandleForHeapStart());
        list->Dispatch((count + 255) / 256, 1, 1);
        D3D12_RESOURCE_BARRIER b{}; b.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION; b.Transition.pResource = output.Get();
        b.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        b.Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS; b.Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_SOURCE;
        list->ResourceBarrier(1, &b);
        list->CopyBufferRegion(readback.Get(), 0, output.Get(), 0, (UINT64)count * 4);
        std::swap(b.Transition.StateBefore, b.Transition.StateAfter); list->ResourceBarrier(1, &b);
        check(list->Close(), "list Close");
    }
    void submit() {
        ID3D12CommandList* ls[] = {list.Get()}; queue->ExecuteCommandLists(1, ls);
        check(queue->Signal(fence.Get(), ++fv), "Signal"); check(fence->SetEventOnCompletion(fv, ev), "SetEventOnCompletion");
    }
    void wait() { if (WaitForSingleObject(ev, 15000) != WAIT_OBJECT_0) throw std::runtime_error(name + ": GPU não respondeu em 15 s"); }
    // Validação completa, em paralelo no CPU.
    bool verify(UINT base, UINT count, UINT seed, UINT iters) {
        void* p = nullptr; D3D12_RANGE r{0, (SIZE_T)count * 4}; check(readback->Map(0, &r, &p), "Map readback");
        const uint32_t* x = (const uint32_t*)p; std::atomic<bool> ok{true};
        unsigned nt = std::max(1u, std::thread::hardware_concurrency()); std::vector<std::thread> th;
        for (unsigned t = 0; t < nt; ++t) th.emplace_back([&, t] {
            for (UINT i = t; i < count && ok.load(std::memory_order_relaxed); i += nt) if (x[i] != refValue(base + i, seed, iters)) { ok = false; }
        });
        for (auto& t : th) t.join();
        D3D12_RANGE w{0, 0}; readback->Unmap(0, &w); return ok;
    }
};

struct Args {
    std::wstring policy, status, shaderDir, runsCsv; bool run = false; UINT elements = 8000000, iterations = 256, reps = 5, sustain = 0;
};
static std::wstring exeDir() { wchar_t b[MAX_PATH]; GetModuleFileNameW(nullptr, b, MAX_PATH); std::wstring s(b); return s.substr(0, s.find_last_of(L"\\/")); }
static Args parseArgs(int argc, wchar_t** argv) {
    Args a; std::wstring d = exeDir();
    a.policy = d + L"\\scheduler-policy.json"; a.status = d + L"\\engine-status.json"; a.shaderDir = d; a.runsCsv = d + L"\\engine-runs.csv";
    for (int i = 1; i < argc; ++i) {
        std::wstring k = argv[i]; auto next = [&]() -> std::wstring { if (i + 1 >= argc) throw std::runtime_error("argumento sem valor: " + narrow(k)); return argv[++i]; };
        auto num = [&](UINT lo, UINT hi) { unsigned long v = wcstoul(next().c_str(), nullptr, 10); if (v < lo || v > hi) throw std::runtime_error("valor fora da faixa para " + narrow(k)); return (UINT)v; };
        if (k == L"--policy") a.policy = next(); else if (k == L"--status") a.status = next(); else if (k == L"--shader-dir") a.shaderDir = next();
        else if (k == L"--runs-csv") a.runsCsv = next(); else if (k == L"--run") a.run = true;
        else if (k == L"--elements") a.elements = num(1024, 16000000); else if (k == L"--iterations") a.iterations = num(1, 4096); else if (k == L"--reps") a.reps = num(1, 50); else if (k == L"--sustain") a.sustain = num(0, 60);
        else throw std::runtime_error("argumento desconhecido: " + narrow(k));
    }
    return a;
}

// ------------------------------------------------------------------ status
struct Status {
    std::string ack = "PENDING", error, policyMode, policyUpdatedAt, mode = "DRY_RUN";
    std::vector<std::pair<std::string, std::string>> adapters; // key, name
    std::vector<std::pair<std::string, double>> plan;          // key, share
    std::string lastRunJson = "null";
};
static void writeStatus(const std::wstring& path, const Status& s) {
    std::ostringstream o;
    o << "{\n  \"schemaVersion\": 1,\n  \"engineVersion\": \"" << kEngineVersion << "\",\n  \"updatedAt\": \"" << nowIso() << "\",\n"
      << "  \"executionMode\": \"" << s.mode << "\",\n  \"acknowledgement\": \"" << s.ack << "\",\n  \"error\": " << (s.error.empty() ? "null" : "\"" + jsonEscape(s.error) + "\"") << ",\n"
      << "  \"policyMode\": " << (s.policyMode.empty() ? "null" : "\"" + s.policyMode + "\"") << ",\n  \"policyUpdatedAt\": " << (s.policyUpdatedAt.empty() ? "null" : "\"" + jsonEscape(s.policyUpdatedAt) + "\"") << ",\n"
      << "  \"adaptersFound\": [";
    for (size_t i = 0; i < s.adapters.size(); ++i) o << (i ? ", " : "") << "{\"key\": \"" << s.adapters[i].first << "\", \"name\": \"" << jsonEscape(s.adapters[i].second) << "\"}";
    o << "],\n  \"plan\": [";
    for (size_t i = 0; i < s.plan.size(); ++i) { char b[64]; sprintf_s(b, "%.4f", s.plan[i].second); o << (i ? ", " : "") << "{\"key\": \"" << s.plan[i].first << "\", \"share\": " << b << "}"; }
    o << "],\n  \"hardwareDeviceChanges\": false,\n  \"lastRun\": " << s.lastRunJson << "\n}\n";
    std::wstring tmp = path + L".tmp";
    { std::ofstream f(tmp, std::ios::binary | std::ios::trunc); if (!f) throw std::runtime_error("não consegui gravar engine-status"); f << o.str(); }
    if (!MoveFileExW(tmp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) throw std::runtime_error("não consegui substituir engine-status.json");
}

// ------------------------------------------------------------------ principal
int wmain(int argc, wchar_t** argv) {
    SetConsoleOutputCP(CP_UTF8); setvbuf(stdout, nullptr, _IONBF, 0);
    Args args; Status st;
    try { args = parseArgs(argc, argv); } catch (const std::exception& e) { fprintf(stderr, "ERRO: %s\n", e.what()); return 2; }
    st.mode = args.run ? "RUN" : "DRY_RUN";
    try {
        Policy pol = loadPolicy(args.policy);
        st.policyMode = pol.mode; st.policyUpdatedAt = pol.updatedAt;
        printf("NEXO GPU ENGINE %s | modo %s | política %s (%s)\n", kEngineVersion, st.mode.c_str(), pol.mode.c_str(), pol.updatedAt.c_str());

        // GPUs por DeviceId (nunca pela ordem de enumeração)
        ComPtr<IDXGIFactory6> fac; check(CreateDXGIFactory2(0, IID_PPV_ARGS(&fac)), "CreateDXGIFactory2");
        struct Known { unsigned id; const char* key; const char* hex; };
        const Known known[] = {{0x13C2, "GTX970", "13C2"}, {0x1380, "GTX750TI", "1380"}};
        std::vector<std::unique_ptr<Gpu>> gpus;
        for (UINT i = 0;; ++i) {
            ComPtr<IDXGIAdapter1> a; HRESULT h = fac->EnumAdapters1(i, &a); if (h == DXGI_ERROR_NOT_FOUND) break; check(h, "EnumAdapters1");
            DXGI_ADAPTER_DESC1 d{}; a->GetDesc1(&d); if (d.VendorId != 0x10DE) continue;
            for (const Known& k : known) if (d.DeviceId == k.id) {
                bool allowed = std::find(pol.allowedDeviceIds.begin(), pol.allowedDeviceIds.end(), std::string(k.hex)) != pol.allowedDeviceIds.end();
                st.adapters.push_back({k.key, narrow(d.Description)});
                if (allowed) { auto g = std::make_unique<Gpu>(); g->key = k.key; g->name = narrow(d.Description); g->deviceId = k.id; g->adapter = a; gpus.push_back(std::move(g)); }
            }
        }
        if (gpus.size() != pol.allowedDeviceIds.size()) throw std::runtime_error("nem todas as GPUs permitidas pela política foram encontradas");
        // Principal primeiro
        std::stable_sort(gpus.begin(), gpus.end(), [&](const auto& x, const auto& y) { return x->key == pol.primaryGpu && y->key != pol.primaryGpu; });
        st.ack = "ACCEPTED";
        if (!args.run) {
            for (auto& g : gpus) st.plan.push_back({g->key, 1.0 / gpus.size()});
            writeStatus(args.status, st);
            printf("DRY RUN: política aceita; %zu GPU(s) permitida(s); nenhum trabalho submetido. A divisão real é calibrada em --run.\nRESULT=PASS\n", gpus.size());
            return 0;
        }

        // ---------- execução ----------
        ComPtr<ID3DBlob> cs; check(D3DReadFileToBlob((args.shaderDir + L"\\compute.cso").c_str(), &cs), "ler compute.cso");
        const UINT N = args.elements, K = args.iterations, seed = 0x4E45584F; // "NEXO"
        for (auto& g : gpus) g->init(cs.Get(), N);

        // Calibração: cada GPU sozinha com 1/8 do job (mesmas iterações, com cópia), mediana de 3.
        const UINT calN = std::max<UINT>(N / 8, 65536);
        std::vector<double> perElem;
        for (auto& g : gpus) {
            std::vector<double> t;
            for (int r = 0; r < 4; ++r) { double a = qpc(); g->encode(0, calN, seed, K); g->submit(); g->wait(); if (r) t.push_back((qpc() - a) * 1000); }
            perElem.push_back(median(t) / calN);
        }
        double sumRate = 0; for (double p : perElem) sumRate += 1.0 / p;
        std::vector<UINT> part; UINT given = 0;
        for (size_t i = 0; i < gpus.size(); ++i) {
            double share = (1.0 / perElem[i]) / sumRate; st.plan.push_back({gpus[i]->key, share});
            UINT n = (i + 1 == gpus.size()) ? N - given : (UINT)(N * share + 0.5); part.push_back(n); given += n;
        }
        for (size_t i = 0; i < gpus.size(); ++i) printf("calibração %-9s %.3f ns/elemento -> %.1f%% (%u elementos)\n", gpus[i]->key.c_str(), perElem[i] * 1e6, st.plan[i].second * 100, part[i]);

        // Job distribuído vs. GPU principal sozinha, ordem ABBA, validação completa de cada rodada medida.
        // Cada rodada medida é precedida de uma rodada idêntica NÃO cronometrada ("pre-roll"), para que a
        // pausa da validação no CPU não deixe as placas caírem de clock antes da medição.
        std::vector<double> tDist, tSolo; bool allOk = true;
        auto prerollDist = [&]() { UINT base = 0; for (size_t i = 0; i < gpus.size(); ++i) { gpus[i]->encode(base, part[i], seed, K); base += part[i]; } for (auto& g : gpus) g->submit(); for (auto& g : gpus) g->wait(); };
        auto prerollSolo = [&]() { gpus[0]->encode(0, N, seed, K); gpus[0]->submit(); gpus[0]->wait(); };
        auto runDist = [&]() {
            prerollDist();
            UINT base = 0; double a = qpc();
            for (size_t i = 0; i < gpus.size(); ++i) { gpus[i]->encode(base, part[i], seed, K); base += part[i]; }
            for (auto& g : gpus) g->submit();
            for (auto& g : gpus) g->wait();
            double ms = (qpc() - a) * 1000; base = 0;
            for (size_t i = 0; i < gpus.size(); ++i) { allOk = gpus[i]->verify(base, part[i], seed, K) && allOk; base += part[i]; }
            return ms;
        };
        auto runSolo = [&]() { prerollSolo(); double a = qpc(); gpus[0]->encode(0, N, seed, K); gpus[0]->submit(); gpus[0]->wait(); double ms = (qpc() - a) * 1000; allOk = gpus[0]->verify(0, N, seed, K) && allOk; return ms; };
        runDist(); if (gpus.size() > 1) runSolo(); // aquecimento
        for (UINT r = 0; r < args.reps; ++r) {
            bool distFirst = (r % 2 == 0) == ((r / 2) % 2 == 0); // A B B A A B B A ...
            if (gpus.size() < 2) { tDist.push_back(runDist()); continue; }
            if (distFirst) { tDist.push_back(runDist()); tSolo.push_back(runSolo()); } else { tSolo.push_back(runSolo()); tDist.push_back(runDist()); }
        }
        printf("amostras distribuído (ms):"); for (double v : tDist) printf(" %.2f", v); printf("\n");
        if (!tSolo.empty()) { printf("amostras %s sozinha (ms):", gpus[0]->key.c_str()); for (double v : tSolo) printf(" %.2f", v); printf("\n"); }
        if (!allOk) throw std::runtime_error("validação falhou: algum elemento diferente da referência");

        // Demonstração visual opcional: trabalho distribuído contínuo por N segundos (curvas sobem no painel).
        // Não entra nas estatísticas; a última rodada é validada por completo.
        UINT sustainJobs = 0;
        if (args.sustain > 0) {
            double end = qpc() + args.sustain;
            while (qpc() < end) { prerollDist(); ++sustainJobs; }
            UINT base = 0; for (size_t i = 0; i < gpus.size(); ++i) { allOk = gpus[i]->verify(base, part[i], seed, K) && allOk; base += part[i]; }
            if (!allOk) throw std::runtime_error("validação falhou na demonstração contínua");
            printf("demonstração contínua: %u jobs em %u s, última rodada validada\n", sustainJobs, args.sustain);
        }

        double md = median(tDist), ms = tSolo.empty() ? md : median(tSolo);
        double gain = tSolo.empty() ? 0.0 : 100.0 * (1.0 - md / ms);
        char run[1024];
        sprintf_s(run, "{\"at\": \"%s\", \"elements\": %u, \"iterations\": %u, \"reps\": %u, \"distributedMedianMs\": %.4f, \"primaryAloneMedianMs\": %s, \"reductionVsPrimaryPct\": %s, \"validation\": \"PASS\", \"note\": \"job sintético do NEXO; não acelera jogos\"}",
                  nowIso().c_str(), N, K, args.reps, md, tSolo.empty() ? "null" : std::to_string(ms).c_str(), tSolo.empty() ? "null" : std::to_string(gain).c_str());
        st.lastRunJson = run;
        writeStatus(args.status, st);
        bool header = GetFileAttributesW(args.runsCsv.c_str()) == INVALID_FILE_ATTRIBUTES;
        { std::ofstream f(args.runsCsv, std::ios::app); if (header) f << "at,policy_mode,elements,iterations,reps,gpus,shares,distributed_median_ms,primary_alone_median_ms,reduction_pct,validation\n";
          std::string shares; for (auto& p : st.plan) { char b[48]; sprintf_s(b, "%s%s=%.3f", shares.empty() ? "" : ";", p.first.c_str(), p.second); shares += b; }
          f << nowIso() << "," << pol.mode << "," << N << "," << K << "," << args.reps << "," << gpus.size() << "," << shares << "," << md << "," << (tSolo.empty() ? std::string("") : std::to_string(ms)) << "," << (tSolo.empty() ? std::string("") : std::to_string(gain)) << ",PASS\n"; }
        printf("job: %u elementos x %u iterações | distribuído %.3f ms", N, K, md);
        if (!tSolo.empty()) printf(" | %s sozinha %.3f ms | redução %.1f%%", gpus[0]->key.c_str(), ms, gain);
        printf(" | validação PASS\nRESULT=PASS\n");
        return 0;
    } catch (const std::exception& e) {
        st.ack = st.ack == "ACCEPTED" ? "ACCEPTED" : "REJECTED"; st.error = e.what();
        try { writeStatus(args.status, st); } catch (...) {}
        fprintf(stderr, "ERRO: %s\nRESULT=FAIL\n", e.what()); return 1;
    }
}
