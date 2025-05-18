	module ControlUnit (
	input  wire        clk,
	input  wire [31:0] data_in,   // HPS -> FPGA (0x0 - 0xf)
	output reg  [31:0] data_out    // FPGA -> HPS (0x10 - 0x1f)	
	);

	// Estados da FSM
	localparam IDLE      = 2'b00,
				RECEIVING   = 2'b01,
				PROCESSING  = 2'b10,
				SENDING     = 2'b11;

	reg [2:0] state;

	// Controles de sincronização
	reg fpga_wait;      					// Indica se FPGA está pronto (1 = ocupado)
	reg [2:0] hps_ready_sync;
	reg hps_ready_prev;  				// Adicionado registro para detecção de borda	 

	// Controles de operação
	reg [4:0] index;    					// Índice para matrizes (0-24)
	reg [2:0] op_code;
	reg [1:0] matrix_size;
	reg [7:0] scalar;
	reg start_flag;

	// Matrizes internas
	reg signed [7:0] matrix_a [0:24];
	reg signed [7:0] matrix_b [0:24];
	reg signed [7:0] matrix_result [0:24];
	reg overflow_flag;

	// Interface com coprocessador
	wire [199:0] matrix_a_flat, matrix_b_flat;
	wire [199:0] matrix_out;
	wire done_signal, overflow_signal;

	// Decodificação de entrada
	wire [7:0]  val_a     = data_in[7:0];
	wire [7:0]  val_b     = data_in[15:8];
	wire [2:0]  opcode_in = data_in[18:16];
	wire [1:0]  size_in   = data_in[20:19];
	wire [7:0]  scalar_in = data_in[28:21];
	wire 			reset     = data_in[29];
	wire        start_in  = data_in[30];

	integer i; // Variável de iteração para o loop for
	 
	 // Sincronização (ordem dos bits)
	always @(posedge clk or posedge reset) begin
		 if (reset) begin
			  hps_ready_sync <= 3'b000;
			  hps_ready_prev <= 1'b0;  										// Inicializado
		 end else begin
			  hps_ready_sync <= {hps_ready_sync[1:0], data_in[31]};  // Ordem correta
			  hps_ready_prev <= hps_ready_sync[2];  					 	// Atualiza o valor anterior
		 end
	end
	
	// Detecção de borda
   wire hps_ready_edge = hps_ready_sync[2] && !hps_ready_prev;

	// FSM principal
	always @(posedge clk or posedge reset) begin : main_fsm
		if (reset) begin
			state <= IDLE;
			index <= 0;
			fpga_wait <= 0;
			for (i = 0; i < 25; i = i + 1) begin
				matrix_a[i] <= 8'b0;
				matrix_b[i] <= 8'b0;
			end
		end 
		else begin
			case (state)
				IDLE: begin
					if (start_in) begin
						index       <= 0;
						state  		<= RECEIVING;
					end 
				end

				RECEIVING: begin 
					if (hps_ready_edge) begin
						op_code     <= opcode_in;
						matrix_size <= size_in;
						scalar      <= scalar_in;
						matrix_a[index] <= val_a;
						matrix_b[index] <= val_b;
						index <= index + 1;
						if (index == 24) begin
							index       <= 0;
							state <= PROCESSING;
                  end
               end
				end
				PROCESSING: begin
					if (done_signal) begin
						overflow_flag <= overflow_signal;
						for (i = 0; i < 25; i = i + 1) begin
							matrix_result[i] <= matrix_out[(i*8) +: 8];
						end
						index <= 0;
						state <= SENDING;
					end 
				end

				SENDING: begin
					// Detecção de borda de subida 
					if (hps_ready_edge) begin
						if (index == 25) begin
							state <= IDLE;
						end
						index <= index + 1; 
					end
				end
			endcase
			// Geração do sinal de sincronização
			fpga_wait <= ((state == RECEIVING) || (state == SENDING)) && hps_ready_sync[2];
		end
	end
	
	// Saídas - Bit 31 = fpga_ack, bits 7:0 = dados
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			data_out <= 32'b0;
		end else begin
			data_out <= {fpga_wait, overflow_flag, 22'b0, (state == SENDING) ? matrix_result[index-1] : 8'b0};
		end
	end

	// Bloco generate nomeado para flatten das matrizes
	generate
		genvar j;
		for (j = 0; j < 25; j = j + 1) begin : matrix_flatten
			assign matrix_a_flat[(j*8) +: 8] = matrix_a[j];
			assign matrix_b_flat[(j*8) +: 8] = matrix_b[j];
		end
	endgenerate

	// Instância do coprocessador
	Coprocessor matrix_coprocessor (
		.op_code(op_code),
		.matrix_size(matrix_size),
		.matrix_a(matrix_a_flat),
		.matrix_b(matrix_b_flat),
		.scalar(scalar),
		.result_final(matrix_out),
		.overflow(overflow_signal),
		.process_Done(done_signal)
	);

endmodule