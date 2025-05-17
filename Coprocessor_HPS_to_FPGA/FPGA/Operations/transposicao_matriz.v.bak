module transposicao_matriz(
    input clk,
    input reset, 
    input signed [199:0] matriz_A,
    output reg signed [199:0] m_transposta_A
);

    // Registradores para manipulação da matriz
    reg signed [7:0] matriz_original [0:24];  // Matriz original 5x5 (25 elementos)
    reg signed [7:0] matriz_transposta [0:24];  // Matriz transposta 5x5 (25 elementos)

    // Variável para loops
    integer i, j;

    // Processo de transposição
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset todos os valores
            for (i = 0; i < 25; i = i + 1) begin
                matriz_original[i] = 8'sd0;  // Usando sd para signed decimal
                matriz_transposta[i] = 8'sd0;
            end
            
            m_transposta_A = 200'sd0;
        end
        else begin
            // Desempacota a matriz de entrada
            for (i = 0; i < 25; i = i + 1) begin
                matriz_original[i] = matriz_A[(i*8)+:8];
            end
            
            // Realiza a transposição
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    matriz_transposta[j*5 + i] = matriz_original[i*5 + j];
                end
            end
            
            // Empacota a matriz transposta de volta
            for (i = 0; i < 25; i = i + 1) begin
                m_transposta_A[(i*8)+:8] = matriz_transposta[i];
            end
        end
    end

endmodule