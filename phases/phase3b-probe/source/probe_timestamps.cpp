// Sonda Fase 3b: separa tempo de kernel e tempo de cópia GPU->host com
// timestamps de GPU (D3D12_QUERY_TYPE_TIMESTAMP), nas duas GPUs.
// Mesmo shader da Fase 3 (compute.cso). Seleciona GPUs por DeviceId.
// Uso: probe_timestamps.exe <pasta_com_compute.cso> <csv_saida>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <dxgi1_6.h>
#include <d3d12.h>
#include <d3dcompiler.h>
#include <wrl/client.h>
#include <cstdio>
#include <cstdint>
#include <string>
#include <vector>
#include <stdexcept>
#include <random>
#include <algorithm>
#include <fstream>
#include <cstring>
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "d3dcompiler.lib")
using Microsoft::WRL::ComPtr;

static void check(HRESULT h, const char* what) {
    if (FAILED(h)) { char b[256]; sprintf_s(b, "%s failed 0x%08X", what, (unsigned)h); throw std::runtime_error(b); }
}
static double qpc() {
    LARGE_INTEGER x, f; QueryPerformanceCounter(&x); QueryPerformanceFrequency(&f);
    return (double)x.QuadPart / (double)f.QuadPart;
}
static uint32_t expected(uint32_t index, uint32_t seed, uint32_t iters) {
    uint32_t v = index ^ seed;
    for (uint32_t i = 0; i < iters; ++i) { v ^= v >> 13; v *= 0x85ebca6b; v ^= v << 7; v += (i ^ index) * 0xc2b2ae35; }
    return v;
}

struct Gpu {
    std::string name;
    ComPtr<ID3D12Device> dev;
    ComPtr<ID3D12CommandQueue> queue;
    ComPtr<ID3D12CommandAllocator> alloc;
    ComPtr<ID3D12GraphicsCommandList> list;
    ComPtr<ID3D12Fence> fence;
    HANDLE ev = nullptr;
    UINT64 fv = 0;
    ComPtr<ID3D12RootSignature> root;
    ComPtr<ID3D12PipelineState> pso;
    ComPtr<ID3D12DescriptorHeap> heap;
    ComPtr<ID3D12Resource> output, readback, tsResolve;
    ComPtr<ID3D12QueryHeap> qheap;
    UINT64 tsFreq = 0;
    ~Gpu() { if (fence && ev) { /* drena a fila antes de liberar */ fence->SetEventOnCompletion(fv, ev); WaitForSingleObject(ev, 5000); } if (ev) CloseHandle(ev); }

