.equ DELAY_CYCLES, 1000

.section .data
devmem_path: .asciz "/dev/mem"
LW_BRIDGE_BASE: .word 0xFF200000
LW_BRIDGE_SPAN: .word 0x1000

.global data_in_ptr
data_in_ptr: .word 0         @ file descriptor do open()

.global data_out_ptr
data_out_ptr: .word 0        @ ponteiro para base do data_in

.global fd_mem
fd_mem: .word 0              @ ponteiro para base do data_out

.align 2

.section .text

@ Definicao de funcoes
.global init_hw_access
.type init_hw_access, %function

.global close_hw_access
.type close_hw_access, %function

.global send_all_data
.type send_all_data, %function

.global read_all_results
.type read_all_results, %function


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
    PUSH {r4-r12, lr}
    
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

    @ --- Delay entre o sinal de reset e start          
    MOV r12, #DELAY_CYCLES              
    BL delay_loop  
    
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
    BL handshake_send       @ envia com handshake
    POP {r0}                @ Recupera o valor de r0 após a função
    
    ADD r10, r10, #1
    B loop_send
    
end_send:
    MOV r0, #0              @ Retorna sucesso
    POP {r4-r12, lr}
    BX lr

delay_loop:
    SUBS r12, r12, #1
    BNE delay_loop
    BX lr

@ void read_all_results(int8_t* result, uint8_t* overflow_flag)
read_all_results:
    PUSH {r4-r7, lr}

    MOV r4, r0      @ r4 = result
    MOV r5, r1      @ r5 = overflow_flag

    MOV r6, #25     @ número de elementos
    MOV r7, #0      @ índice

.loop_recv:
    CMP r7, r6
    BGE .done

    MOV r0, r4
    ADD r0, r0, r7  @ endereço de result[i]
    MOV r1, r5      @ sempre sobrescreve overflow_flag (último é o final)
    BL handshake_receive

    ADD r7, r7, #1
    B .loop_recv

.done:
    POP {r4-r7, lr}
    BX lr

@ void handshake_send(uint32_t value)
@ Entrada:
@   r0 = valor a ser enviado
handshake_send:
    PUSH {r1-r4, lr}

    @ r0 = valor original
    @ Lê ponteiro para data_in
    LDR r1, =data_in_ptr
    LDR r1, [r1]          @ r1 = endereço data_in

    @ Lê ponteiro para data_out
    LDR r2, =data_out_ptr
    LDR r2, [r2]          @ r2 = endereço data_out

    @ --- Etapa 1: Escreve valor com bit 31 ligado ---
    ORR r3, r0, #(1 << 31)     @ r3 = valor | HPS_CONTROL_BIT
    STR r3, [r1]               @ escreve no registrador data_in

    @ --- Etapa 2: Espera FPGA_ACK = 1 ---
.wait_ack_high:
    LDR r4, [r2]               @ lê data_out
    TST r4, #(1 << 31)         @ testa bit 31
    BEQ .wait_ack_high         @ se 0, continua esperando

    @ --- Etapa 3: Confirma recebimento → escreve 0 ---
    MOV r3, #0
    STR r3, [r1]               @ limpa controle

    @ --- Etapa 4: Espera FPGA_ACK = 0 ---
.wait_ack_low:
    LDR r4, [r2]
    TST r4, #(1 << 31)
    BNE .wait_ack_low          @ se ainda 1, espera

    @ --- Fim ---
    POP {r1-r4, lr}
    BX lr

@ void handshake_receive(uint8_t* value_out, uint8_t* overflow_out)
@ Entrada:
@   r0 = ponteiro para armazenar valor
@   r1 = ponteiro para armazenar overflow flag

handshake_receive:
    PUSH {r2-r5, lr}

    LDR r2, =data_in_ptr
    LDR r2, [r2]
    LDR r3, =data_out_ptr
    LDR r3, [r3]

    MOV r4, #(1 << 31)
    STR r4, [r2]              @ HPS_CONTROL = 1

.wait_ack_high:
    LDR r5, [r3]
    TST r5, #(1 << 31)
    BEQ .wait_ack_high

    @ Extrai valor (bits [7:0])
    AND r4, r5, #0xFF
    STRB r4, [r0]             @ *value_out = valor

    @ Extrai overflow (bit 30)
    LSR r4, r5, #30           @ shift para bit 0
    AND r4, r4, #1
    STRB r4, [r1]             @ *overflow_out = bit 30

    @ Confirma leitura
    MOV r4, #0
    STR r4, [r2]

.wait_ack_low:
    LDR r5, [r3]
    TST r5, #(1 << 31)
    BNE .wait_ack_low

    POP {r2-r5, lr}
    BX lr
