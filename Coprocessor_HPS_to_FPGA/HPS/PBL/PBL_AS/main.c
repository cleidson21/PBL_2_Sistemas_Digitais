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
        printf("%3d", matrix[i]);  // Aumentei o espaço para melhor visualização
        if (i % n != n - 1) 
            printf(", ");
        else printf(" |");
    }
}

int validate_operation(uint32_t op_code, uint32_t matrix_size) {
    if (op_code > 7) {
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
    int8_t matrix_a[MATRIX_SIZE] = {
        1, 2, 3, 4, 5,
        6, 7, 8, 9, 10,
        11, 12, 13, 14, 15,
        16, 17, 18, 19, 20,
        21, 22, 23, 24, 25
    };

    int8_t matrix_b[MATRIX_SIZE] = {
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1
    };
    
    // Buffer para armazenar o resultado da operação
    int8_t matrix_result[MATRIX_SIZE] = {0};
    uint8_t overflow_flag = 0;
    uint32_t op_code = 2;
    uint32_t matrix_size = 0;
    uint32_t scalar = 11;

    struct Params params = {
        .a = matrix_a,
        .b = matrix_b,
        .opcode = op_code,
        .size = matrix_size,
        .scalar = scalar
    };
    
    // Valida os parâmetros antes de iniciar a comunicação
    if (validate_operation(op_code, matrix_size) != HW_SUCCESS) {
        return EXIT_FAILURE;
    }

    printf("Inicializando hardware...\n");
    if (init_hw_access() != HW_SUCCESS) {
        fprintf(stderr, "Falha na inicialização do hardware\n");
        return EXIT_FAILURE;
    }

    printf("Enviando dados para a FPGA...\n");
    if (send_all_data(&params) != HW_SUCCESS) {
        fprintf(stderr, "Falha no envio de dados para a FPGA\n");
        close_hw_access();
        return EXIT_FAILURE;
    }

    printf("Processando (aguardando FPGA concluir a operação)...\n");
    
    // Limpa o buffer de resultado antes de receber novos dados
    int i;
    for (i = 0; i < MATRIX_SIZE; i++) {
        matrix_result[i] = 0;
    }
    overflow_flag = 0;
    
    // Recebe os resultados da FPGA (ciclo de 25 números + flag de overflow)
    if (read_all_results(matrix_result, &overflow_flag) != HW_SUCCESS) {
        fprintf(stderr, "Falha na leitura dos resultados da FPGA\n");
        close_hw_access();
        return EXIT_FAILURE;
    }

    printf("Recebimento dos dados da FPGA concluído com sucesso!\n");

    // Exibe os resultados da operação
    print_matrix("\nMatriz A", matrix_a, matrix_size);
    print_matrix("\nMatriz B", matrix_b, matrix_size);
    print_matrix("\nResultado", matrix_result, matrix_size);
    printf("\n\nOverflow: %s\n", (overflow_flag & 0x1) ? "SIM\n" : "NÃO\n");

    close_hw_access();
    return EXIT_SUCCESS;
}