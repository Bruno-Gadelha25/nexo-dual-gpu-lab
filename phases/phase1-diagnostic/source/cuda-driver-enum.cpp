#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdio>
typedef int CUresult; typedef int CUdevice;
typedef CUresult (__stdcall *PFN_cuInit)(unsigned int);
typedef CUresult (__stdcall *PFN_cuDeviceGetCount)(int*);
typedef CUresult (__stdcall *PFN_cuDeviceGet)(CUdevice*,int);
typedef CUresult (__stdcall *PFN_cuDeviceGetName)(char*,int,CUdevice);
typedef CUresult (__stdcall *PFN_cuDeviceComputeCapability)(int*,int*,CUdevice);
typedef CUresult (__stdcall *PFN_cuDeviceTotalMem_v2)(size_t*,CUdevice);
int main(){ HMODULE h=LoadLibraryW(L"nvcuda.dll"); if(!h){printf("LoadLibrary nvcuda.dll failed: %lu\n",GetLastError());return 2;} auto init=(PFN_cuInit)GetProcAddress(h,"cuInit"); auto count=(PFN_cuDeviceGetCount)GetProcAddress(h,"cuDeviceGetCount"); auto get=(PFN_cuDeviceGet)GetProcAddress(h,"cuDeviceGet"); auto name=(PFN_cuDeviceGetName)GetProcAddress(h,"cuDeviceGetName"); auto cc=(PFN_cuDeviceComputeCapability)GetProcAddress(h,"cuDeviceComputeCapability"); auto mem=(PFN_cuDeviceTotalMem_v2)GetProcAddress(h,"cuDeviceTotalMem_v2"); if(!init||!count||!get||!name||!cc||!mem){printf("Required CUDA Driver API symbol missing\n");return 3;} CUresult r=init(0);printf("cuInit(0)=%d\n",r);if(r)return r;int n=0;r=count(&n);printf("cuDeviceGetCount=%d result=%d\n",n,r);if(r)return r;for(int i=0;i<n;++i){CUdevice d=-1;char nm[256]{};int ma=0,mi=0;size_t bytes=0;CUresult a=get(&d,i),b=name(nm,sizeof(nm),d),c=cc(&ma,&mi,d),m=mem(&bytes,d);printf("GPU %d handle=%d name=%s compute=%d.%d memory=%llu MiB [results %d,%d,%d,%d]\n",i,d,nm,ma,mi,(unsigned long long)(bytes/1048576),a,b,c,m);}FreeLibrary(h);return 0;}
