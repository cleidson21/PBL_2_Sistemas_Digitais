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
LW_BRIDGE_BASE: .word 0xFF200000
LW_BRIDGE_SPAN: .word 0x00005000

.text

init_hw_access:
    PUSH {r4-r7, lr}
    LDR r0, =devmem_path
    MOV r1, #2
    MOV r2, #0
    MOV r7, #5      @ open
    svc 0
    CMP r0, #0
    BLT fail_open
    MOV r4, r0
    LDR r1, =fd_mem
    STR r4, [r1]

    MOV r0, #0
    LDR r1, =LW_BRIDGE_SPAN
    LDR r1, [r1]
    MOV r2, #3
    MOV r3, #1
    MOV r5, r4
    LDR r6, =LW_BRIDGE_BASE
    LDR r6, [r6]
    MOV r7, #192    @ mmap2
    svc 0
    CMP r0, #-1
    BEQ fail_mmap

    LDR r1, =data_in_ptr
    STR r0, [r1]
    ADD r1, r0, #0x10
    LDR r2, =data_out_ptr
    STR r1, [r2]

    MOV r0, #0
    B end_init

fail_open:
    MOV r0, #-1
    B end_init

fail_mmap:
    MOV r0, r4
    MOV r7, #6      @ close
    svc 0
    MOV r0, #-1

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
    svc 0

    LDR r0, =fd_mem
    LDR r0, [r0]
    MOV r7, #6      @ close
    svc 0

    POP {r4, lr}
    BX lr

@ void send_all_data(int8_t* a, int8_t* b, uint32_t opcode, uint32_t size, uint32_t scalar)
send_all_data:
    PUSH {r4-r11, lr}
    MOV r4, r0      @ a
    MOV r5, r1      @ b
    MOV r6, r2      @ opcode
    MOV r7, r3      @ size
    LDR r8, [sp, #36] @ scalar
    
    @ 1. Envia pulso de start
    BL send_start_pulse
    
    @ 2. Envia dados das matrizes
    MOV r9, #25             @ tamanho máximo
    MOV r10, #0
send_loop:
    CMP r10, r9
    BGE send_end

    LDRSB r0, [r4, r10]     @ MatA
    LDRSB r1, [r5, r10]     @ MatB
    LSL r1, r1, #8
    ORR r0, r0, r1
    ORR r0, r0, r6, LSL #16 @ Opcode
    ORR r0, r0, r7, LSL #19 @ Size
    ORR r0, r0, r8, LSL #21 @ Scalar
    
    BL handshake_send        

    ADD r10, r10, #1
    B send_loop
send_end:
    POP {r4-r11, lr}
    BX lr

@ int read_all_results(int8_t* result, uint32_t size)
read_all_results:
    PUSH {r4-r7, lr}
    MOV r4, r0      @ result
    MOV r5, r1      @ size
    ADD r5, r5, #2
    MUL r6, r5, r5  @ total elementos

    MOV r7, #0
recv_loop:
    CMP r7, r6
    BGE recv_end

    BL handshake_receive
    STRB r0, [r4, r7]

    ADD r7, r7, #1
    B recv_loop
recv_end:
    MOV r0, #0
    POP {r4-r7, lr}
    BX lr

@ Envia pulso de start
send_start_pulse:
    PUSH {r0-r2, lr}
    LDR r2, =data_in_ptr
    LDR r2, [r2]
    MOV r0, #(1 << 30)      @ Start bit
    STR r0, [r2]
    MOV r0, #0              @ Limpa
    STR r0, [r2]
    POP {r0-r2, lr}
    BX lr

@ Envia dados com handshake (r0 = dados)
handshake_send:
    PUSH {r1-r4, lr}
    MOV r1, #1              @ Flag de envio
    B handshake_common

@ Recebe dados (retorna em r0)
handshake_receive:
    PUSH {r1-r4, lr}
    MOV r1, #0              @ Flag de recebimento

handshake_common:
    LDR r2, =data_in_ptr
    LDR r2, [r2]
    MOV r3, #0
    STR r3, [r2]            @ Limpa controle

    CMP r1, #1
    BNE .recv_mode

.send_mode:
    ORR r3, r0, #(1 << 31) @ Dados + controle
    STR r3, [r2]
    B .wait_ack

.recv_mode:
    MOV r3, #(1 << 31)      @ Apenas controle
    STR r3, [r2]

.wait_ack:
    LDR r3, =data_out_ptr
    LDR r3, [r3]
    LDR r3, [r3]
    TST r3, #(1 << 31)
    BEQ .wait_ack           @ Espera ACK

    CMP r1, #1
    BNE .read_data

.confirm_send:
    STR r0, [r2]            @ Confirma envio
    B .wait_completion

.read_data:
    AND r0, r3, #0xFF       @ Extrai dados
    MOV r3, #0
    STR r3, [r2]            @ Limpa

.wait_completion:
    LDR r3, =data_out_ptr
    LDR r3, [r3]
    LDR r3, [r3]
    TST r3, #(1 << 31)
    BNE .wait_completion    @ Espera finalização

    POP {r1-r4, lr}
    BX lr