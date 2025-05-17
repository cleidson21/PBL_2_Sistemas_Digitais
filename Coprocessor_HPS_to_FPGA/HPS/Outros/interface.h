#ifndef INTERFACE_H
#define INTERFACE_H
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define HW_SUCCESS 0
#define HW_INIT_FAIL -1
#define HW_SEND_FAIL -2
#define HW_READ_FAIL -3

// Protótipos atualizados
int write_matrix_value(uint32_t offset, uint32_t value);
int read_result_value(uint32_t offset, uint32_t* result, uint8_t* overflow_flag);
int send_all_data(const int8_t* a, const int8_t* b, uint32_t opcode, uint32_t size, uint32_t scalar);
int read_all_results(int8_t* result, uint8_t* overflow_flag);
int init_hw_access(void);
int close_hw_access(void);

#ifdef __cplusplus
}
#endif

#endif /* INTERFACE_H */