    void init(IDXGIAdapter1* a, ID3DBlob* cs, UINT maxN) {
        check(D3D12CreateDevice(a, D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&dev)), "CreateDevice");
        D3D12_COMMAND_QUEUE_DESC q{}; q.Type = D3D12_COMMAND_LIST_TYPE_COMPUTE;
        check(dev->CreateCommandQueue(&q, IID_PPV_ARGS(&queue)), "CreateCommandQueue");
        check(queue->GetTimestampFrequency(&tsFreq), "GetTimestampFrequency");
        check(dev->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_COMPUTE, IID_PPV_ARGS(&alloc)), "CreateCommandAllocator");
        check(dev->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_COMPUTE, alloc.Get(), nullptr, IID_PPV_ARGS(&list)), "CreateCommandList");
        check(list->Close(), "Close");
        check(dev->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&fence)), "CreateFence");
        ev = CreateEventW(nullptr, FALSE, FALSE, nullptr);
        if (!ev) throw std::runtime_error("CreateEvent");

        D3D12_DESCRIPTOR_RANGE range{}; range.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV; range.NumDescriptors = 1;
        D3D12_ROOT_PARAMETER rp[2]{};
        rp[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS; rp[0].Constants = {0, 0, 4};
        rp[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE; rp[1].DescriptorTable = {1, &range};
        D3D12_ROOT_SIGNATURE_DESC rs{}; rs.NumParameters = 2; rs.pParameters = rp;
        ComPtr<ID3DBlob> blob, err;
        check(D3D12SerializeRootSignature(&rs, D3D_ROOT_SIGNATURE_VERSION_1, &blob, &err), "SerializeRootSignature");
        check(dev->CreateRootSignature(0, blob->GetBufferPointer(), blob->GetBufferSize(), IID_PPV_ARGS(&root)), "CreateRootSignature");
        D3D12_COMPUTE_PIPELINE_STATE_DESC pd{}; pd.pRootSignature = root.Get(); pd.CS = {cs->GetBufferPointer(), cs->GetBufferSize()};
        check(dev->CreateComputePipelineState(&pd, IID_PPV_ARGS(&pso)), "CreatePSO");

        D3D12_DESCRIPTOR_HEAP_DESC dh{}; dh.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV; dh.NumDescriptors = 1; dh.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
        check(dev->CreateDescriptorHeap(&dh, IID_PPV_ARGS(&heap)), "CreateDescriptorHeap");

        auto buffer = [&](D3D12_HEAP_TYPE t, UINT64 bytes, D3D12_RESOURCE_FLAGS f, D3D12_RESOURCE_STATES s, ComPtr<ID3D12Resource>& r, const char* w) {
            D3D12_HEAP_PROPERTIES hp{}; hp.Type = t;
            D3D12_RESOURCE_DESC rd{}; rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER; rd.Width = bytes; rd.Height = 1; rd.DepthOrArraySize = 1;
            rd.MipLevels = 1; rd.SampleDesc.Count = 1; rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR; rd.Flags = f;
            check(dev->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd, s, nullptr, IID_PPV_ARGS(&r)), w);
        };
        buffer(D3D12_HEAP_TYPE_DEFAULT, (UINT64)maxN * 4, D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_UNORDERED_ACCESS, output, "output");
        buffer(D3D12_HEAP_TYPE_READBACK, (UINT64)maxN * 4, D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_COPY_DEST, readback, "readback");
        buffer(D3D12_HEAP_TYPE_READBACK, 3 * sizeof(UINT64), D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_COPY_DEST, tsResolve, "tsResolve");
        D3D12_UNORDERED_ACCESS_VIEW_DESC uv{}; uv.ViewDimension = D3D12_UAV_DIMENSION_BUFFER; uv.Buffer.NumElements = maxN; uv.Buffer.StructureByteStride = 4;
        dev->CreateUnorderedAccessView(output.Get(), nullptr, &uv, heap->GetCPUDescriptorHandleForHeapStart());
        D3D12_QUERY_HEAP_DESC qh{}; qh.Type = D3D12_QUERY_HEAP_TYPE_TIMESTAMP; qh.Count = 3;
        check(dev->CreateQueryHeap(&qh, IID_PPV_ARGS(&qheap)), "CreateQueryHeap");
    }

    // ts0 | Dispatch | barreira UAV->COPY_SOURCE | ts1 | [cópia p/ READBACK] | barreira COPY_SOURCE->UAV | ts2
    void encode(UINT base, UINT count, UINT seed, UINT iters, bool withCopy) {
        check(alloc->Reset(), "alloc Reset");
        check(list->Reset(alloc.Get(), pso.Get()), "list Reset");
        list->SetComputeRootSignature(root.Get());
        ID3D12DescriptorHeap* hs[] = {heap.Get()}; list->SetDescriptorHeaps(1, hs);
        UINT c[4] = {base, count, seed, iters}; list->SetComputeRoot32BitConstants(0, 4, c, 0);
        list->SetComputeRootDescriptorTable(1, heap->GetGPUDescriptorHandleForHeapStart());
        list->EndQuery(qheap.Get(), D3D12_QUERY_TYPE_TIMESTAMP, 0);
        list->Dispatch((count + 255) / 256, 1, 1);
        D3D12_RESOURCE_BARRIER b{}; b.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION; b.Transition.pResource = output.Get();
        b.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        b.Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS; b.Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_SOURCE;
        list->ResourceBarrier(1, &b);
        list->EndQuery(qheap.Get(), D3D12_QUERY_TYPE_TIMESTAMP, 1);
        if (withCopy) list->CopyBufferRegion(readback.Get(), 0, output.Get(), 0, (UINT64)count * 4);
        std::swap(b.Transition.StateBefore, b.Transition.StateAfter);
        list->ResourceBarrier(1, &b);
        list->EndQuery(qheap.Get(), D3D12_QUERY_TYPE_TIMESTAMP, 2);
        list->ResolveQueryData(qheap.Get(), D3D12_QUERY_TYPE_TIMESTAMP, 0, 3, tsResolve.Get(), 0);
        check(list->Close(), "list Close");
    }
    void submit() {
        ID3D12CommandList* ls[] = {list.Get()}; queue->ExecuteCommandLists(1, ls);
        check(queue->Signal(fence.Get(), ++fv), "Signal");
        check(fence->SetEventOnCompletion(fv, ev), "SetEventOnCompletion");
    }
    void wait() { if (WaitForSingleObject(ev, 10000) != WAIT_OBJECT_0) throw std::runtime_error(name + ": timeout 10 s"); }
    void times(double& kernelMs, double& copyMs) {
        void* p = nullptr; D3D12_RANGE r{0, 3 * sizeof(UINT64)};
        check(tsResolve->Map(0, &r, &p), "Map ts");
        auto* t = (UINT64*)p; kernelMs = (double)(t[1] - t[0]) * 1000.0 / tsFreq; copyMs = (double)(t[2] - t[1]) * 1000.0 / tsFreq;
        D3D12_RANGE w{0, 0}; tsResolve->Unmap(0, &w);
    }
    bool verify(UINT base, UINT count, const std::vector<uint32_t>& ref) {
        void* p = nullptr; D3D12_RANGE r{0, (SIZE_T)count * 4};
        check(readback->Map(0, &r, &p), "Map readback");
        auto* x = (uint32_t*)p; bool ok = true;
        for (UINT i = 0; i < count; ++i) if (x[i] != ref[base + i]) { ok = false; break; }
        D3D12_RANGE w{0, 0}; readback->Unmap(0, &w);
        return ok;
    }
};

