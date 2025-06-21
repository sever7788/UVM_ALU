`include "uvm_macros.svh"

`include "Arithematic.sv"
`include "Logical.sv"

interface alu_if
  #(parameter N = 4, M = 4);
  logic clk;
  logic rst;
  logic [N-1:0] A, B;
  logic [M-1:0] instruction;
  logic [N-1:0] ALU_out;
  logic [7:0] add_cnt;
  logic [7:0] a_eq_b_cnt;

endinterface

module ALU 
#(parameter N = 4, M = 4)
(
    input clk,
	input rst,
    input [N-1:0] A, B,
    input [M-1:0] instruction,
    output reg [N-1:0] ALU_out,
	output reg [7:0] add_cnt,//counter for operation add_cnt
	output reg [7:0] a_eq_b_cnt//count operations a==b
	
	
);
  import uvm_pkg::*;
    wire [N-1:0] LU, AU;

    // initialize the sub blocks
    Logical Logic(.clk(clk), .A(A), .B(B), .instruction(instruction[M-2:0]), .LU_out(LU));
    Arithematic arith(.clk(clk), .A(A), .B(B), .instruction(instruction[M-2:0]), .AU_out(AU));

  always @(negedge rst, posedge clk) begin
    if(!rst) 
      ALU_out <= '0;
    else
      ALU_out <= (instruction[M-1]==1) ? LU : AU;
  end
		

  always@(negedge rst, posedge clk)
    if(!rst)begin
      add_cnt<=0;
    end
  else if( instruction == 'h0)begin
    add_cnt<=add_cnt+1;
  end

  always@(negedge rst, posedge clk)
    if(!rst)begin
      a_eq_b_cnt<=0;
    end
  else if(  instruction == 'hf)begin
    a_eq_b_cnt<=a_eq_b_cnt+1;
  end

endmodule