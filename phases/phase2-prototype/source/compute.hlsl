cbuffer Params : register(b0)
{
    uint BaseIndex;
    uint Count;
    uint Seed;
    uint Iterations;
};
RWStructuredBuffer<uint> Output : register(u0);
[numthreads(256, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID)
{
    if (tid.x >= Count) return;
    uint index = BaseIndex + tid.x;
    uint v = index ^ Seed;
    [loop]
    for (uint i = 0; i < Iterations; ++i)
    {
        v ^= v >> 13;
        v *= 0x85ebca6b;
        v ^= v << 7;
        v += (i ^ index) * 0xc2b2ae35;
    }
    Output[tid.x] = v;
}
