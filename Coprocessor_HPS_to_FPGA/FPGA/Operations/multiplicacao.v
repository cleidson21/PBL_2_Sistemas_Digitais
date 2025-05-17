module multiplicacao (
    input [199:0] matrix_a,   
    input [199:0] matrix_b,
    output reg [199:0] result_out,         
    output reg overflow_flag      // Sinal de estouro (overflow) se algum valor exceder o intervalo [-128,127]
);

    integer size, i, j, k;
    reg signed [7:0] a_elem, b_elem;
    reg signed [15:0] temp_sum;
    reg [4:0] index;
    reg overflow_local;

    always @(*) begin
	 
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

endmodule