int wmain(int argc, wchar_t** argv) {
    if (argc < 3) { fwprintf(stderr, L"uso: probe_timestamps.exe <pasta_cso> <csv>\n"); return 2; }
    setvbuf(stdout, nullptr, _IONBF, 0);
    try {
        const UINT N = 8000000, seed = 0x13579BDF, warm = 3, reps = 10;
        ComPtr<ID3DBlob> cs; check(D3DReadFileToBlob((std::wstring(argv[1]) + L"\\compute.cso").c_str(), &cs), "Read compute.cso");
        ComPtr<IDXGIFactory6> f; check(CreateDXGIFactory2(0, IID_PPV_ARGS(&f)), "CreateDXGIFactory2");
        ComPtr<IDXGIAdapter1> a970, a750;
        for (UINT i = 0;; ++i) {
            ComPtr<IDXGIAdapter1> a; HRESULT h = f->EnumAdapters1(i, &a);
            if (h == DXGI_ERROR_NOT_FOUND) break; check(h, "EnumAdapters1");
            DXGI_ADAPTER_DESC1 d{}; a->GetDesc1(&d);
            if (d.VendorId == 0x10DE && d.DeviceId == 0x13C2) a970 = a;
            if (d.VendorId == 0x10DE && d.DeviceId == 0x1380) a750 = a;
        }
        if (!a970 || !a750) throw std::runtime_error("GTX 970 (13C2) e GTX 750 Ti (1380) sao obrigatorias");
        Gpu g0, g1; g0.name = "GTX970"; g1.name = "GTX750Ti";
        g0.init(a970.Get(), cs.Get(), N); g1.init(a750.Get(), cs.Get(), N);
        printf("timestamp freq: 970=%llu Hz, 750Ti=%llu Hz\n", g0.tsFreq, g1.tsFreq);

        std::vector<uint32_t> ref8(N), ref1024(N);
        for (UINT i = 0; i < N; ++i) { ref8[i] = expected(i, seed, 8); ref1024[i] = expected(i, seed, 1024); }

        struct Cfg { const char* mode; UINT iters; bool copy; };
        std::vector<Cfg> cfgs;
        for (UINT it : {8u, 1024u}) for (bool cp : {true, false}) for (const char* m : {"gtx970_solo", "gtx750_solo", "dual_parallel_50"}) cfgs.push_back({m, it, cp});
        // Ordem aleatória (semente fixa) de todas as execuções medidas; aquecimentos antes, por configuração.
        std::vector<std::pair<int, int>> order;
        for (int c = 0; c < (int)cfgs.size(); ++c) for (int r = 1; r <= (int)reps; ++r) order.push_back({c, r});
        std::mt19937 rng(20261119); std::shuffle(order.begin(), order.end(), rng);

        std::ofstream out(argv[2], std::ios::trunc);
        out << "seq,mode,iterations,with_copy,rep,warmup,elements,host_total_ms,k970_ms,c970_ms,k750_ms,c750_ms,validation\n";
        int seq = 0;
        auto run = [&](const Cfg& c, int rep, bool warmup) {
            const auto& ref = c.iters == 8 ? ref8 : ref1024;
            double k0 = 0, c0 = 0, k1 = 0, c1 = 0; bool ok = true;
            double t = qpc();
            if (!strcmp(c.mode, "gtx970_solo")) { g0.encode(0, N, seed, c.iters, c.copy); g0.submit(); g0.wait(); }
            else if (!strcmp(c.mode, "gtx750_solo")) { g1.encode(0, N, seed, c.iters, c.copy); g1.submit(); g1.wait(); }
            else { g0.encode(0, N / 2, seed, c.iters, c.copy); g1.encode(N / 2, N / 2, seed, c.iters, c.copy); g0.submit(); g1.submit(); g0.wait(); g1.wait(); }
            double host = (qpc() - t) * 1000;
            bool use0 = strcmp(c.mode, "gtx750_solo") != 0, use1 = strcmp(c.mode, "gtx970_solo") != 0;
            if (use0) g0.times(k0, c0);
            if (use1) g1.times(k1, c1);
            if (c.copy) {
                if (!strcmp(c.mode, "gtx970_solo")) ok = g0.verify(0, N, ref);
                else if (!strcmp(c.mode, "gtx750_solo")) ok = g1.verify(0, N, ref);
                else ok = g0.verify(0, N / 2, ref) && g1.verify(N / 2, N / 2, ref);
            }
            char line[512];
            sprintf_s(line, "%d,%s,%u,%d,%d,%d,%u,%.4f,%.4f,%.4f,%.4f,%.4f,%s", ++seq, c.mode, c.iters, c.copy ? 1 : 0, rep, warmup ? 1 : 0, N,
                      host, k0, c0, k1, c1, c.copy ? (ok ? "PASS" : "FAIL") : "NOT_CHECKED");
            out << line << "\n"; out.flush();
            if (c.copy && !ok) throw std::runtime_error(std::string("validacao falhou: ") + c.mode);
        };
        SYSTEMTIME st; GetLocalTime(&st);
        printf("inicio %02d:%02d:%02d\n", st.wHour, st.wMinute, st.wSecond);
        for (auto& c : cfgs) for (UINT w = 1; w <= warm; ++w) run(c, (int)w, true);
        for (auto& o : order) run(cfgs[o.first], o.second, false);
        GetLocalTime(&st);
        printf("fim %02d:%02d:%02d; execucoes=%d\nRESULT=PASS\n", st.wHour, st.wMinute, st.wSecond, seq);
        return 0;
    } catch (const std::exception& e) {
        fprintf(stderr, "FATAL: %s\n", e.what()); puts("RESULT=FAIL"); return 1;
    }
}
