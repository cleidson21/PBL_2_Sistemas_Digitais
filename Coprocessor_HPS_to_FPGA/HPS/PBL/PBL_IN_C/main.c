#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include "./hps_0.h"

#define LW_BRIDGE_BASE 0xFF200000
#define LW_BRIDGE_SPAN 0x00005000

// Bits de controle (ajustados para o seu modelo)
#define OPCODE_BITS      (2 << 16)  // data_in[18:16]
#define SIZE_BITS        (3 << 19)  // data_in[21:19]
#define SCALAR_BITS      (3 << 21)  // data_in[28:21]
#define RESET_BIT        (1 << 29)  // data_in[29]
#define START_PULSE_BIT  (1 << 30)  // data_in[30]
#define HPS_CONTROL_BIT  (1 << 31)  // data_in[31] (HPS -> FPGA)
#define FPGA_ACK_BIT     (1 << 31)  // data_out[30] (FPGA -> HPS)

#define TIMEOUT_US 1000000  // 1 segundo

void debug_print(const char* message, volatile uint32_t* data_in, volatile uint32_t* data_out) {
    printf("[DEBUG] %s\n", message);
    printf("  data_in:  0x%08X (HPS_CTRL: %d)\n", *data_in, (*data_in >> 31) & 1);
    printf("  data_out: 0x%08X (FPGA_ACK: %d)\n", *data_out, (*data_out >> 31) & 1);
}

void reset_operation(volatile uint32_t* data_in) {
    *data_in = RESET_BIT;  // Pulso de start
    usleep(10);                  // Garante que o FPGA detecte
    *data_in = 0;                // Remove pulso
}

void start_operation(volatile uint32_t* data_in) {
    *data_in = START_PULSE_BIT;  // Pulso de start
    usleep(10);                  // Garante que o FPGA detecte
    *data_in = 0;                // Remove pulso
}

void handshake_send(volatile uint32_t* data_in, volatile uint32_t* data_out, uint8_t value_a, uint8_t value_b) {
    // Passo 1: Garante que FPGA está no estado inicial
    *data_in = 0; // Clear todos os bits
    usleep(100);   // Espera 100 μs 

    // Passo 2: HPS envia dado com controle = 1
    *data_in = HPS_CONTROL_BIT | SCALAR_BITS | SIZE_BITS | OPCODE_BITS | (value_b << 8) | value_a;
    debug_print("HPS -> FPGA: Dado + CTRL=1", data_in, data_out);

    // Passo 3: Aguarda FPGA_ACK=1
    uint32_t timeout = 0;
    while(!(*data_out & FPGA_ACK_BIT)) {
        if(timeout++ > TIMEOUT_US) {
            printf("[ERROR] Timeout esperando FPGA_ACK!\n");
            return;
        }
        usleep(1);
    }

    // Passo 3: HPS confirma (controle=0)
    *data_in = SCALAR_BITS | SIZE_BITS | OPCODE_BITS | (value_b << 8) | value_a;  // Mantém dados, CTRL=0

    // Passo 4: Aguarda FPGA_ACK=0
    timeout = 0;
    while(*data_out & FPGA_ACK_BIT) {
        if(timeout++ > TIMEOUT_US) {
            printf("[ERROR] Timeout esperando FPGA liberar!\n");
            return;
        }
        usleep(1);
    }
}

uint8_t handshake_receive(volatile uint32_t* data_in, volatile uint32_t* data_out) {
    // Passo 1: Garante que FPGA está no estado inicial
    *data_in = 0; // Clear todos os bits
    usleep(10);   // Espera 10 μs 

    // Passo 2: HPS sinaliza prontidão (HPS_CONTROL=1)
    *data_in = HPS_CONTROL_BIT;

    // Passo 3: Aguarda FPGA_ACK=1
    uint32_t timeout = 0;
    while(!(*data_out & FPGA_ACK_BIT)) {
        if(timeout++ > TIMEOUT_US) {
            printf("[ERROR] Timeout aguardando dado do FPGA!\n");
            return 0xFF;
        }
        usleep(1);
    }
    uint8_t value = *data_out & 0xFF;

    // Passo 4: HPS confirma recebimento (HPS_CONTROL=0)
    *data_in = 0;

    // Passo 5: Aguarda FPGA_ACK=0
    timeout = 0;
    while(*data_out & FPGA_ACK_BIT) {
        if(timeout++ > TIMEOUT_US) {
            printf("[ERROR] Timeout aguardando FPGA finalizar!\n");
            return value;
        }
        usleep(1);
    }
    return value;
}

int main() {
    int fd;
    int i;
    void *virtual_base;
    volatile uint32_t *data_in, *data_out;
    
    printf("=== Iniciando teste de comunicação HPS-FPGA ===\n");
    
    // Abre /dev/mem
    printf("\n[INIT] Abrindo /dev/mem...\n");
    if((fd = open("/dev/mem", O_RDWR)) < 0) {
        perror("open");
        return 1;
    }
    
    // Mapeia memória
    printf("[INIT] Mapeando memória...\n");
    virtual_base = mmap(NULL, LW_BRIDGE_SPAN, PROT_READ|PROT_WRITE, MAP_SHARED, fd, LW_BRIDGE_BASE);
    if(virtual_base == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return 1;
    }
    
    data_in = (volatile uint32_t*)(virtual_base + DATA_IN_BASE);
    data_out = (volatile uint32_t*)(virtual_base + DATA_OUT_BASE);

    *data_in = 0;
    *data_out = 0;
    
    printf("[INIT] Ponteiros configurados:\n");
    printf("  data_in:  %p\n", data_in);
    printf("  data_out: %p\n", data_out);
    debug_print("Estado inicial:", data_in, data_out);
    
    // Inicia operação
    printf("\n[TESTE] Iniciando teste de soma de vetores...\n");
    
    // Vetores de teste
    uint8_t vec_a[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25};
    uint8_t vec_b[] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};

    // Reseta FPGA
    reset_operation(data_in);

    // Inicia operação
    start_operation(data_in);
    
    // Exemplo de uso modificado:
    printf("\n[TESTE] Enviando vetores com handshake...\n");
    for(i = 0; i < 25; i++) {
        handshake_send(data_in, data_out, vec_a[i], vec_b[i]);
    }
    printf("\n[HS] Envio completo!\n");
    
    int8_t res[25];
    printf("\n[TESTE] Recebendo resultados com handshake...\n");
    for( i = 0; i < 25; i++) {
        res[i] = handshake_receive(data_in, data_out);
    }
    printf("\nMatriz A \n");
    for (i = 0; i < 25; i++) {
        if (i % 5 == 0) printf("\n| ");

        printf("%02d", vec_a[i]);  

        if (i % 5 != 4) printf(", ");
        else printf(" |");
        }
    printf("\n");

    printf("\nMatriz B \n");
    for (i = 0; i < 25; i++) {
        if (i % 5 == 0) printf("\n| ");

        printf("%02d", vec_b[i]);  

        if (i % 5 != 4) printf(", ");
        else printf(" |");
        }
    printf("\n");

    printf("\nMatriz Resultado \n");
    for (i = 0; i < 25; i++) {
        if (i % 5 == 0) printf("\n| ");

        printf("%02d", res[i]);  

        if (i % 5 != 4) printf(", ");
        else printf(" |");
        }
    printf("\n");

    printf("\n[HS] Recebimento completo!\n");
    
    // Libera recursos
    printf("\n[FIM] Liberando recursos...\n");
    munmap(virtual_base, LW_BRIDGE_SPAN);
    close(fd);
    
    printf("\n=== Teste concluído ===\n");
    return 0;
}