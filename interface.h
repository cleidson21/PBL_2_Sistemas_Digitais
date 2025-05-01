#ifndef INTERFACE_H
#define INTERFACE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Escreve um valor em um offset específico na FPGA*/
void write_matrix_value(uint32_t offset, uint32_t value);

/* Lê um valor de um offset específico da FPGA*/
uint32_t read_result_value(uint32_t offset);

/* Envia as duas matrizes, opcode, tamanho e escalar para a FPGA e inicia o processamento*/
void send_all_data(const int8_t* a, const int8_t* b, uint32_t opcode, uint32_t size, uint32_t scalar);

/* Lê os resultados do processamento da FPGA e armazena no vetor result*/
void read_all_results(int8_t* result);

#ifdef __cplusplus
}
#endif

#endif /* INTERFACE_H */
