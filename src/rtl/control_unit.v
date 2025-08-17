`timescale 1ns / 1ps

//======================================================================================
// Module: control_unit
//
// Author: Alisson Jaime Sales Barros
// Course: Microprocessors - Federal University of Ceará (UFC)
//
// Description:
// This module implements the Control Unit of the 8-bit CPU using a Finite State
// Machine (FSM). It decodes instructions from the Instruction Register (IR) and
// generates the appropriate control signals to orchestrate the datapath through
// the fetch-decode-execute cycle.
//
//======================================================================================
module control_unit (
    input               clock,
    input               reset,          // Active-low reset
    input               execute,        // Global execution enable
    input       [7:0]   IR,             // Instruction Register input
    input       [7:0]   CCR_Result,     // Condition Code Register input
    output reg          IR_Load,
    output reg          MAR_Load,
    output reg          PC_Load,
    output reg          PR_Load,
    output reg          PC_Inc, PR_Inc,
    output reg          Memory_Load,
    output reg          A_Load,
    output reg          B_Load,
    output reg          C_Load,
    output reg  [3:0]   ALU_Sel,
    output reg          CCR_Load,
    output reg  [2:0]   Bus1_Sel,
    output reg  [1:0]   Bus2_Sel,
    output reg          write,
    output reg          file_finished
);

    // State registers
    reg [7:0] current_state, next_state;

    // FSM State Definitions
    parameter S_FETCH_0     = 0, S_FETCH_1     = 1, S_FETCH_2     = 2; // Instruction Fetch Cycle
    parameter S_DECODE      = 3;                                     // Instruction Decode
    
    parameter S_LDA_DIR_4   = 7, S_LDA_DIR_5   = 8, S_LDA_DIR_6   = 9; // Load Operand A from memory
    parameter S_LDB_IMM_4   = 14;                                    // Load Operand B with immediate value
    parameter S_LDB_DIR_4   = 17, S_LDB_DIR_5  = 18, S_LDB_DIR_6  = 19;// Load Operand B from memory
    
    parameter S_ALU_EXEC    = 25; // Execute ALU operation
    parameter S_JMP_EXEC    = 26; // Execute Jump operation
    
    parameter S_HALT        = 100; // Halt state

    // State Register Logic (Sequential)
    always @ (posedge clock or negedge reset) begin
        if (!reset)
            current_state <= S_FETCH_0;
        else if(execute)
            current_state <= next_state;
    end

    // Next State Logic (Combinational)
    always @ (*) begin
        case (current_state)
            // Instruction Fetch Cycle
            S_FETCH_0: next_state = S_FETCH_1;
            S_FETCH_1: next_state = S_FETCH_2;
            S_FETCH_2: next_state = S_DECODE;

            // Decode and branch to operand fetch
            S_DECODE: begin
                if(IR == 8'h00)      next_state = S_HALT;        // HALT instruction
                else if (IR == 8'h04)next_state = S_LDB_DIR_4;    // JMP needs one operand
                else                 next_state = S_LDA_DIR_4;    // Other ops need at least one operand
            end

            // Operand A Fetch Cycle
            S_LDA_DIR_4: next_state = S_LDA_DIR_5;
            S_LDA_DIR_5: next_state = S_LDA_DIR_6;
            S_LDA_DIR_6: begin // After fetching A, decide if B is needed
                if(IR == 8'h03)                     next_state = S_ALU_EXEC;   // NOT A (1 operand)
                else if(IR == 8'h01 || IR == 8'h02) next_state = S_LDB_IMM_4;  // INC/DEC A (uses immediate 1)
                else                                next_state = S_LDB_DIR_4;  // Needs second operand from memory
            end

            // Operand B Fetch (Immediate)
            S_LDB_IMM_4: next_state = S_ALU_EXEC;
            
            // Operand B Fetch (Direct from memory)
            S_LDB_DIR_4: next_state = S_LDB_DIR_5;
            S_LDB_DIR_5: next_state = S_LDB_DIR_6;
            S_LDB_DIR_6: begin // After fetching B, decide what to execute
                if(IR == 8'h04) next_state = S_JMP_EXEC;
                else            next_state = S_ALU_EXEC;
            end

            // After execution, return to fetch next instruction
            S_ALU_EXEC: next_state = S_FETCH_0;
            S_JMP_EXEC: next_state = S_FETCH_0;

            default: next_state = S_FETCH_0;
        endcase
    end

    // Output Logic (Combinational)
    always @ (*) begin
        // Default values for all control signals
        IR_Load = 0; MAR_Load = 0; PC_Load = 0; PC_Inc = 0; PR_Inc = 0;
        Memory_Load = 0; A_Load = 0; B_Load = 0; C_Load = 0; CCR_Load = 0;
        Bus1_Sel = 3'b000; Bus2_Sel = 2'b00; write = 0; file_finished = 0;
        ALU_Sel = 4'hF; // Default to an invalid operation

        case (current_state)
            S_FETCH_0:      MAR_Load = 1;
            S_FETCH_1:      PC_Inc = 1;
            S_FETCH_2:      begin Bus2_Sel = 2'b10; IR_Load = 1; end
            S_DECODE:       begin /* Combinational logic only */ end
            S_LDA_DIR_4:    MAR_Load = 1;
            S_LDA_DIR_5:    PC_Inc = 1;
            S_LDA_DIR_6:    begin Bus2_Sel = 2'b10; A_Load = 1; end
            S_LDB_DIR_4:    MAR_Load = 1;
            S_LDB_DIR_5:    PC_Inc = 1;
            S_LDB_DIR_6:    begin Bus2_Sel = 2'b10; B_Load = 1; end
            S_LDB_IMM_4:    begin Bus2_Sel = 2'b01; B_Load = 1; end
            S_JMP_EXEC:     begin Bus1_Sel = 3'b010; Bus2_Sel = 2'b00; PC_Load = 1; end
            S_HALT:         file_finished = 1;

            S_ALU_EXEC: begin
                case(IR)
                    8'h01: ALU_Sel = 4'h0;  // ADD (for increment)
                    8'h02: ALU_Sel = 4'h1;  // SUB (for decrement)
                    8'h03: ALU_Sel = 4'h8;  // NOT
                    8'h10: ALU_Sel = 4'h0;  // ADD
                    8'h20: ALU_Sel = 4'h1;  // SUB
                    8'h30: ALU_Sel = 4'h2;  // MUL
                    8'h40: ALU_Sel = 4'h3;  // DIV
                    8'h50: ALU_Sel = 4'h4;  // MOD
                    8'h60: ALU_Sel = 4'h6;  // AND
                    8'h70: ALU_Sel = 4'h7;  // OR
                    8'h80: ALU_Sel = 4'hA;  // XOR
                    8'h90: ALU_Sel = 4'hB;  // NAND
                    8'hA0: ALU_Sel = 4'hC;  // NOR
                    8'hB0: ALU_Sel = 4'hD;  // XNOR
                    8'hC0: ALU_Sel = 4'h5;  // COMP
                endcase
            end
        endcase
    end
endmodule
