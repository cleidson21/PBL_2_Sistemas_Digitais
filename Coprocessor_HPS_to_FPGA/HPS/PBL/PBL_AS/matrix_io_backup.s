.syntax unified
.cpu cortex-a9
.text

.global init_hw_access
.global close_hw_access
.global send_all_data
.global read_all_results

.type init_hw_access, %function
.type close_hw_access, %function
.type send_all_data, %function
.type read_all_results, %function

.section .init_array, "aw"
.align 2
.word init_hw_access

.data
.align 4
.global data_in_ptr
data_in_ptr: .word 0

.global data_out_ptr
data_out_ptr: .word 0

.global fd_mem
fd_mem: .word 0

.section .rodata
devmem_path: .asciz "/dev/mem"
LW_BRIDGE_BASE: .word 0xFF200
LW_BRIDGE_SPAN: .word 0x1000

.text

init_hw_access:
    PUSH {r1-r7, lr}

    @ --- Abre /dev/mem ---
    LDR r0, =devmem_path
    MOV r1, #2
    MOV r2, #0
    MOV r7, #5      @ open
    SVC 0

    CMP r0, #0
    BLT fail_open
    
    @ --- Salva file descriptor ---
    LDR r1, =fd_mem
    str r0, [r1]

    @ --- Mapeia memória ---
    @ Normalmente os periféricos da FPGA estão em 0xC0000000 no espaço virtual
    MOV r0, #0
    LDR r1, =LW_BRIDGE_SPAN
    LDR r1, [r1]
    MOV r2, #3
    MOV r3, #1
    LDR r4, =fd_mem
    LDR r4, [r4]
    LDR r5, =LW_BRIDGE_BASE
    LDR r5, [r5]
    MOV r7, #192    @ mmap2
    SVC 0

    CMP r0, #1
    BEQ fail_mmap

    LDR r1, =data_in_ptr    
    STR r0, [r1]
    ADD r1, r0, #0x10
    LDR r2, =data_out_ptr
    STR r1, [r2]

    MOV r0, #0
    B end_init

fail_open:
    mov r7, #1
    mov r0, #1
    svc #0
    B end_init

fail_mmap:
     mov r7, #1
    mov r0, #2
    svc #0

end_init:
    POP {r4-r7, lr}
    BX lr

close_hw_access:
    PUSH {r4, lr}
    LDR r0, =data_in_ptr
    LDR r0, [r0]
    LDR r1, =LW_BRIDGE_SPAN
    LDR r1, [r1]
    MOV r7, #91     @ munmap
    SVC 0

    LDR r0, =fd_mem
    LDR r0, [r0]
    MOV r7, #6      @ close
    SVC 0

    POP {r4, lr}
    BX lr

