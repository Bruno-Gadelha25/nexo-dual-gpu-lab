#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <dxgi1_6.h>
#include <d3d12.h>
#include <wrl/client.h>
#include <cstdio>
#include <cstdint>
#include <vector>
#include <string>
#include <algorithm>
#pragma comment(lib,"dxgi.lib")
#pragma comment(lib,"d3d12.lib")
#pragma comment(lib,"dxguid.lib")
#pragma comment(lib,"ole32.lib")
using Microsoft::WRL::ComPtr;
static void hr(const char* what, HRESULT h) { printf("  %-45s HRESULT=0x%08X %s\n",what,(unsigned)h,SUCCEEDED(h)?"OK":"FAIL"); }
static const char* fl(D3D_FEATURE_LEVEL x) { switch(x){case D3D_FEATURE_LEVEL_12_2:return "12_2";case D3D_FEATURE_LEVEL_12_1:return "12_1";case D3D_FEATURE_LEVEL_12_0:return "12_0";case D3D_FEATURE_LEVEL_11_1:return "11_1";case D3D_FEATURE_LEVEL_11_0:return "11_0";default:return "?";} }
static void crossProbe(ID3D12Device* src, ID3D12Device* dst, const wchar_t* label) {
 printf("  Cross-adapter probe %ls\n",label);
 D3D12_HEAP_DESC hd{}; hd.SizeInBytes=65536; hd.Properties.Type=D3D12_HEAP_TYPE_DEFAULT; hd.Properties.CreationNodeMask=1; hd.Properties.VisibleNodeMask=1; hd.Alignment=0; hd.Flags=D3D12_HEAP_FLAG_SHARED|D3D12_HEAP_FLAG_SHARED_CROSS_ADAPTER;
 ComPtr<ID3D12Heap> heap; HRESULT h=src->CreateHeap(&hd,IID_PPV_ARGS(&heap)); hr("Create cross-adapter heap",h); if(FAILED(h))return;
 D3D12_RESOURCE_DESC rd{}; rd.Dimension=D3D12_RESOURCE_DIMENSION_TEXTURE2D; rd.Width=64; rd.Height=64; rd.DepthOrArraySize=1; rd.MipLevels=1; rd.Format=DXGI_FORMAT_R8G8B8A8_UNORM; rd.SampleDesc.Count=1; rd.Layout=D3D12_TEXTURE_LAYOUT_ROW_MAJOR; rd.Flags=D3D12_RESOURCE_FLAG_ALLOW_CROSS_ADAPTER;
 ComPtr<ID3D12Resource> res; h=src->CreatePlacedResource(heap.Get(),0,&rd,D3D12_RESOURCE_STATE_COMMON,nullptr,IID_PPV_ARGS(&res)); hr("CreatePlacedResource cross-adapter row-major texture",h); if(FAILED(h))return;
 HANDLE sh=nullptr; h=src->CreateSharedHandle(heap.Get(),nullptr, GENERIC_ALL,nullptr,&sh); hr("CreateSharedHandle heap",h); if(FAILED(h))return;
 ComPtr<ID3D12Heap> opened; h=dst->OpenSharedHandle(sh,IID_PPV_ARGS(&opened)); hr("OpenSharedHandle heap on peer GPU",h); CloseHandle(sh); if(SUCCEEDED(h)){ComPtr<ID3D12Resource> peerRes; h=dst->CreatePlacedResource(opened.Get(),0,&rd,D3D12_RESOURCE_STATE_COMMON,nullptr,IID_PPV_ARGS(&peerRes)); hr("CreatePlacedResource on peer heap",h);}
}int main(){
 printf("DXGI/D3D12 diagnostic; no rendering, kernels, or benchmark.\n");
 ComPtr<IDXGIFactory6> f; HRESULT h=CreateDXGIFactory2(0,IID_PPV_ARGS(&f)); hr("CreateDXGIFactory2",h); if(FAILED(h))return 2;
 std::vector<ComPtr<IDXGIAdapter1>> ads;
 for(UINT i=0;;++i){ ComPtr<IDXGIAdapter1>a; h=f->EnumAdapters1(i,&a); if(h==DXGI_ERROR_NOT_FOUND)break; if(FAILED(h)){hr("EnumAdapters1",h);break;} DXGI_ADAPTER_DESC1 d{};a->GetDesc1(&d); printf("\nAdapter %u: %ls\n VendorId=%04X DeviceId=%04X SubSys=%08X Revision=%u\n DedicatedVideoMemory=%llu SharedSystemMemory=%llu Flags=0x%X LUID=%08X:%08X\n",i,d.Description,d.VendorId,d.DeviceId,d.SubSysId,d.Revision,(unsigned long long)d.DedicatedVideoMemory,(unsigned long long)d.SharedSystemMemory,d.Flags,d.AdapterLuid.HighPart,d.AdapterLuid.LowPart); ads.push_back(a); }
 std::vector<ComPtr<ID3D12Device>> devs(ads.size());
 const D3D_FEATURE_LEVEL levels[]={D3D_FEATURE_LEVEL_12_2,D3D_FEATURE_LEVEL_12_1,D3D_FEATURE_LEVEL_12_0,D3D_FEATURE_LEVEL_11_1,D3D_FEATURE_LEVEL_11_0};
 for(size_t i=0;i<ads.size();++i){DXGI_ADAPTER_DESC1 ad{};ads[i]->GetDesc1(&ad); printf("\nD3D12 adapter %zu %ls\n",i,ad.Description); h=D3D12CreateDevice(ads[i].Get(),D3D_FEATURE_LEVEL_11_0,IID_PPV_ARGS(&devs[i]));hr("D3D12CreateDevice(min FL11_0)",h);if(FAILED(h))continue; auto*d=devs[i].Get(); D3D12_FEATURE_DATA_FEATURE_LEVELS fls{};fls.NumFeatureLevels=sizeof(levels)/sizeof(levels[0]);fls.pFeatureLevelsRequested=levels;h=d->CheckFeatureSupport(D3D12_FEATURE_FEATURE_LEVELS,&fls,sizeof(fls));hr("Query max feature level",h);if(SUCCEEDED(h))printf("  Max feature level: %s\n",fl(fls.MaxSupportedFeatureLevel));
 D3D12_FEATURE_DATA_SHADER_MODEL sm{}; HRESULT hs=E_INVALIDARG; D3D_SHADER_MODEL candidates[]={D3D_SHADER_MODEL_6_8,D3D_SHADER_MODEL_6_7,D3D_SHADER_MODEL_6_6,D3D_SHADER_MODEL_6_5,D3D_SHADER_MODEL_6_4,D3D_SHADER_MODEL_6_3,D3D_SHADER_MODEL_6_2,D3D_SHADER_MODEL_6_1,D3D_SHADER_MODEL_6_0,D3D_SHADER_MODEL_5_1}; for(auto candidate:candidates){sm.HighestShaderModel=candidate;hs=d->CheckFeatureSupport(D3D12_FEATURE_SHADER_MODEL,&sm,sizeof(sm));if(SUCCEEDED(hs)){printf("  Highest supported shader model enum: 0x%X\n",sm.HighestShaderModel);break;}} hr("Query shader model descending",hs);
 D3D12_FEATURE_DATA_D3D12_OPTIONS op{};h=d->CheckFeatureSupport(D3D12_FEATURE_D3D12_OPTIONS,&op,sizeof(op));hr("Query D3D12_OPTIONS",h);if(SUCCEEDED(h))printf("  ResourceBindingTier=%u ResourceHeapTier=%u CrossNodeSharingTier=%u\n",op.ResourceBindingTier,op.ResourceHeapTier,op.CrossNodeSharingTier);
 printf("  NodeCount=%u\n",d->GetNodeCount());
 for(auto t:{D3D12_COMMAND_LIST_TYPE_DIRECT,D3D12_COMMAND_LIST_TYPE_COMPUTE,D3D12_COMMAND_LIST_TYPE_COPY}){D3D12_COMMAND_QUEUE_DESC q{};q.Type=t;ComPtr<ID3D12CommandQueue> cq;const char* n=t==D3D12_COMMAND_LIST_TYPE_DIRECT?"DIRECT":t==D3D12_COMMAND_LIST_TYPE_COMPUTE?"COMPUTE":"COPY";std::string label=std::string("Create ")+n+" command queue";h=d->CreateCommandQueue(&q,IID_PPV_ARGS(&cq));hr(label.c_str(),h);}
 }
 for(size_t i=0;i<ads.size();++i){DXGI_ADAPTER_DESC1 a{};ads[i]->GetDesc1(&a);if(a.VendorId!=0x10DE||!devs[i])continue;for(size_t j=0;j<ads.size();++j){DXGI_ADAPTER_DESC1 b{};ads[j]->GetDesc1(&b);if(i!=j&&b.VendorId==0x10DE&&devs[j]){std::wstring label=std::wstring(a.Description)+L" -> "+b.Description;crossProbe(devs[i].Get(),devs[j].Get(),label.c_str());}}}
 return 0;
}







