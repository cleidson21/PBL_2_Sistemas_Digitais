module ControlUnit (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] data_in,
    output reg  [31:0] data_out,
    output reg  [3:0]  debug_state,
    output start,
    output entrada,
    output reg saida
);

// Estados e parâmetros
localparam IDLE = 2'b00, RECEIVING = 2'b01, PROCESS = 2'b10, SENDING = 2'b11;

// Registradores
reg [1:0] state;
reg [7:0] received_data [0:15];
reg [3:0] data_counter;
reg [7:0] results [0:7];
reg fpga_ack;
reg [2:0] hps_ready_sync;
reg hps_ready_prev;  // Adicionado registro para detecção de borda
integer i;

// Atribuições de saída para debug
assign start = data_in[30];
assign entrada = data_in[31];
// assign saida = data_out[31];  // Corrigido para bit 30 (fpga_ack)

// Sincronização CORRIGIDA (ordem dos bits)
always @(posedge clk or posedge reset) begin
    if (reset) begin
        hps_ready_sync <= 3'b000;
        hps_ready_prev <= 1'b0;  // Inicializado
    end else begin
        hps_ready_sync <= {hps_ready_sync[1:0], data_in[31]};  // Ordem correta
        hps_ready_prev <= hps_ready_sync[2];  // Atualiza o valor anterior
    end
end

// Lógica principal CORRIGIDA
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        fpga_ack <= 0;
        data_counter <= 0;
        // Inicialização otimizada
        for (i = 0; i < 16; i = i + 1) received_data[i] <= 8'b0;
    end else begin
        case (state)
            IDLE: begin
                if (data_in[30]) begin  // Start pulse
                    state <= RECEIVING;
                    data_counter <= 0;  // Reset counter when starting
						  saida <= 0;
                end
            end
            
            RECEIVING: begin
                // Detecção de borda de subida CORRIGIDA
                if (hps_ready_sync[2] && !hps_ready_prev) begin
						  saida <= 1'b1 	;
                    received_data[data_counter] <= data_in[7:0];
                    data_counter <= data_counter + 1;
                    
                    if (data_counter == 15) begin
                        state <= PROCESS;
                    end
                end
            end
            
            PROCESS: begin
                // Processamento em um ciclo
                for (i = 0; i < 8; i = i + 1) begin
                    results[i] <= received_data[i] + received_data[i+8];
                end
                state <= SENDING;
                data_counter <= 0;  // Reset counter for sending
            end
            
            SENDING: begin
                // Detecção de borda de subida CORRIGIDA
                if (hps_ready_sync[2] && !hps_ready_prev) begin
                    data_counter <= data_counter + 1;   
                    if (data_counter == 7) begin
                        state <= IDLE;
                    end
                end
            end
            
            default: state <= IDLE;
        endcase
        
        // Geração do sinal de acknowledge CORRIGIDA
        fpga_ack <= ((state == RECEIVING) || (state == SENDING)) && hps_ready_sync[2];
    end
end

// Saídas CORRIGIDAS
always @(*) begin
    // Bit 31 = fpga_ack, bits 7:0 = dados
    data_out = {fpga_ack, 23'b0, (state == SENDING) ? results[data_counter] : 8'b0};
    
    case(state)
        IDLE:      debug_state = 4'b0001;
        RECEIVING: debug_state = 4'b0010;
        PROCESS:   debug_state = 4'b0100;
        SENDING:   debug_state = 4'b1000;
        default:   debug_state = 4'b0000;
    endcase
end

endmodule