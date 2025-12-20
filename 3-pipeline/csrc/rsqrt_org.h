#ifndef RSQRT_ORG   // if not defined RSQRT_ORG (如果RSQER_ORG這個巨集還沒被定義), 用來檢查這個header file是否已經被包含過
#define RSQRT_ORG   // 定義RSQRT_ORG這個巨集(內容為空), 標記「這個header file已經被包含了」, 如果下次再#include這個檔案時, #ifndef會檢查到已定義, 就會跳過整個檔案內容
static uint64_t mul32(uint32_t a, uint32_t b);
static int clz(uint32_t x);
uint32_t fast_rsqrt(uint32_t x);
#endif