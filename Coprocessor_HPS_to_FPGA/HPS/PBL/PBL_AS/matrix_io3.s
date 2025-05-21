.section .data
devmem_path: .asciz "/dev/mem"
LW_BRIDGE_BASE: .word 0xFF200
LW_BRIDGE_SPAN: .word 0x1000
ADDRESS_MAPPED:  .space   4
ADDRESS_FD:      .space   4

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

.align 4
.global data_in_ptr
data_in_ptr: .word 0

.global data_out_ptr
data_out_ptr: .word 0

.global fd_mem
fd_mem: .word 0

init_hw_access:
    PUSH {r1-r7, lr}
    @ --- Abre /dev/mem ---
    LDR r0, =devmem_path
    MOV r1, #2              @ O_RDWR
    MOV r2, #0
    MOV r7, #5              @ syscall open
    SVC 0
    CMP r0, #0
    BLT fail_open           @ Corrigido: sintaxe de branch

    @ --- Salva file descriptor ---
    LDR r1, =fd_mem
    STR r0, [r1]

    @ --- Mapeia memória ---
    MOV r0, #0              @ addr = NULL (deixe o kernel escolher)
    LDR r1, =LW_BRIDGE_SPAN
    LDR r1, [r1]
    MOV r2, #3              @ PROT_READ | PROT_WRITE
    MOV r3, #1              @ MAP_SHARED
    LDR r4, =fd_mem
    LDR r4, [r4]
    LDR r5, =LW_BRIDGE_BASE
    LDR r5, [r5]
    LSR r5, r5, #12         @ Corrigido: converter para offset de página (dividido por 4096)
    MOV r7, #192            @ syscall mmap2
    SVC 0
    
    CMP r0, #-1             @ Corrigido: verificação de erro adequada para mmap
    BEQ fail_mmap           @ Corrigido: sintaxe de branch

    LDR r1, =data_in_ptr
    STR r0, [r1]
    ADD r1, r0, #0x10
    LDR r2, =data_out_ptr
    STR r1, [r2]
    MOV r0, #0
    B end_init

fail_open:
    MOV r7, #1              @ syscall exit
    MOV r0, #1              @ código de saída 1
    SVC 0
    B end_init

fail_mmap:
    MOV r7, #1              @ syscall exit
    MOV r0, #2              @ código de saída 2
    SVC 0

end_init:
    POP {r1-r7, lr}         @ Corrigido: POP com mesmos registradores do PUSH
    BX lr

close_hw_access:
    PUSH {r4-r7, lr}        @ Expandido para manter consistência
    LDR r0, =data_in_ptr
    LDR r0, [r0]
    LDR r1, =LW_BRIDGE_SPAN
    LDR r1, [r1]
    MOV r7, #91             @ syscall munmap
    SVC 0
    
    LDR r0, =fd_mem
    LDR r0, [r0]
    MOV r7, #6              @ syscall close
    SVC 0
    
    POP {r4-r7, lr}
    BX lr

send_all_data:
    PUSH {r4-r9, lr}         @ Salva registradores
    
    @ Envia pulso de start para o módulo da FPGA
    LDR r2, =data_in_ptr
    LDR r2, [r2]             @ r2 = endereço base do registrador data_in
    
    @ Ativa o bit de start (bit 30)
    MOV r9, #1
    LSL r9, r9, #30          @ Bit 30 = 1 (0x40000000)
    STR r9, [r2]             @ Escreve com start bit ativo
    
    @ Pequeno delay para garantir que o sinal seja percebido
    MOV r0, #1000
delay_loop:
    SUBS r0, r0, #1
    BNE delay_loop
    
    @ Limpa o bit de start
    MOV r9, #0
    STR r9, [r2]             @ Escreve com start bit desativado
    
    POP {r4-r9, lr}
    BX lr          @ escreve com reset bit ativo


read_all_results:
