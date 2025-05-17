module multiplicacao_num_matriz(
    input clk,
    input rst,
    input signed [199:0] matriz_A,
    input signed [7:0] num_inteiro,
    output reg signed [199:0] nova_matriz_A 
);

    reg signed [7:0] matriz_original [24:0];
    reg signed [7:0] matriz_multiplicada [24:0];

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reseta todos os valores
            for (i = 0; i < 25; i = i + 1) begin
                matriz_original[i] = 8'sd0;
                matriz_multiplicada[i] = 8'sd0;
            end

            nova_matriz_A = 200'sd0;
        end
        else begin
        
            // Matriz de Entrada
            for(i = 0; i < 25; i = i + 1) begin
                matriz_original[i] = matriz_A[(i*8) +: 8];
            end

            // Multiplica pelo número inteiro
            for (i = 0; i < 25; i = i + 1) begin
                matriz_multiplicada[i] = num_inteiro*matriz_original[i];
            end

            // Transfere os números para a matriz de saída
            for (i = 0; i < 25; i = i + 1) begin
                nova_matriz_A[(i*8) +: 8] = matriz_multiplicada[i];
            end
        end
    end

endmodule