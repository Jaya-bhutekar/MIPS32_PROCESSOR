`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   10:14:48 08/27/2025
// Design Name:   pipe_MIPS32
// Module Name:   E:/Xilinx/vlsi examples/full_alu/test_CPU.v
// Project Name:  full_alu
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: pipe_MIPS32
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module test_mips32;

	// Inputs
	reg clk1;
	reg clk2;
	
	integer k;

	// Instantiate the Unit Under Test (UUT)
	pipe_MIPS32 uut (
		.clk1(clk1), 
		.clk2(clk2)
	);

	initial begin
		
		clk1 = 0;
		clk2 = 0;
		
		repeat(60)
		begin
				#5 clk1=1; #5 clk1=0;  // Generating clocks
				#5 clk2=1; #5 clk2=0;
		end

	end
	
	initial 
			begin
				for(k=0;k<31;k=k+1)
						uut.RegFile[k] = k;
						
				uut.Mem[0]  =   32'h2801000a;  // ADDI R1, R0,10
				uut.Mem[1]  =   32'h28020014;  // ADDI R2, R0,20
				uut.Mem[2]  =   32'h28030019;  // ADDI R3, R0,25
				uut.Mem[3]  =   32'h0ce77800;  // OR   R7, R7,R7
				uut.Mem[4]  =   32'h0ce77800;  // OR   R7, R7,R7
				uut.Mem[5]  =   32'h00222000;  // ADD  R4, R1,R2
				uut.Mem[6]  =   32'h0ce77800;  // OR   R7, R7,R7
				uut.Mem[7]  =   32'h00832800;  // ADD  R5, R4,R3
				uut.Mem[8]  =   32'hfc000000;  // HLT
				
				
				uut.HALTED       = 0;
				uut.PC           = 0;
				uut.TAKEN_BRANCH = 0;
				
				#280
				
				for(k=0;k<6;k=k+1)
						$display("R%1d - %2d ",k,uut.RegFile[k]);
        end
		  
		 
		  initial  #300 $finish;
		  
		  
endmodule

