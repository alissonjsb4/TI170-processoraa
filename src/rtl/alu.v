`timescale 1ns / 1ps

//======================================================================================
// Arithmetic Logic Unit (ALU) and Sub-Modules
//
// Author: Alisson Jaime Sales Barros
// Course: Microprocessors - Federal University of Ceará (UFC)
//
// Description:
// This file contains the complete implementation of the 8-bit ALU and all its
// constituent components, such as adders, multipliers, dividers, and comparators.
//
//======================================================================================


//======================================================================================
// Module: full_adder
// Description: Basic 1-bit full adder. Building block for the 8-bit adder.
//======================================================================================
module full_adder (
    input   A, B, Cin,
    output  S, Cout
);
    assign S = A ^ B ^ Cin;
    assign Cout = (A & B) | (B & Cin) | (A & Cin);
endmodule


//======================================================================================
// Module: adder_8bit
// Description: An 8-bit ripple-carry adder constructed from 8 full_adder instances.
//======================================================================================
module adder_8bit (
    input  [7:0] A, B,
    input        Cin,
    output [7:0] Sum,
    output       Cout
);
    wire [7:0] Carry;

    full_adder u0 (A[0], B[0], Cin,     Sum[0], Carry[0]);
    full_adder u1 (A[1], B[1], Carry[0], Sum[1], Carry[1]);
    full_adder u2 (A[2], B[2], Carry[1], Sum[2], Carry[2]);
    full_adder u3 (A[3], B[3], Carry[2], Sum[3], Carry[3]);
    full_adder u4 (A[4], B[4], Carry[3], Sum[4], Carry[4]);
    full_adder u5 (A[5], B[5], Carry[4], Sum[5], Carry[5]);
    full_adder u6 (A[6], B[6], Carry[5], Sum[6], Carry[6]);
    full_adder u7 (A[7], B[7], Carry[6], Sum[7], Cout);
endmodule


//======================================================================================
// Module: divider_8bit
// Description: Behavioral model for an 8-bit combinational divider.
// Note: This is a non-synthesizable model suitable for simulation. A synthesizable
//       divider would typically require a sequential (multi-cycle) implementation.
//======================================================================================
module divider_8bit (
    input  [7:0] Dividend, 
    input  [7:0] Divisor,
    output reg [7:0] Quotient,
    output reg [7:0] Remainder
);
    always @(*) begin
        if (Divisor != 0) begin
            Quotient = Dividend / Divisor;
            Remainder = Dividend % Divisor;
        end else begin
            Quotient = 8'hFF;  // Error indicator for division by zero
            Remainder = 8'hFF; // Error indicator
        end
    end
endmodule


//======================================================================================
// Module: multiplier_8bit
// Description: Behavioral model for an 8-bit combinational multiplier.
//======================================================================================
module multiplier_8bit (
    input  [7:0] A, B,
    output [15:0] Product
);
    // Behavioral multiplication is synthesizable by modern tools
    assign Product = A * B;
endmodule


//======================================================================================
// Module: comparator_8bit
// Description: An 8-bit magnitude comparator.
//======================================================================================
module comparator_8bit (
    input  [7:0] A, B,
    output reg [1:0] comparison_result // 00: A==B, 01: A>B, 10: A<B
);
    always @(*) begin
        if (A > B)
            comparison_result = 2'b01;
        else if (A < B)
            comparison_result = 2'b10;
        else
            comparison_result = 2'b00;
    end
endmodule


//======================================================================================
// Module: ALU (Top-Level)
// Description: The main 8-bit ALU. It selects an operation based on ALU_Sel and
//              computes the result, updating status flags accordingly.
//======================================================================================
module ALU (
    input wire  [7:0]   A, B,
    input wire  [3:0]   ALU_Sel,
    output reg  [7:0]   C,
    output reg  [6:0]   Flags, // 6:Sign, 5:Carry, 4:Zero, 3:Parity, 2:Overflow
    output reg  [1:0]   comparison_result,
    output reg          ALU_Cout
);

    // Internal wires for connecting sub-modules
    wire [7:0] Sum_w, Sub_w, Quotient_w, Remainder_w;
    wire Sum_Cout_w, Sub_Cout_w;
    wire [15:0] Product_w;
    wire [1:0] comp_res_w;

    // Instantiate all ALU sub-modules
    adder_8bit      adder_inst      (.A(A), .B(B), .Cin(1'b0), .Sum(Sum_w), .Cout(Sum_Cout_w));
    adder_8bit      subtractor_inst (.A(A), .B(~B), .Cin(1'b1), .Sum(Sub_w), .Cout(Sub_Cout_w)); // A - B = A + (~B) + 1
    multiplier_8bit multiplier_inst (.A(A), .B(B), .Product(Product_w));
    divider_8bit    divider_inst    (.Dividend(A), .Divisor(B), .Quotient(Quotient_w), .Remainder(Remainder_w));
    comparator_8bit comparator_inst (.A(A), .B(B), .comparison_result(comp_res_w));
    
    // Main ALU logic block
    always @(*) begin
        // Default values for outputs
        Flags = 7'b0;
        comparison_result = 2'b00;
        C = 8'hXX; // Default to unknown
        
        case (ALU_Sel)
            4'h0: begin // ADD
                C = Sum_w;
                Flags[5] = Sum_Cout_w;                           // Carry Flag
                Flags[6] = C[7];                                 // Sign Flag
                Flags[4] = (C == 8'h00);                         // Zero Flag
                Flags[3] = ^C;                                   // Parity Flag
                Flags[2] = (A[7] == B[7]) && (C[7] != A[7]);     // Overflow Flag
            end

            4'h1: begin // SUB
                C = Sub_w;
                Flags[5] = ~Sub_Cout_w;                          // Borrow Flag
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
                Flags[3] = ^C;
                Flags[2] = (A[7] != B[7]) && (C[7] != A[7]);
            end

            4'h2: begin // MUL
                C = Product_w[7:0];
                Flags[4] = (Product_w == 16'h00);
                Flags[2] = |Product_w[15:8]; // Overflow if upper byte is non-zero
            end

            4'h3: begin // DIV
                C = Quotient_w;
                Flags[4] = (C == 8'h00);
            end

            4'h4: begin // MOD
                C = Remainder_w;
            end

            4'h5: begin // COMP
                C = 8'h00; // Result is not stored, only flags are affected
                comparison_result = comp_res_w;
                Flags[4] = (comp_res_w == 2'b00); // Set Zero flag if equal
            end
            
            4'h6: begin // AND
                C = A & B;
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
            end
            
            4'h7: begin // OR
                C = A | B;
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
            end
            
            4'h8: begin // NOT A
                C = ~A;
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
            end
            
            4'hA: begin // XOR
                C = A ^ B;
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
            end
            
            4'hB: begin // NAND
                C = ~(A & B);
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
            end
            
            4'hC: begin // NOR
                C = ~(A | B);
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
            end
            
            4'hD: begin // XNOR
                C = ~(A ^ B);
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
            end

            default: begin
                C = 8'hXX;
                Flags = 7'h7F; // Indicate an error/invalid operation
            end
        endcase
    end
endmodule
