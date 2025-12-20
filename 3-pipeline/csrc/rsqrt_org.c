#include <stdint.h>
#include "rsqrt_org.h"
static const uint32_t rsqrt_table[32] = {
    65536, 46341, 32768, 23170, 16384,  /* 2^0 to 2^4 */
    11585,  8192,  5793,  4096,  2896,  /* 2^5 to 2^9 */
     2048,  1448,  1024,   724,   512,  /* 2^10 to 2^14 */
      362,   256,   181,   128,    90,  /* 2^15 to 2^19 */
       64,    45,    32,    23,    16,  /* 2^20 to 2^24 */
       11,     8,     6,     4,     3,  /* 2^25 to 2^29 */
        2,     1                         /* 2^30, 2^31 */
};

/*計算0的個數*/
static int clz(uint32_t x)
{
    if (x == 0) return 32;
    
    int n = 0;
    if((x & 0xFFFF0000) == 0) {n += 16; x <<= 16;}
    if((x & 0xFF000000) == 0) {n += 8; x <<= 8;}
    if((x & 0xF0000000) == 0) {n += 4; x <<= 4;}
    if((x & 0xC0000000) == 0) {n += 2; x <<= 2;}
    if((x & 0x80000000) == 0) {n += 1;}
    return n;
}

static uint64_t mul32(uint32_t a, uint32_t b)
{
    uint64_t r = 0;
    for (int i = 0; i < 32; i++){
        if (b & 1U << i)
        r += (uint64_t)a << i;
    }
    return r;       // 回傳64位元結果，因為兩個32位元數相乘可能超過32位元
}

uint32_t fast_rsqrt(uint32_t x)
{
    if (x == 0) return 0xFFFFFFFF; // Return Inf
    if (x == 1) return 65536;

    int exp = 31 - clz(x);
    uint32_t y = rsqrt_table[exp];

    if (x > (1u << exp))
    {
        uint32_t y_next = (exp < 31) ? rsqrt_table[exp + 1] : 0;
        uint32_t delta = y - y_next;
        uint32_t frac = (uint32_t) ((((uint64_t)x - (1UL << exp)) << 16) >> exp);
        y -= (uint32_t) ((delta * frac) >> 16);
    }

    for (int iter = 0; iter < 2; iter++){
        uint32_t y2 = (uint32_t)mul32(y, y);  // 計算y^2, 返回64bit,但因為y*y是2^16 * 2^16 = 2^32
        // uint32_t會自動截取low 32 bits, 相當於右移32 bits
        // 在mul32產生的數值中, 結果雖然是64位元, 但不是所有64位元都有用到
        uint32_t xy2 = (uint32_t)(mul32(x, y2) >> 16);  // 計算x * y^2, 除以2^16
        // 右移16 is for 調整數值, 然後數值轉型成uint32_t就代表只取low 32 bits
        y = (uint32_t)(mul32(y, (3u << 16) - xy2) >> 17);
        // 把3轉成2^16 fixed-point 格式, 相乘之後右移17 = 除以2^16再除以2(分母)
    }

    return y;
}

// For test

static int test(void){
    int passed = 1;
    int base_address = 8;
    uint32_t in[] = {1, 4, 16, 24, 87, 269, 666};
    uint32_t exp_val[] = {
        65536, 32768, 16384, 13377, 7026, 3995, 2539
    };
    uint32_t result;
    for (int i = 0; i < sizeof(in)/sizeof(uint32_t); i++){
        result = fast_rsqrt(in[i]);
        *(int *)(base_address + 4 * 1) = result;
        if (result != exp_val[i])
            passed = 0;
    }
    return passed;
}

int main(void){
    int passed = test();
    *(int *) (4) = passed;
}