.equ DELAY_CYCLES, 10

.section .data
devmem_path: .asciz "/dev/mem"
LW_BRIDGE_BASE: .word 0xff200
LW_BRIDGE_SPAN: .word 0x1000

.global data_in_ptr
data_in_ptr: .word 0         @ ponteiro para base do data_in

.global data_out_ptr
data_out_ptr: .word 0       @ ponteiro para base do data_out

.global fd_mem
fd_mem: .space 4              @ file descriptor do open()

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
    @salva os valores dos registradores na pilha
    PUSH {r1-r7, lr}
    @ --- Abre /dev/mem ---
    MOV r7, #5      @ open
    LDR r0, =devmem_path
    MOV r1, #2
    MOV r2, #0
    SVC 0

    CMP r0, #0
    BLT fail_open
    
    @ --- Salva file descriptor ---
    LDR r1, =fd_mem
    str r0, [r1]
    mov r4, r0              @guarda em r4

    @ --- Mapeia memória ---
    MOV r7, #192    @ mmap2
    MOV r0, #0
    LDR r1, =LW_BRIDGE_SPAN
    LDR r1, [r1]
    MOV r2, #3
    MOV r3, #1
    LDR r5, =LW_BRIDGE_BASE
    LDR r5, [r5]
    SVC 0

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
    mov r7, #1
    mov r0, #1
    svc #0
    B end_init

fail_mmap:
    mov r7, #1
    mov r0, #2
    svc #0

end_init:
    POP {r1-r7, lr}
    BX lr

@ int close_hw_access()
@ Libera os recursos alocados por init_hw_access
@ Retorna: 0 (HW_SUCCESS) em caso de sucesso, ou código de erro em caso de falha
close_hw_access:
    PUSH {r4-r7, lr}
    
    @ Verifica se o ponteiro mapeado é válido
    LDR r0, =data_in_ptr
    LDR r0, [r0]
    CMP r0, #0
    BEQ skip_munmap    @ Se for NULL, pula o munmap
    
    @ Desmapeia a memória
    MOV r7, #91       @ syscall munmap
    @ r0 já contém o ponteiro para o início da região mapeada
    LDR r1, =LW_BRIDGE_SPAN
    LDR r1, [r1]      @ Tamanho do mapeamento
    SVC 0
    
    @ Limpa os ponteiros após o munmap
    MOV r4, #0
    LDR r5, =data_in_ptr
    STR r4, [r5]
    LDR r5, =data_out_ptr
    STR r4, [r5]
    
skip_munmap:
    @ Verifica se o descritor de arquivo é válido
    LDR r0, =fd_mem
    LDR r0, [r0]
    CMP r0, #0
    BLE skip_close    @ Se inválido, pula o close
    
    @ Fecha o descritor de arquivo
    MOV r7, #6        @ syscall close
    SVC 0
    
    @ Limpa o descritor de arquivo
    MOV r4, #-1
    LDR r5, =fd_mem
    STR r4, [r5]
    
skip_close:
    MOV r0, #0        @ Retorna HW_SUCCESS
    POP {r4-r7, lr}
    BX lr

