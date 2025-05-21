#ifndef INTERFACE_H
#define INTERFACE_H
#include <stdint.h>

/* ========== CONSTANTES DE STATUS ========== */
#define HW_SUCCESS      0
#define HW_INIT_FAIL   -1
#define HW_SEND_FAIL   -2
#define HW_READ_FAIL   -3

/* ========== DEFINIÇÕES DE HARDWARE ========== */
#define DATA_IN_BASE    0x0
#define DATA_OUT_BASE   0x10
#define LW_BRIDGE_BASE  0xFF200000
#define LW_BRIDGE_SPAN  0x00005000

/* ========== BITS DE CONTROLE ========== */
#define OPCODE_BITS     (3 << 16)
#define SIZE_BITS       (3 << 19)
#define SCALAR_BITS     (3 << 21)
#define RESET_BIT       (1 << 29)
#define START_PULSE_BIT (1 << 30)
#define HPS_CONTROL_BIT (1 << 31)
#define FPGA_ACK_BIT    (1 << 31)

/* ========== ESTRUTURAS DE DADOS ========== */
struct Params {
    const int8_t* a;
    const int8_t* b;
    uint32_t opcode;
    uint32_t size;
    uint32_t scalar;
};

/* ========== DECLARAÇÕES DE FUNÇÕES ASSEMBLY ========== */
extern int init_hw_access(void);

extern int close_hw_access(void);

extern int send_all_data(const struct Params* p);

extern int read_all_results(int8_t* result, uint8_t* overflow_flag);

#endif
