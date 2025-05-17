module oposicao_matriz (
    input clk,
    input reset,
    input signed [199:0] matriz_A , // Matriz A com 25 elementos de 8 bits
    output reg signed [199:0] m_oposta_A  // Matriz oposta A com 25 elementos de 8 bits
);
    integer i;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            m_oposta_A = 200'b0; // Zera toda a matriz uma única vez
        end else begin
            for (i = 0; i < 25; i = i + 1) begin
                m_oposta_A[i*8 +: 8] <= -matriz_A[i*8 +: 8]; // Calcula a matriz oposta diretamente
            end
        end
    end
endmodule