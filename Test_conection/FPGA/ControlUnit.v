module ControlUnit (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] data_in,
    output reg  [31:0] data_out,
    output reg  [3:0]  debug_state
);

// Estados e parâmetros
localparam IDLE = 2'b00, RECEIVING = 2'b01, PROCESS = 2'b10, SENDING = 2'b11;

// Registradores
reg [1:0] state;
reg [7:0] received_data [0:15];
reg [3:0] data_counter;
reg [7:0] results [0:7];
reg fpga_ack;
reg hps_ready_prev;
reg [2:0] hps_ready_sync;
integer i;

// Sincronização
always @(posedge clk or posedge reset) begin
    if (reset) hps_ready_sync <= 3'b000;
    else hps_ready_sync <= {hps_ready_sync[1:0], data_in[31]};
end

// Lógica principal
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        fpga_ack <= 0;
        data_counter <= 0;
        // Inicialização otimizada
        for ( i = 0; i < 16; i = i + 1) received_data[i] <= 8'b0;
    end else begin
        hps_ready_prev <= hps_ready_sync[2];
        
        case (state)
            IDLE: if (data_in[30]) state <= RECEIVING;
            
            RECEIVING: begin
                if (hps_ready_sync[2] && !hps_ready_prev) begin
                    received_data[data_counter] <= data_in[7:0];
                    data_counter <= (data_counter == 15) ? 0 : data_counter + 1;
                    state <= (data_counter == 15) ? PROCESS : RECEIVING;
                end
            end
            
            PROCESS: begin
                for ( i = 0; i < 8; i = i + 1) begin
                    results[i] <= received_data[i] + received_data[i+8];
                end
                state <= SENDING;
            end
            
            SENDING: begin
                if (hps_ready_sync[2] && !hps_ready_prev) begin
                    data_counter <= (data_counter == 7) ? 0 : data_counter + 1;
                    state <= (data_counter == 7) ? IDLE : SENDING;
                end
            end
        endcase
        
        fpga_ack <= (state == RECEIVING || state == SENDING) && 
                   hps_ready_sync[2] && !hps_ready_prev;
    end
end

// Saídas
always @(*) begin
    data_out = {22'b0, fpga_ack, (state == SENDING) ? results[data_counter] : 8'b0};
    case(state)
        IDLE:      debug_state = 4'b0001;
        RECEIVING: debug_state = 4'b0010;
        PROCESS:   debug_state = 4'b0100;
        SENDING:   debug_state = 4'b1000;
        default:   debug_state = 4'b0000;
    endcase
end

endmodule