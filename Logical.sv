module Logical 
#(parameter N = 4, M = 4)
(
    input wire clk,
    input wire [N-1:0] A, B,
    input wire [M-2:0] instruction,
    output reg [N-1:0] LU_out
);
  always @(*) begin

        case (instruction)
            3'h0: LU_out = A & B; 
            3'h1: LU_out = A | B; 
            3'h2: LU_out = A ^ B; 
            3'h3: LU_out = ~(A | B); 
            3'h4: LU_out = ~(A & B); 
            3'h5: LU_out = ~(A ^ B); 
            3'h6: LU_out = (A>B) ? 4'h1: 4'h0;
            3'h7: LU_out = (A==B) ? 4'h1: 4'h0; 
            default: LU_out = A;
        endcase

    end
endmodule