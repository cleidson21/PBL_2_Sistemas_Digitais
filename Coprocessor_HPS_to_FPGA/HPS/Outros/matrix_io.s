.syntax unified
.cpu cortex-a9
.text

@ Definição de offsets para cada ponte
.set H2F_MATRIX_OFFSET,   0x00    @ Ponte H2F - Dados das matrizes
.set F2H_RESULT_OFFSET,   0x00    @ Ponte F2H - Resultados
.set F2H_STATUS_OFFSET,   0x04    @ Ponte F2H - Status

.set LW_OPCODE_OFFSET,    0x00    @ Ponte LW - Opcode
.set LW_SIZE_OFFSET,      0x04    @ Ponte LW - Tamanho
.set LW_SCALAR_OFFSET,    0x08    @ Ponte LW - Escalar
.set LW_START_OFFSET,     0x0C    @ Ponte LW - Start
.set LW_STATUS_OFFSET,    0x10    @ Ponte LW - Status

.global init_hw_access
.global close_hw_access
.global send_all_data
.global read_all_results
.global write_matrix_value
.global read_result_value

.type init_hw_access, %function
.type close_hw_access, %function
.type send_all_data, %function
.type read_all_results, %function
.type write_matrix_value, %function
.type read_result_value, %function

@ Ponteiros globais
.data
.align 4
.global LW_bridge_ptr
LW_bridge_ptr: .word 0

.global H2F_bridge_ptr
H2F_bridge_ptr: .word 0

.global F2H_bridge_ptr
F2H_bridge_ptr: .word 0

.section .init_array, "aw"
.align 2
.word init_hw_access

.text

@ int init_hw_access(void)
@ Abre /dev/mem e faz mmap das pontes H2F, F2H e LW
@ Retorna 0 em sucesso, -1 em falha
init_hw_access:
    PUSH {r4-r7, lr}

    @ Abre /dev/mem
    LDR r0, =devmem_path
    MOV r1, #2          @ O_RDWR
    MOV r2, #0
    MOV r7, #5          @ syscall: open
    svc 0
    CMP r0, #0
    BLT fail_open
    MOV r4, r0          @ fd = r4

    @ Mapeia ponte HPS-to-FPGA
    MOV r0, #0          @ addr = NULL
    LDR r1, =MAP_SIZE   @ length
    LDR r1, [r1]
    MOV r2, #3          @ PROT_READ | PROT_WRITE
    MOV r3, #1          @ MAP_SHARED
    MOV r5, r4          @ fd
    LDR r6, =H2F_BASE
    LDR r6, [r6]
    MOV r7, #192        @ syscall: mmap2
    svc 0
    CMP r0, #-1
    BEQ fail_mmap
    LDR r1, =H2F_bridge_ptr
    STR r0, [r1]

    @ Mapeia ponte FPGA-to-HPS
    MOV r0, #0
    LDR r1, =MAP_SIZE
    LDR r1, [r1]
    MOV r2, #3
    MOV r3, #1
    MOV r5, r4
    LDR r6, =F2H_BASE
    LDR r6, [r6]
    MOV r7, #192
    svc 0
    CMP r0, #-1
    BEQ fail_mmap
    LDR r1, =F2H_bridge_ptr
    STR r0, [r1]

    @ Mapeia ponte Lightweight
    MOV r0, #0
    LDR r1, =MAP_SIZE
    LDR r1, [r1]
    MOV r2, #3
    MOV r3, #1
    MOV r5, r4
    LDR r6, =LW_BRIDGE_BASE
    LDR r6, [r6]
    MOV r7, #192
    svc 0
    CMP r0, #-1
    BEQ fail_mmap
    LDR r1, =LW_bridge_ptr
    STR r0, [r1]

    LDR r1, =fd_close
    STR r4, [r1]
    MOV r0, #0          @ sucesso
    B end_init

fail_open:
    MOV r0, #-1
    B end_init

fail_mmap:
    MOV r0, r4          @ fd ainda está em r4
    MOV r7, #6          @ syscall: close
    svc 0
    MOV r0, #-1

end_init:
    POP {r4-r7, lr}
    BX lr

@ void close_hw_access(void)
@ Desfaz o mmap e fecha o arquivo
close_hw_access:
    PUSH {r4-r5, lr}

    @ Desmapeia ponte HPS-to-FPGA
    LDR r0, =H2F_bridge_ptr
    LDR r0, [r0]
    LDR r1, =MAP_SIZE
    LDR r1, [r1]
    MOV r7, #91         @ syscall: munmap
    svc 0

    @ Desmapeia ponte FPGA-to-HPS
    LDR r0, =F2H_bridge_ptr
    LDR r0, [r0]
    LDR r1, =MAP_SIZE
    LDR r1, [r1]
    MOV r7, #91
    svc 0

    @ Desmapeia ponte Lightweight
    LDR r0, =LW_bridge_ptr
    LDR r0, [r0]
    LDR r1, =MAP_SIZE
    LDR r1, [r1]
    MOV r7, #91
    svc 0

    @ Fecha /dev/mem
    LDR r0, =fd_close
    LDR r0, [r0]
    MOV r7, #6          @ syscall: close
    svc 0

    POP {r4-r5, lr}
    BX lr

