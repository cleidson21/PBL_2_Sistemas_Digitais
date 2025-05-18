module Coprocessor (
    input [2:0] op_code,                   		// Código da operação a ser executada (adição, subtração, etc.)
    input [1:0] matrix_size,               		// Define o tamanho da matriz (2x2, 3x3, 4x4, 5x5)
    input [199:0] matrix_a,            			// Matriz A de entrada
    input [199:0] matrix_b,              			// Matriz B de entrada
    input signed [7:0] scalar,                  // Valor escalar para multiplicação
    output reg overflow,                        // Sinaliza overflow em operações
    output reg process_Done,                    // Sinaliza que o processamento foi concluído
    output reg [199:0] result_final     			// Resultado final da operação                          
);

    // Resultados intermediários para cada operação
    wire [199:0] result_add, result_sub, result_transpose, result_opposite, result_mult_esc, result_matrix_mult;
    wire overflow_add, overflow_sub, overflow_matrix_mult, overflow_scalar, overflow_determinant;
    wire signed [7:0] determinant_result;      
    wire determinant_done;  

   // Instância dos módulos combinacionais que realizam as operações de matriz
   MatrixAdder adder (
        .matrix_A(matrix_a),
        .matrix_B(matrix_b),
        .matrix_size(matrix_size),
        .result_out(result_add),             // Resultado da adição
        .overflow(overflow_add)              // Sinal de overflow na adição
    );

   MatrixSubtractor subtractor (
        .matrix_A(matrix_a),
        .matrix_B(matrix_b),
        .matrix_size(matrix_size),
        .result_out(result_sub),             // Resultado da subtração
        .overflow(overflow_sub)              // Sinal de overflow na subtração
    );

    transposicao_matriz transpose (
        .matrix_A(matrix_a),                  
        .matrix_size(matrix_size),            
        .m_transposta_A(result_transpose)     // Matriz transposta (resultado)
    );

    oposicao_matriz opposite (
        .matrix_A(matrix_a),                 
        .matrix_size(matrix_size),            
        .m_oposta_A(result_opposite)          // Matriz oposta (resultado)
    );

    multiplicacao_num_matriz multiplierScalar (
        .matriz_A(matrix_a),                  
        .matrix_size(matrix_size),            
        .num_inteiro(scalar),                 
        .nova_matriz_A(result_mult_esc),       // Resultado da multiplicação escalar
		  .overflow_flag(overflow_scalar)
    );

    // Módulo sequencial para multiplicação de matrizes
    multiplicacao matrix_multiplier (                      
        .matrix_a(matrix_a),                  
        .matrix_b(matrix_b),                  
        .result_out(result_matrix_mult),   // Resultado da multiplicação de matrizes
        .overflow_flag(overflow_matrix_mult) // Sinal de overflow na multiplicação de matrizes
    );

    // Módulo para cálculo do determinante da matriz
    ula_determinante determinante_matriz (                         
        .matriz(matrix_a),                    
        .tamanho_matriz(matrix_size),         
        .det(determinant_result),             // Resultado do determinante
		  .overflow(overflow_determinant),
        .done(determinant_done)               // Sinaliza que o determinante foi calculado
    );

	// Lógica de controle para selecionar a operação a ser realizada com base no código de operação (op_code)
	always @(*) begin
		case (op_code)
			3'b000: begin 
				result_final = result_add;            // Resultado da adição de matrizes
				overflow = overflow_add;              
				process_Done = 1;                     
			end
			3'b001: begin 
				result_final = result_sub;            // Resultado da subtração de matrizes
				overflow = overflow_sub;              
				process_Done = 1;                     
			end
			3'b010: begin
				result_final = result_matrix_mult;   // Resultado da multiplicação de matrizes
				overflow = overflow_matrix_mult;     
				process_Done = 1;
			end
			3'b011: begin 
				result_final = result_mult_esc;       // Resultado da multiplicação escalar
				overflow = overflow_scalar;                         
				process_Done = 1;                     
			end
			3'b100: begin 
				result_final = determinant_result;    // Zera os bits superiores no cálculo do determinante
				overflow = overflow_determinant;    
				process_Done <= determinant_done;     
			end
			3'b101: begin
				result_final = result_transpose;      // Resultado da transposição da matriz
				overflow = 0;                         
				process_Done = 1;                     
			end
			3'b110: begin
				result_final = result_opposite;       // Resultado da matriz oposta
				overflow = 0;                         
				process_Done = 1;                     
			end
			default: begin 
				result_final = 0;                       // Caso padrão, limpa o resultado
				overflow = 0;                           // Não há overflow
				process_Done = 0;                       // Processamento não concluído
			end
		endcase
	end

endmodule
