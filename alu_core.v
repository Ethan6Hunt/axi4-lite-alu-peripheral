`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.03.2026 12:22:29
// Design Name: 
// Module Name: alu_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// alu_core.v
// Pure combinational ALU
// op_sel: 2'b00=ADD, 2'b01=SUB, 2'b10=AND, 2'b11=OR

module alu_core (
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [1:0]  op_sel,
    output reg  [31:0] result,
    output wire        overflow   // set on ADD/SUB overflow
);

    wire [32:0] add_ext = {1'b0, operand_a} + {1'b0, operand_b};
    wire [32:0] sub_ext = {1'b0, operand_a} - {1'b0, operand_b};

    always @(*) begin
        case (op_sel)
            2'b00: result = operand_a + operand_b;   // ADD
            2'b01: result = operand_a - operand_b;   // SUB
            2'b10: result = operand_a & operand_b;   // AND
            2'b11: result = operand_a | operand_b;   // OR
            default: result = 32'd0;
        endcase
    end

    assign overflow = (op_sel == 2'b00) ? add_ext[32] :
                      (op_sel == 2'b01) ? sub_ext[32] : 1'b0;

endmodule