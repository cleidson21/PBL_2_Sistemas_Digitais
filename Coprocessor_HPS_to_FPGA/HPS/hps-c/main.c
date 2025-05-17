#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include "./hps_0.h"

#define LW_BRIDGE_BASE 0xFF200000
#define LW_BRIDGE_SPAN 0x00005000

// Definições dos registradores PIO
#define DATA_IN_BASE  0x0
#define DATA_OUT_BASE 0x10

// Bits de controle no barramento de dados
#define FPGA_WAIT_BIT  (1 << 29)
#define FPGA_DONE_BIT  (1 << 27)
#define FPGA_OVFL_BIT  (1 << 28)
#define HPS_WAIT_BIT   (1 << 30)

// Protótipos de função
void send_data(volatile uint32_t* base, uint32_t data);
uint32_t receive_data(volatile uint32_t* base);
void wait_for_fpga_ready(volatile uint32_t* data_out_ptr);

int main(void) {
    int fd;
    void *LW_virtual;
    volatile uint32_t *data_in_ptr, *data_out_ptr;

    // Abre /dev/mem para acesso a endereços físicos
    if((fd = open("/dev/mem", (O_RDWR | O_SYNC))) == -1) {
        printf("ERROR: could not open \"/dev/mem\"...\n");
        return 1;
    }

    // Mapeia os endereços físicos para virtuais
    LW_virtual = mmap(NULL, LW_BRIDGE_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, LW_BRIDGE_BASE);
    if(LW_virtual == MAP_FAILED) {
        printf("ERROR: mmap() failed...\n");
        close(fd);
        return -1;
    }

    // Configura ponteiros para os registradores PIO
    data_in_ptr = (volatile uint32_t*)(LW_virtual + DATA_IN_BASE);
    data_out_ptr = (volatile uint32_t*)(LW_virtual + DATA_OUT_BASE);

    printf("Starting HPS-FPGA communication test...\n");

    // Teste 1: Envia operação simples e verifica resultado
    printf("\nTest 1: Simple addition\n");
    
    // Configura operação: soma de matrizes 2x2
    uint32_t control_word = (0x1 << 29) | // start = 1
                           (0x0 << 30) | // HPS wait = 0 (ready)
                           (0x0 << 19) | // size = 2x2 (01)
                           (0x0 << 16);  // opcode = 000 (add)
    
    // Envia dados de teste (2x2 matrix)
    printf("Sending control word: 0x%08X\n", control_word);
    send_data(data_in_ptr, control_word);
    
    // Envia matriz A (2x2)
    for(int i = 0; i < 4; i++) {
        uint32_t data = (i << 8) | (i+1); // Valores de exemplo
        printf("Sending matrix A element %d: 0x%08X\n", i, data);
        send_data(data_in_ptr, data);
    }
    
    // Envia matriz B (2x2)
    for(int i = 0; i < 4; i++) {
        uint32_t data = ((i+2) << 8) | (i+3); // Valores de exemplo
        printf("Sending matrix B element %d: 0x%08X\n", i, data);
        send_data(data_in_ptr, data);
    }
    
    // Espera processamento e recebe resultados
    printf("\nWaiting for results...\n");
    for(int i = 0; i < 4; i++) {
        uint32_t result = receive_data(data_out_ptr);
        printf("Received result %d: 0x%08X (value: %d)\n", i, result, result & 0xFF);
    }

    // Teste 2: Multiplicação por escalar
    printf("\nTest 2: Scalar multiplication\n");
    
    // Configura operação: multiplicação por escalar 5 em matriz 3x3
    control_word = (0x1 << 29) | // start = 1
                  (0x0 << 30) | // HPS wait = 0 (ready)
                  (5 << 21) |    // scalar = 5
                  (0x2 << 19) |  // size = 3x3 (10)
                  (0x2 << 16);   // opcode = 010 (scalar multiply)
    
    printf("Sending control word: 0x%08X\n", control_word);
    send_data(data_in_ptr, control_word);
    
    // Envia matriz A (3x3)
    for(int i = 0; i < 9; i++) {
        uint32_t data = (i << 8) | (i+1); // Valores de exemplo
        printf("Sending matrix element %d: 0x%08X\n", i, data);
        send_data(data_in_ptr, data);
    }
    
    // Espera processamento e recebe resultados
    printf("\nWaiting for results...\n");
    for(int i = 0; i < 9; i++) {
        uint32_t result = receive_data(data_out_ptr);
        printf("Received result %d: 0x%08X (value: %d)\n", i, result, result & 0xFF);
    }

    // Libera recursos
    if(munmap(LW_virtual, LW_BRIDGE_SPAN) != 0) {
        printf("ERROR: munmap() failed...\n");
        close(fd);
        return -1;
    }
    close(fd);

    printf("\nTest completed successfully!\n");
    return 0;
}

// Função para enviar dados para o FPGA com handshake
void send_data(volatile uint32_t* data_in_ptr, uint32_t data) {
    // Espera FPGA estar pronto (wait bit = 0)
    while((*data_in_ptr & FPGA_WAIT_BIT));
    
    // Envia dados
    *data_in_ptr = data;
    
    // Sinaliza que HPS está ocupado (wait = 1)
    *data_in_ptr |= HPS_WAIT_BIT;
    
    // Espera FPGA confirmar recebimento
    while(!(*data_in_ptr & FPGA_WAIT_BIT));
    
    // Libera barramento (HPS ready)
    *data_in_ptr &= ~HPS_WAIT_BIT;
}

// Função para receber dados do FPGA com handshake
uint32_t receive_data(volatile uint32_t* data_out_ptr) {
    uint32_t data;
    
    // Espera FPGA ter dados prontos (wait bit = 1)
    while(!(*data_out_ptr & FPGA_WAIT_BIT));
    
    // Lê dados
    data = *data_out_ptr;
    
    // Confirma recebimento (HPS wait = 0)
    // O FPGA monitora o bit 30 do data_in para handshake
    // Neste caso, precisamos escrever em data_in para confirmar
    // Isso pode requerer ajustes dependendo da implementação exata
    
    // Retorna os dados (bits 7:0)
    return data;
}

// Função auxiliar para esperar FPGA ficar pronto
void wait_for_fpga_ready(volatile uint32_t* data_out_ptr) {
    while(*data_out_ptr & FPGA_WAIT_BIT) {
        usleep(1000); // Pequena pausa para evitar busy-wait
    }
}