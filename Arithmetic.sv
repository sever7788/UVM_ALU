module Arithematic 
#(parameter N = 4, M = 4)
(
    input wire clk,
    input wire [N-1:0] A, B,
    input wire [M-2:0] instruction,
    output reg [N-1:0] AU_out
);
    
  always @ (*) begin
        
        case (instruction)
            3'h0: AU_out = A + B;
            3'h1: AU_out = A - B;
            3'h2: AU_out = A * B;//the multiplying needs more bits to store the result
            3'h3: AU_out = A / B;//we cant simplify the division operator in verilog
            3'h4: AU_out = A << 1;
            3'h5: AU_out = A >> 1;
            3'h6: AU_out = {A[N-2:0], A[N-1]};
            3'h7: AU_out = {A[0], A[N-1:1]};
            default: AU_out = A;
        endcase
    end

endmodule
