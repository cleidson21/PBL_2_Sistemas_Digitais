]#include <stdint.h>
#include <stdio.h>
#include "interface.h" 

#define MATRIX_SIZE 25

int main() {
    int8_t matrix_a[MATRIX_SIZE] = {
        1, 2, 3, 4, 5,
        6, 7, 8, 9, 10,
        11, 12, 13, 14, 15,
        16, 17, 18, 19, 20,
        21, 22, 23, 24, 25
    };

    int8_t matrix_b[MATRIX_SIZE] = {
        25, 24, 23, 22, 21,
        20, 19, 18, 17, 16,
        15, 14, 13, 12, 11,
        10, 9, 8, 7, 6,
        5, 4, 3, 2, 1
    };

    int8_t matrix_result[MATRIX_SIZE];

    uint32_t op_code = 2;       // Exemplo: multiplicação
    uint32_t matrix_size = 3;   // 5x5 → código 3
    uint32_t scalar = 3;        // Escalar de exemplo

    printf("Enviando dados para o hardware...\n");
    send_all_data(matrix_a, matrix_b, op_code, matrix_size, scalar);

    for (volatile int i = 0; i < 100000; ++i);  // Delay simples

    printf("Lendo resultados...\n");
    read_all_results(matrix_result);

    uint32_t overflow = *((volatile uint32_t*)(0xFF200000 + 25 * 4));  // Overflow flag

    printf("\nMatriz A:\n");
    for (int i = 0; i < MATRIX_SIZE; ++i) {
        printf("%4d", matrix_a[i]);
        if ((i + 1) % 5 == 0) printf("\n");
    }

    printf("\nMatriz B:\n");
    for (int i = 0; i < MATRIX_SIZE; ++i) {
        printf("%4d", matrix_b[i]);
        if ((i + 1) % 5 == 0) printf("\n");
    }

    printf("\nResultado:\n");
    for (int i = 0; i < MATRIX_SIZE; ++i) {
        printf("%4d", matrix_result[i]);
        if ((i + 1) % 5 == 0) printf("\n");
    }

    printf("\nOverflow detectado? %s\n", (overflow & 0x1) ? "SIM" : "NÃO");

    return 0;
}