@ void send_all_data(*params)
@ params = {int8_t* a, int8_t* b, uint32_t opcode, uint32_t size, uint32_t scalar}
send_all_data:
    PUSH {r4-r11, lr}
    
    @ R0 = ponteiro para struct Params
    LDR r4, [r0]      @ a
    LDR r5, [r0, #4]  @ b
    LDR r6, [r0, #8]  @ opcode
    LDR r7, [r0, #12] @ size
    LDR r8, [r0, #16] @ scalar
    
    @ Envia pulso de reset e de start para o módulo da FPGA
    LDR r2, =data_in_ptr
    LDR r2, [r2]            @ r2 = endereço base do registrador data_in
    
    MOV r9, #1
    LSL r9, r9, #29
    MOV r0, r9              @ r0 = reset bit (bit 29 = 1)
    STR r0, [r2]            @ escreve com reset bit ativo
    MOV r0, #0
    STR r0, [r2]            @ limpa (pulso rápido)
    
    MOV r9, #1
    LSL r9, r9, #30
    MOV r0, r9              @ r0 = start bit (bit 30 = 1)
    STR r0, [r2]            @ escreve com start bit ativo
    MOV r0, #0
    STR r0, [r2]            @ limpa (pulso rápido)
    
    @ Inicializa contadores
    MOV r9, #25             @ número máximo de elementos (5x5)
    MOV r10, #0             @ índice = 0

loop_send:
    CMP r10, r9
    BGE end_send            @ sai do loop se índice >= 25
    
    @ Carrega valores das matrizes
    LDRSB r0, [r4, r10]     @ r0 = matrix_a[i], com sinal
    LDRSB r1, [r5, r10]     @ r1 = matrix_b[i], com sinal
    
    LSL r1, r1, #8          @ desloca B para posição [15:8]
    ORR r0, r0, r1          @ combina A e B nos bits [15:0]
    
    @ Adiciona os campos de controle
    ORR r0, r0, r6, LSL #16 @ insere opcode nos bits [17:16]
    ORR r0, r0, r7, LSL #19 @ insere size nos bits [20:19]
    ORR r0, r0, r8, LSL #21 @ insere scalar nos bits [23:21]
    
    PUSH {r0}               @ Salva o valor de r0 antes da chamada da função
    MOV r1, #1              @ sinaliza tipo de envio (1 = dado normal)
    BL handshake_transfer   @ envia com handshake
    POP {r0}                @ Recupera o valor de r0 após a função
    
    ADD r10, r10, #1
    B loop_send
    
end_send:
    MOV r0, #0              @ Retorna sucesso
    POP {r4-r11, lr}
    BX lr

@ int read_all_results(int8_t* result, uint8_t* overflow_flag)
read_all_results:
    PUSH {r4-r11, lr}
    MOV r4, r0
    MOV r5, r1
    
    MOV r4, r0              @ result
    MOV r5, r1              @ overflow_flag pointer
    
    @ Inicialmente, vamos ler 25 elementos (matriz 5x5 completa)
    MOV r6, #25             @ total elementos
    MOV r7, #0              @ contador
loop_recv:
    CMP r7, r6
    BGE read_overflow       @ Se terminou, lê a flag de overflow
    
    MOV r1, #0              @ indica leitura
    BL handshake_transfer   @ recebe com handshake
    
    STRB r0, [r4, r7]       @ armazena no buffer de resultado
    ADD r7, r7, #1
    B loop_recv
    
read_overflow:
    MOV r1, #0              @ indica leitura
    BL handshake_transfer   @ lê flag de overflow
    STRB r0, [r5]           @ armazena no endereço do overflow_flag
    
    MOV r0, #0              @ Retorna sucesso
    POP {r4-r11, lr}
    BX lr

@ handshake_transfer(value, is_send)
@ r0 = valor (ou buffer para retorno)
@ r1 = is_send (1 = envio, 0 = leitura)
handshake_transfer:
    PUSH {r2-r4, lr}
    
    LDR r2, =data_in_ptr
    LDR r2, [r2]
    MOV r3, #0
    STR r3, [r2]     @ limpa controle
    
    CMP r1, #1
    BNE .recv_ready
    
.send_ready:
    ORR r3, r0, #(1 << 31)
    STR r3, [r2]
    B .wait_ack1
    
.recv_ready:
    MOV r3, #(1 << 31)
    STR r3, [r2]
    B .wait_ack1
    
.wait_ack1:
    LDR r3, =data_out_ptr
    LDR r3, [r3]
    LDR r3, [r3]
    TST r3, #(1 << 31)
    BEQ .wait_ack1
    
    CMP r1, #1
    BEQ .confirm_send
    
    AND r0, r3, #0xFF  @ leitura
    MOV r3, #0
    STR r3, [r2]
    B .wait_ack0
    
.confirm_send:
    MOV r3, #0
    STR r3, [r2]      @ Limpa o bit HPS_CONTROL
    
.wait_ack0:
    LDR r3, =data_out_ptr
    LDR r3, [r3]
    LDR r3, [r3]
    TST r3, #(1 << 31)
    BNE .wait_ack0
    
    POP {r2-r4, lr}
    BX lr
    