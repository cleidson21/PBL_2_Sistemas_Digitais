module multiplicacao (
    input [199:0] raw_matrix_a,   
    input [199:0] raw_matrix_b,
	 input [1:0] matrix_size, // 00: 2x2, 01: 3x3, 10: 4x4, 11: 5x5
    output reg [199:0] result_out,         
    output reg overflow_flag      // Sinal de estouro (overflow) se algum valor exceder o intervalo [-128,127]
);

    integer size, i, j, k;
    reg signed [7:0] a_elem, b_elem;
    reg signed [15:0] temp_sum;
    reg [4:0] index;
    reg overflow_local;
	 reg [199:0] matrix_a, matrix_b;

    always @(*) begin
	 
		  // Aplica o masker às matrizes de entrada
        matrix_a = mask_matrix(matrix_size, raw_matrix_a);
        matrix_b = mask_matrix(matrix_size, raw_matrix_b);
	 
        result_out = 0;
        overflow_local = 0;

        for (i = 0; i < 5; i = i + 1) begin
            for (j = 0; j < 5; j = j + 1) begin
                temp_sum = 0;
                for (k = 0; k < 5; k = k + 1) begin
                    a_elem = matrix_a[(i*40) + (k*8) +: 8];
                    b_elem = matrix_b[(k*40) + (j*8) +: 8];
                    temp_sum = temp_sum + bit_mult(a_elem, b_elem);
                end
                index = i*5 + j;
                result_out[(index*8) +: 8] = temp_sum[7:0];
                if (temp_sum > 127 || temp_sum < -128)
                    overflow_local = 1;
            end
        end

        overflow_flag = overflow_local;
    end

    // Função auxiliar para multiplicação bit a bit
    function signed [15:0] bit_mult;
        input signed [7:0] a, b;
        begin
            bit_mult = 0;
            if (b[0]) bit_mult = bit_mult + a;
            if (b[1]) bit_mult = bit_mult + (a << 1);
            if (b[2]) bit_mult = bit_mult + (a << 2);
            if (b[3]) bit_mult = bit_mult + (a << 3);
            if (b[4]) bit_mult = bit_mult + (a << 4);
            if (b[5]) bit_mult = bit_mult + (a << 5);
            if (b[6]) bit_mult = bit_mult + (a << 6);
            if (b[7]) bit_mult = bit_mult - (a << 7); // Ajuste para complemento de dois
        end
    endfunction
	 
	 // Função masker integrada
    function [199:0] mask_matrix;
        input [1:0] size;
        input [199:0] matrix_in;
        integer row, col, in_index, out_index;
        begin
            mask_matrix = {200{1'b0}}; // Inicializa com zeros
            
            case(size)
                2'b00: begin // 2x2
                    for(row = 0; row < 2; row = row + 1) begin
                        for(col = 0; col < 2; col = col + 1) begin
                            in_index = row * 2 + col;
                            out_index = row * 5 + col;
                            mask_matrix[out_index*8 +: 8] = matrix_in[in_index*8 +: 8];
                        end
                    end
                end
                
                2'b01: begin // 3x3
                    for(row = 0; row < 3; row = row + 1) begin
                        for(col = 0; col < 3; col = col + 1) begin
                            in_index = row * 3 + col;
                            out_index = row * 5 + col;
                            mask_matrix[out_index*8 +: 8] = matrix_in[in_index*8 +: 8];
                        end
                    end
                end
                
                2'b10: begin // 4x4
                    for(row = 0; row < 4; row = row + 1) begin
                        for(col = 0; col < 4; col = col + 1) begin
                            in_index = row * 4 + col;
                            out_index = row * 5 + col;
                            mask_matrix[out_index*8 +: 8] = matrix_in[in_index*8 +: 8];
                        end
                    end
                end
                
                default: begin // 5x5 (inclui 2'b11 e default)
                    mask_matrix = matrix_in;
                end
            endcase
        end
    endfunction

endmodule