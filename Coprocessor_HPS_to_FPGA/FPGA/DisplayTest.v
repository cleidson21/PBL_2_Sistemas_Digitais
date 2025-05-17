module DisplayTest (
    input wire clk_1_segundo,
    input wire test,
    input wire [199:0] matrix_out,
    output reg [6:0] Display0,
    output reg [6:0] Display1,
	 output reg [6:0] Display4,
	 output reg [6:0] Display5
);

    reg signed [7:0] signed_value;
    reg [7:0] abs_value;
	 reg [4:0] index_display = 0;
	 

    always @(posedge clk_1_segundo) begin

        if (test) begin
            signed_value = (matrix_out[(index_display*8) +: 8]);
            abs_value = (signed_value < 0) ? -signed_value : signed_value;

            Display0 <= seg7(abs_value % 10);
            Display1 <= seg7((abs_value / 10) % 10);
				Display4 <= seg7(index_display % 10);
				Display5 <= seg7((index_display / 10) % 10);	

            if (index_display < 25)
                index_display <= index_display + 1;
            else
                index_display <= 0;
        end
    end

    function [6:0] seg7;
        input [3:0] val;
        begin
            case (val)
                4'd0: seg7 = 7'b1000000;
                4'd1: seg7 = 7'b1111001;
                4'd2: seg7 = 7'b0100100;
                4'd3: seg7 = 7'b0110000;
                4'd4: seg7 = 7'b0011001;
                4'd5: seg7 = 7'b0010010;
                4'd6: seg7 = 7'b0000010;
                4'd7: seg7 = 7'b1111000;
                4'd8: seg7 = 7'b0000000;
                4'd9: seg7 = 7'b0010000;
                default: seg7 = 7'b1111111;
            endcase
        end
    endfunction

endmodule
