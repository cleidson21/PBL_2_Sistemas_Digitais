#ifndef INTERFACE_H
#define INTERFACE_H
#include <stdint.h>

/* ========== CONSTANTES DE STATUS ========== */
#define HW_SUCCESS      0
#define HW_SEND_FAIL   -1

/* ========== ESTRUTURAS DE DADOS ========== */
struct Params {
    const int8_t* a;
    const int8_t* b;
    uint32_t opcode;
    uint32_t size;
    int32_t scalar;
};

/* ========== DECLARAÇÕES DE FUNÇÕES ASSEMBLY ========== */
extern int init_hw_access(void);

extern int close_hw_access(void);

extern int send_all_data(const struct Params* p);

extern int read_all_results(int8_t* result, uint8_t* overflow_flag);

#endif