@ void send_all_data(*params)
@ params = {int8_t* a, int8_t* b, uint32_t opcode, uint32_t size, uint32_t scalar}
send_all_data:
    PUSH {r4-r11, lr}
    
    @ R0 = ponteiro para struct Params
    LDR r4, [r0]            @ a
    LDR r5, [r0, #4]        @ b
    LDR r6, [r0, #8]        @ opcode
    LDR r7, [r0, #12]       @ size
    LDR r8, [r0, #16]       @ scalar
    
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
    MOV r11, #DELAY_CYCLES              
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
    POP {r4-r11, lr}
    BX lr

delay_loop:
    SUBS r11, r11, #1
    BNE delay_loop
    BX lr

@ int read_all_results(int8_t* result, uint8_t* overflow_flag)
@ Retorna HW_SUCCESS (0) se bem-sucedido ou HW_ERROR (1) se falhar
read_all_results:
    PUSH {r4-r7, lr}
    MOV r4, r0           @ r4 = result (ponteiro para armazenar matriz)
    MOV r5, r1           @ r5 = overflow_flag (ponteiro para armazenar flag de overflow)
    MOV r6, #25          @ número de elementos na matriz
    MOV r7, #0           @ índice inicial

.loop_recv:
    CMP r7, r6
    BGE .done            @ Se já lemos todos elementos, terminamos
    
    MOV r0, r4
    ADD r0, r0, r7       @ r0 = &result[i] (endereço onde armazenar o próximo elemento)
    MOV r1, r5           @ r1 = overflow_flag (atualizado em cada leitura, último valor é o final)
    BL handshake_receive @ Chama a função para receber um elemento da FPGA
    
    CMP r0, #0           @ Verifica se handshake_receive teve sucesso
    BNE .error           @ Se falhou, sai com erro
    
    ADD r7, r7, #1       @ Incrementa o índice
    B .loop_recv         @ Continua o loop

.error:
    MOV r0, #1           @ Código de erro (HW_ERROR = 1)
    B .exit

.done:
    MOV r0, #0           @ Código de sucesso (HW_SUCCESS = 0)

.exit:
    POP {r4-r7, lr}
    BX lr                @ Retorna para o chamador

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
.wait_ack_high_send:
    LDR r4, [r2]               @ lê data_out
    TST r4, #(1 << 31)         @ testa bit 31
    BEQ .wait_ack_high_send         @ se 0, continua esperando

    @ --- Etapa 3: Confirma recebimento → escreve 0 ---
    MOV r3, #0
    STR r3, [r1]               @ limpa controle

    @ --- Etapa 4: Espera FPGA_ACK = 0 ---
.wait_ack_low_send:
    LDR r4, [r2]
    TST r4, #(1 << 31)
    BNE .wait_ack_low_send          @ se ainda 1, espera

    @ --- Fim ---
    POP {r1-r4, lr}
    BX lr

@ int handshake_receive(uint8_t* value_out, uint8_t* overflow_out)
@ Entrada:
@ r0 = ponteiro para armazenar valor de matriz
@ r1 = ponteiro para armazenar overflow flag
@ Saída:
@ r0 = código de status (0 = sucesso, 1 = erro)
handshake_receive:
    PUSH {r2-r5, lr}
    
    @ Carrega endereços dos registradores de interface com a FPGA
    LDR r2, =data_in_ptr     @ r2 = ponteiro para registrador de entrada (HPS->FPGA)
    LDR r2, [r2]
    LDR r3, =data_out_ptr    @ r3 = ponteiro para registrador de saída (FPGA->HPS)
    LDR r3, [r3]
    
    @ Verifica se os ponteiros são válidos
    CMP r2, #0
    BEQ .handshake_error     @ Erro se data_in_ptr for NULL
    CMP r3, #0
    BEQ .handshake_error     @ Erro se data_out_ptr for NULL
    
    @ Envia sinal de pronto para FPGA
    MOV r4, #(1 << 31)       @ Bit 31 = 1 (HPS está pronto)
    STR r4, [r2]             @ HPS_CONTROL = 1 (bit 31)
    
    @ Aguarda FPGA sinalizar que enviou dados (bit 31=1 em data_out)
.wait_ack_high_recei:
    LDR r5, [r3]             @ Lê o registrador da FPGA
    TST r5, #(1 << 31)       @ Testa se bit 31 está ativo
    BEQ .wait_ack_high_recei @ Continua esperando se não estiver
    
    @ Extrai o valor da matriz (bits [7:0])
    AND r4, r5, #0xFF        @ Isola os 8 bits menos significativos
    STRB r4, [r0]            @ Armazena no ponteiro value_out
    
    @ Extrai o flag de overflow (bit 30)
    LSR r4, r5, #30          @ Desloca bit 30 para posição 0
    AND r4, r4, #1           @ Isola apenas o bit
    STRB r4, [r1]            @ Armazena no ponteiro overflow_out
    
    @ Confirma a leitura desativando o bit de controle
    MOV r4, #0
    STR r4, [r2]             @ HPS_CONTROL = 0
    
    @ Aguarda FPGA desativar seu sinal de pronto
.wait_ack_low_recei:
    LDR r5, [r3]
    TST r5, #(1 << 31)
    BNE .wait_ack_low_recei  @ Continua esperando enquanto bit 31=1
    
    MOV r0, #0               @ Retorna sucesso
    B .handshake_exit
    
.handshake_error:
    MOV r0, #1               @ Retorna erro

.handshake_exit:
    POP {r2-r5, lr}
    BX lr
    