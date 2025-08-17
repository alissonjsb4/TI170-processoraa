`timescale 1ns / 1ps

//======================================================================================
// Module: Datapath
//
// Author: Alisson Jaime Sales Barros
// Course: Microprocessors - Federal University of Ceará (UFC)
//
// Description:
// This module implements the datapath of the 8-bit CPU. It contains all the
// registers (PC, IR, MAR, A, B, C, etc.), multiplexers, and internal buses
// required for data storage, transfer, and processing. The operation is
// orchestrated by control signals from the Control Unit.
//
//======================================================================================
module datapath (
    input wire          clock,
    input wire          reset,          // Active-low reset
    // Control Signals from Control Unit
    input wire  [2:0]   Bus1_Sel,
    input wire  [1:0]   Bus2_Sel,
    input wire          PC_Load, PC_Inc, PR_Inc,
    input wire          A_Load, B_Load, C_Load,
    input wire          IR_Load, MAR_Load, CCR_Load, Memory_Load,
    // Data Inputs
    input wire  [7:0]   ALU_Result,
    input wire  [7:0]   from_memory,
    input wire  [6:0]   NZVC,           // Flags from ALU
    // Data Outputs
    output reg  [7:0]   to_memory,
    output reg  [7:0]   address,
    // Register Outputs (for Control Unit, etc.)
    output reg  [7:0]   IR, A, B, C, PC, MAR, PR, CCR_Result
);

    // Internal buses for data transfer
    reg [7:0] Bus1, Bus2;

    // Bus1 Multiplexer: Selects the source for Bus1 from various registers.
    always @(*) begin
        case (Bus1_Sel)
            3'b000: Bus1 = PC;
            3'b001: Bus1 = A;
            3'b010: Bus1 = B;
            3'b011: Bus1 = C;
            3'b100: Bus1 = PR;
            3'b101: Bus1 = IR;
            default: Bus1 = 8'hXX;
        endcase
    end

    // Bus2 Multiplexer: Selects the source for Bus2, which is the main data input for registers.
    always @(*) begin
        case (Bus2_Sel)
            2'b00: Bus2 = Bus1;         // Pass-through from Bus1
            2'b01: Bus2 = 8'h01;        // Immediate value 1 (for INC/DEC)
            2'b10: Bus2 = from_memory;  // Data from memory
            2'b11: Bus2 = ALU_Result;   // Result from ALU
            default: Bus2 = 8'hXX;
        endcase
    end

    // Memory Interface Logic (combinational)
    // Drives the address and data lines for memory operations.
    always @(*) begin
        if (Memory_Load) begin
            to_memory = Bus1;
            address = MAR;
        end else begin
            to_memory = 8'hZZ; // High-impedance when not writing
            address = MAR;     // Address can be driven by MAR
        end
    end

    // --- Registers (Sequential Logic) ---

    // Instruction Register (IR)
    always @(posedge clock or negedge reset) begin
        if (!reset)
            IR <= 8'h00;
        else if (IR_Load)
            IR <= Bus2;
    end

    // Memory Address Register (MAR)
    always @(posedge clock or negedge reset) begin
        if (!reset)
            MAR <= 8'h00;
        else if (MAR_Load)
            MAR <= Bus2;
    end

    // Program Counter (PC)
    always @(posedge clock or negedge reset) begin
        if (!reset)
            PC <= 8'h00;
        else if (PC_Load)
            PC <= PC + Bus2; // For jump instructions
        else if (PC_Inc)
            PC <= PC + 1;    // For sequential execution
    end

    // Program Response Counter (PR) - Auxiliary register
    always @(posedge clock or negedge reset) begin
        if (!reset)
            PR <= 8'h00;
        else if (PR_Inc)
            PR <= PR + 1;
    end
    
    // General Purpose Register A
    always @(posedge clock or negedge reset) begin
        if (!reset)
            A <= 8'h00;
        else if (A_Load)
            A <= Bus2;
    end

    // General Purpose Register B
    always @(posedge clock or negedge reset) begin
        if (!reset)
            B <= 8'h00;
        else if (B_Load)
            B <= Bus2;
    end

    // General Purpose Register C (typically for ALU output)
    always @(posedge clock or negedge reset) begin
        if(!reset)
            C <= 8'h00;
        else if (C_Load)
            C <= Bus2;
    end

    // Condition Code Register (CCR) - Stores ALU flags
    always @(posedge clock or negedge reset) begin
        if (!reset)
            CCR_Result <= 8'h00;
        else if (CCR_Load)
            CCR_Result <= NZVC;
    end

endmodule
