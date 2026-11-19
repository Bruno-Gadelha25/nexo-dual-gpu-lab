#include <intrin.h>
#include <cstdio>
int main(){int r[4]{};__cpuid(r,0);int max=r[0];char vendor[13]{};*(int*)&vendor[0]=r[1];*(int*)&vendor[4]=r[3];*(int*)&vendor[8]=r[2];printf("CPUID vendor=%s maxleaf=%d\n",vendor,max);__cpuid(r,1);printf("Leaf1 ECX: SSE3=%d SSSE3=%d FMA=%d SSE4.1=%d SSE4.2=%d XSAVE=%d OSXSAVE=%d AVX=%d F16C=%d\n",(r[2]>>0)&1,(r[2]>>9)&1,(r[2]>>12)&1,(r[2]>>19)&1,(r[2]>>20)&1,(r[2]>>26)&1,(r[2]>>27)&1,(r[2]>>28)&1,(r[2]>>29)&1);__cpuidex(r,7,0);printf("Leaf7 EBX: BMI1=%d AVX2=%d BMI2=%d AVX512F=%d\n",(r[1]>>3)&1,(r[1]>>5)&1,(r[1]>>8)&1,(r[1]>>16)&1);return 0;}
