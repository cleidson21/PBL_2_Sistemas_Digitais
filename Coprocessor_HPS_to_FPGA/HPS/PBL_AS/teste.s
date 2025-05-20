.syntax unified
.cpu cortex-a9
.text

.global _start

.section .data
devmem_path:      .asciz "/dev/mem"
fd_mem:           .word 0
virtual_base:     .word 0

.section .text

_start:
    @ --- Abrir /dev/mem ---
    LDR r0, =devmem_path
    MOV r1, #2          @ O_RDWR
    MOV r2, #0          @ sem flags
    MOV r7, #5          @ syscall: open
    SVC 0
    CMP r0, #0
    BLT fail_open
    LDR r1, =fd_mem
    STR r0, [r1]        @ salva fd

    @ --- Mapeamento mmap ---
    MOV r0, #0          @ endereço sugerido
    LDR r1, =0x5000     @ span (20 KB)
    MOV r2, #3          @ PROT_READ | PROT_WRITE
    MOV r3, #1          @ MAP_SHARED
    LDR r4, =fd_mem
    LDR r4, [r4]
    LDR r5, =0xFF200000 @ endereço base da ponte
    MOV r7, #192        @ syscall: mmap2
    SVC 0
    CMP r0, #-1
    BEQ fail_mmap

    LDR r1, =virtual_base
    STR r0, [r1]

    @ --- Escreve valor no data_in (offset 0x00) ---
    MOV r1, #0x80000000
    STR r1, [r0]        @ *data_in = 0x80000000 (sinal de start)

    @ --- Delay para observar ---
    MOV r2, #0x2000000
delay_loop:
    SUBS r2, r2, #1
    BNE delay_loop

    @ --- Fechar mmap ---
    MOV r1, #0x5000
    MOV r7, #91         @ syscall: munmap
    SVC 0

    @ --- Fechar /dev/mem ---
    LDR r0, =fd_mem
    LDR r0, [r0]
    MOV r7, #6          @ syscall: close
    SVC 0

    @ --- Sair ---
    MOV r7, #1
    MOV r0, #0
    SVC 0

fail_open:
    MOV r7, #1
    MOV r0, #1
    SVC 0

fail_mmap:
    MOV r7, #1
    MOV r0, #2
    SVC 0
