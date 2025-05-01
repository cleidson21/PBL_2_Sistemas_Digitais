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

@ Ponteiros globais
.data
.align 4
.global LW_bridge_ptr
LW_bridge_ptr: .word 0

.text

@ int init_hw_access(void)
@ Abre /dev/mem e faz mmap da ponte lightweight
@ Retorna 0 em sucesso, -1 em falha

init_hw_access:
    PUSH {r4-r7, lr}

    LDR r0, =devmem_path
    MOV r1, #2          @ O_RDWR
    MOV r2, #0
    MOV r7, #5          @ syscall: open
    svc 0
    CMP r0, #0
    BLT fail_open
    MOV r4, r0          @ fd = r4

    MOV r0, #0          @ addr = NULL
    LDR r1, =MAP_SIZE   @ length
    LDR r1, [r1]        @ Carrega o valor real
    MOV r2, #3          @ PROT_READ | PROT_WRITE
    MOV r3, #1          @ MAP_SHARED
    MOV r5, r4          @ fd
    LDR r6, =LW_BRIDGE_BASE
    LDR r6, [r6]        @ Carrega o endereço base real
    MOV r7, #192        @ syscall: mmap2
    svc 0
    CMP r0, #-1
    BEQ fail_mmap

    LDR r1, =LW_bridge_ptr
    STR r0, [r1]        @ LW_bridge_ptr = retorno do mmap
    LDR r1, =fd_close
    STR r4, [r1]        @ Armazena o fd para fechamento posterior
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

    LDR r0, =LW_bridge_ptr
    LDR r0, [r0]        @ ponteiro mmap
    LDR r1, =MAP_SIZE
    MOV r7, #91         @ syscall: munmap
    svc 0

    LDR r0, =fd_close
    LDR r0, [r0]
    MOV r7, #6          @ syscall: close
    svc 0

    POP {r4-r5, lr}
    BX lr


@ void send_all_data(const int8_t* a, const int8_t* b, uint32_t opcode, uint32_t size, uint32_t scalar)

send_all_data:
    PUSH {r4-r12, lr}

    MOV r4, r0      @ a
    MOV r5, r1      @ b
    MOV r6, r2      @ opcode
    MOV r7, r3      @ matrix_size
    LDR r8, [sp, #36] @ scalar (offset depende da pilha: 36 = +9 regs * 4)

    LDR r9, =LW_bridge_ptr
    LDR r9, [r9]    @ ponteiro base mapeado

    MOV r10, #0

loop_send:
    CMP r10, #25
    BGE send_ctrl

    LDRSB r11, [r4, r10]
    LDRSB r12, [r5, r10]
    UXTB r11, r11
    UXTB r12, r12
    LSL r12, r12, #8
    ORR r1, r11, r12

    ADD r0, r9, r10, LSL #2
    STR r1, [r0]

    ADD r10, r10, #1
    B loop_send

send_ctrl:
    STR r6, [r9, #0xF0 << 2] @ opcode
    STR r7, [r9, #0xF1 << 2] @ matrix_size
    STR r8, [r9, #0xF2 << 2] @ scalar
    MOV r0, #1
    STR r0, [r9, #0xFE << 2] @ start

    POP {r4-r12, lr}
    BX lr


@ void read_all_results(int8_t* result)

read_all_results:
    PUSH {r4-r6, lr}

    MOV r4, r0
    MOV r5, #0

    LDR r6, =LW_bridge_ptr
    LDR r6, [r6]

loop_read:
    CMP r5, #25
    BGE end_read

    ADD r0, r6, r5, LSL #2
    LDR r1, [r0]
    UXTB r1, r1
    STRB r1, [r4, r5]

    ADD r5, r5, #1
    B loop_read

end_read:
    POP {r4-r6, lr}
    BX lr


@ Constantes e Strings

.section .rodata
devmem_path: .asciz "/dev/mem"

.section .data
MAP_SIZE:       .word 0x00001000     @ 4KB
LW_BRIDGE_BASE: .word 0xFF200000
fd_close:       .word 0

