#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "interface.h"

#define MATRIX_SIZE 25

void print_matrix(const char* label, const int8_t* matrix, int size) {
    uint8_t n = size + 2;
    uint8_t size_total = n * n;
    int i;
    printf("\n%s:\n", label);
    for (i = 0; i < size_total; i++) {
        if (i % n == 0) 
            printf("\n| ");
        printf("%3d", matrix[i]);
        if (i % n != n - 1) 
            printf(", ");
        else printf(" |");
    }
}

int validate_operation(uint32_t op_code, uint32_t matrix_size) {
    if (op_code > 6) {
        fprintf(stderr, "Código de operação inválido: %u\n", op_code);
        return HW_SEND_FAIL;
    }

    if (matrix_size > 3) {
        fprintf(stderr, "Tamanho de matriz inválido: %u\n", matrix_size);
        return HW_SEND_FAIL;
    }
    return HW_SUCCESS;
}

int main() {
/*
    int8_t matrix_a[MATRIX_SIZE] = {
        1, 2, 3, 4, 5,
       6, 7, 8, 9, 10,
       11, 12, 13, 14, 15,
       16, 17, 18, 19, 20,
       21, 22, 23, 24, 25
    };

    int8_t matrix_b[MATRIX_SIZE] = {
       -1, -1, 1, 1, 1,
       1, 1, 1, 1, 1,
       1, 1, 1, 1, 1,
       1, 1, 1, 1, 1,
       1, 1, 1, 1, 1
    };
*/
    int8_t matrix_a[MATRIX_SIZE] = {
        10,  100,  10, 100,   50,  // Pequeno, grande, pequeno neg., grande neg., médio
        30,  60,   0,   30,   80,
        20,  80,   25,  25,   90,
        40,   70,  30,  70,   20,
        15,   85,  15,  85,   35
   };
   
   int8_t matrix_b[MATRIX_SIZE] = {
        20,   50,  -20,  -50,   77,  // 30, 150, -30, -150, 127
        25,   68,   10,   97,   48,  // 55, 128, 10, 127, 128
       -15,  -49,   30,  -30,   38,  // -35, -129, 55, -55, 128
        35,   58,  -25,  -59,   45,  // 75, 128, -55, -129, 65
        40,   43,  -35,  -44,   50   // 55, 128, -50, -129, 85
   };
/*
    int8_t matrix_a[MATRIX_SIZE] = {
        100, -100,  110, -110,  120,  // Valores que geram overflow claro
         90,  -90,  105, -105,   95,
        115, -115,   80,  -80,  125,
         85,  -85,  100, -100,   75,
        127, -128,   70,  -70,   65
    };
    
    int8_t matrix_b[MATRIX_SIZE] = {
         50,  -50,   45,  -45,   30,  // 150, -150, 155, -155, 150
         60,  -60,   55,  -55,   65,  // 150, -150, 160, -160, 160
         40,  -40,   50,  -50,   15,  // 155, -155, 130, -130, 140
         75,  -75,   35,  -35,   85,  // 160, -160, 135, -135, 160
          1,   -2,   60,  -60,   70   // 128, -130, 130, -130, 135
    };
*/
    int8_t matrix_result[MATRIX_SIZE] = {0};
    uint8_t overflow_flag = 0;

    if (init_hw_access() != HW_SUCCESS) {
        fprintf(stderr, "Falha na inicialização do hardware\n");
        return EXIT_FAILURE;
    }

    while (1) {
        uint32_t op_code, matrix_size, scalar = 0;

        printf("\n\n========= MENU =========\n");
        printf("Escolha a operação:\n");
        printf("0 - Soma de matrizes\n");
        printf("1 - Subtração de matrizes\n");
        printf("2 - Multiplicação de matrizes\n");
        printf("3 - Multiplicação escalar (A)\n");
        printf("4 - Determinante (A)\n");
        printf("5 - Transposição de matriz (A)\n");
        printf("6 - Matriz oposta (A)\n");
        printf("7 - Sair\n");
        printf("Opção: ");
        scanf("%u", &op_code);

        if (op_code == 7) break;

        printf("Escolha o tamanho da matriz:\n");
        printf("0 - 2x2\n1 - 3x3\n2 - 4x4\n3 - 5x5\nTamanho: ");
        scanf("%u", &matrix_size);

        if (op_code == 3) {
            printf("Digite o valor escalar para multiplicar A: ");
            scanf("%u", &scalar);
        }

        if (validate_operation(op_code, matrix_size) != HW_SUCCESS) {
            continue;
        }

        struct Params params = {
            .a = matrix_a,
            .b = matrix_b,
            .opcode = op_code,
            .size = matrix_size,
            .scalar = scalar
        };
        
        printf("1 -Chegou aqui\n");
        if (send_all_data(&params) != HW_SUCCESS) {
            fprintf(stderr, "Falha no envio de dados para a FPGA\n");
            continue;
        }
        printf("2 -Chegou aqui\n");
        // Zera buffers
        int i;
        for (i = 0; i < MATRIX_SIZE; i++) matrix_result[i] = 0;
        overflow_flag = 0;

        if (read_all_results(matrix_result, &overflow_flag) != HW_SUCCESS) {
            fprintf(stderr, "Falha na leitura dos resultados da FPGA\n");
            continue;
        }

        printf("\n--- Resultado ---\n");
        print_matrix("Matriz A", matrix_a, matrix_size);
        if (op_code < 3) {
            print_matrix("Matriz B", matrix_b, matrix_size);
        }
        if (op_code == 4) {
            printf("\nDeterminante: %d\n", matrix_result[0]);
        } else {
            // Op_code == 2 usa matriz 3x3 fixa para inversa
            int result_size = (op_code == 2 || op_code == 5 ) ? 3 : matrix_size;
            print_matrix("Resultado", matrix_result, result_size);

            // Mostrar overflow somente para operações matemáticas
            if (op_code != 2 && op_code != 4) {
                printf("\nOverflow: %s\n", (overflow_flag & 0x1) ? "SIM" : "NÃO");
            }
        }
        
    }

    close_hw_access();
    return EXIT_SUCCESS;
}