@ Função de espera por sinal de pronto
wait_ready:
    PUSH {r4-r5, lr}
    LDR r4, =F2H_bridge_ptr
    LDR r4, [r4]
    ADD r4, r4, #F2H_STATUS_OFFSET
    
wait_loop:
    LDR r5, [r4]
    CMP r5, #1
    BNE wait_loop
    
    POP {r4-r5, lr}
    BX lr

@ int write_matrix_value(uint32_t offset, uint32_t value)
write_matrix_value:
    PUSH {r4-r5, lr}
    
    LDR r4, =H2F_bridge_ptr
    LDR r4, [r4]
    ADD r4, r4, r0, LSL #2  @ Calcula endereço: base + offset*4
    
    STR r1, [r4]            @ Escreve valor na memória
    
    MOV r0, #0              @ Retorna sucesso
    POP {r4-r5, lr}
    BX lr

@ int read_result_value(uint32_t offset, uint32_t* result)
read_result_value:
    PUSH {r4-r6, lr}
    
    BL wait_ready           @ Espera resultado ficar pronto
    
    LDR r4, =F2H_bridge_ptr
    LDR r4, [r4]
    ADD r4, r4, r0, LSL #2  @ Calcula endereço: base + offset*4
    
    LDR r5, [r4]            @ Lê valor da memória
    STR r5, [r1]            @ Armazena no ponteiro result
    
    @ Reseta flag de pronto
    ADD r4, r4, #F2H_STATUS_OFFSET
    MOV r5, #0
    STR r5, [r4]
    
    MOV r0, #0              @ Retorna sucesso
    POP {r4-r6, lr}
    BX lr

@ void send_all_data(const int8_t* a, const int8_t* b, uint32_t opcode, uint32_t size, uint32_t scalar)
send_all_data:
    PUSH {r4-r12, lr}

    MOV r4, r0      @ a
    MOV r5, r1      @ b
    MOV r6, r2      @ opcode
    MOV r7, r3      @ matrix_size
    LDR r8, [sp, #36] @ scalar

    @ Usa a ponte HPS-to-FPGA para enviar os dados combinados
    LDR r9, =H2F_bridge_ptr
    LDR r9, [r9]
    MOV r10, #0     @ índice

loop_send:
    CMP r10, #25
    BGE send_ctrl

    @ Verifica se pode enviar (buffer não está cheio)
    LDR r0, =LW_bridge_ptr
    LDR r0, [r0]
    LDR r1, [r0, #LW_STATUS_OFFSET]
    CMP r1, #1           @ 1 = buffer cheio
    BEQ loop_send        @ Espera até ter espaço

    @ Carrega valores de A e B (8 bits com sinal)
    LDRSB r11, [r4, r10]  @ valor de A
    LDRSB r12, [r5, r10]  @ valor de B

    @ Combina em um único valor de 16 bits:
    @ bits [7:0] = valor de A
    @ bits [15:8] = valor de B
    UXTB r11, r11          @ estende para 32 bits sem sinal
    UXTB r12, r12          @ estende para 32 bits sem sinal
    LSL r12, r12, #8       @ desloca valor B para bits [15:8]
    ORR r0, r11, r12       @ combina A e B

    @ Armazena na memória mapeada (32 bits)
    STR r0, [r9, r10, LSL #2]  @ endereço = base + (índice * 4)

    ADD r10, r10, #1       @ incrementa índice
    B loop_send

send_ctrl:
    @ Espera FPGA estar pronta para receber comandos
    LDR r0, =LW_bridge_ptr
    LDR r0, [r0]
    LDR r1, [r0, #LW_STATUS_OFFSET]
    CMP r1, #1
    BEQ send_ctrl          @ Espera até estar pronta

    @ Envia parâmetros de controle via Lightweight bridge
    LDR r9, =LW_bridge_ptr
    LDR r9, [r9]
    
    STR r6, [r9, #LW_OPCODE_OFFSET]
    STR r7, [r9, #LW_SIZE_OFFSET]
    STR r8, [r9, #LW_SCALAR_OFFSET]
    
    @ Inicia operação
    MOV r0, #1
    STR r0, [r9, #LW_START_OFFSET]

    POP {r4-r12, lr}
    BX lr

@ void read_all_results(int8_t* result)
read_all_results:
    PUSH {r4-r6, lr}

    MOV r4, r0      @ result
    MOV r5, #0      @ index

    BL wait_ready   @ Espera operação completar

    @ Lê resultados via FPGA-to-HPS
    LDR r6, =F2H_bridge_ptr
    LDR r6, [r6]

read_loop:
    CMP r5, #25
    BGE read_done
    
    LDR r0, [r6, r5, LSL #2]
    STRB r0, [r4, r5]
    
    ADD r5, r5, #1
    B read_loop

read_done:
    @ Reseta flag de pronto
    MOV r0, #0
    STR r0, [r6, #F2H_STATUS_OFFSET]

    POP {r4-r6, lr}
    BX lr

@ Constantes e Strings
.section .rodata
devmem_path: .asciz "/dev/mem"

.section .data
MAP_SIZE:       .word 0x00200000     @ 2MB
H2F_BASE:       .word 0xC0000000     @ HPS-to-FPGA AXI Master Bridge
F2H_BASE:       .word 0xC0100000     @ FPGA-to-HPS Bridge
LW_BRIDGE_BASE: .word 0xFF200000     @ Lightweight HPS-to-FPGA Bridge
fd_close:       .word 0
