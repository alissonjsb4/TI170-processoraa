`timescale 1ns / 1ps

//======================================================================================
// 8-bit CPU Design - Debug Version
//
// Author: Alisson Jaime Sales Barros
// Course: Microprocessors - Federal University of Ceará (UFC)
//
// Description:
// This file contains the complete Verilog code for an 8-bit processor,
// including extensive debug messages (`$display`) for simulation and verification.
// It is composed of four main modules:
// 1. data_memory: A 128-byte synchronous RAM.
// 2. datapath: Contains registers, buses, and routes data.
// 3. control_unit: A Finite State Machine (FSM) that orchestrates the CPU.
// 4. ALU: Performs arithmetic and logical operations.
//
//======================================================================================


//======================================================================================
// Module 1: Data Memory
// Description: Implements a 128-byte synchronous RAM for data storage.
//              It is initialized with a binary file ("file.bin").
//======================================================================================
module data_memory(
    input               clock,      // System clock
    input               reset,      // System reset
    input       [7:0]   address,    // Memory address
    input       [7:0]   data_in,    // Data to be written
    input               write,      // Write enable signal
    output reg  [7:0]   data_out    // Data read from memory
);

    // 128x8-bit memory array
    reg [7:0] RW[0:127];

    // Initialize memory content from file at the start of simulation
    initial begin
        $readmemb("file.bin", RW);
    end
  
    // Internal enable logic based on valid address range
    reg EN;
    always @ (address) begin
        if (address <= 127) 
            EN = 1'b1;
        else 
            EN = 1'b0;
    end

    // Synchronous read/write logic
    always @ (posedge clock) begin
        if (write && EN) begin
            RW[address] <= data_in;
        end else if (!write && EN) begin
            data_out <= RW[address];
        end
    end

endmodule


//======================================================================================
// Module 2: Datapath
// Description: Contains all the registers (PC, IR, MAR, etc.), multiplexers,
//              and buses that form the data-flow part of the CPU.
//======================================================================================
module datapath (
    input wire          reset, 
    input wire          execute,
    input wire  [2:0]   Bus1_Sel,
    input wire  [1:0]   Bus2_Sel,
    input wire          PC_Load, PC_Inc, PR_Inc, A_Load, B_Load, C_Load, IR_Load, MAR_Load, CCR_Load, Memory_Load,
    input wire  [6:0]   NZVC,
    input wire  [7:0]   ALU_Result, 
    input wire  [7:0]   from_memory,
    output reg  [7:0]   to_memory, 
    output reg  [7:0]   address,
    output reg  [7:0]   IR, A, B, C, PC, MAR, PR, CCR_Result
);

    // Internal buses
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

    // Bus2 Multiplexer: Selects the source for Bus2.
    always @(*) begin
        case (Bus2_Sel)
            2'b00: Bus2 = Bus1;         // Pass-through from Bus1
            2'b01: Bus2 = 8'h01;        // Immediate value 1 (for INC/DEC)
            2'b10: Bus2 = from_memory;  // Data from memory
            2'b11: Bus2 = ALU_Result;   // Result from ALU
            default: Bus2 = 8'hXX;
        endcase
    end

    // Memory write connection
    always @(*) begin
        if(execute && Memory_Load) begin
            to_memory = Bus1;
            address = MAR;
        end
    end

    // Instruction Register (IR)
    always @(posedge IR_Load or negedge reset) begin
        if (!reset)
            IR <= 8'h00;
        else if (IR_Load) begin
            IR <= Bus2;
            $display("[DATAPATH] IR loaded with instruction: %h from Bus2", Bus2);
            if(Bus2 != 8'h04) 
                $display("[DATAPATH] --- Operation Result ---");
            else 
                $display("[DATAPATH] --- Jump Instruction ---");
        end
    end

    // Memory Address Register (MAR)
    always @(posedge MAR_Load or negedge reset) begin
        if (!reset)
            MAR <= 8'h00;
        else if (execute && MAR_Load)
            MAR <= Bus2;
    end

    // Program Counter (PC)
    always @(posedge PC_Inc or negedge reset) begin
        if (!reset)
            PC <= 8'h00;
        else if (execute && PC_Load)
            PC <= PC + Bus2; // Used for jumps
        else if (execute && PC_Inc)
            PC <= PC + 1;    // Default increment
    end

    // Program Response Counter (PR) - Example of an auxiliary register
    always @(posedge PR_Inc or negedge reset) begin
        if (!reset)
            PR <= 8'h00;
        else if (execute && PR_Inc)
            PR <= PR + 1;
    end
    
    // General Purpose Registers A, B, C
    always @(posedge A_Load or negedge reset) begin
        if (!reset)
            A <= 8'h00;
        else if (execute && A_Load) begin
            A <= Bus2;
            $display("[DATAPATH] Register A loaded with value: %h", Bus2);
        end
    end

    always @(posedge B_Load or negedge reset) begin
        if (!reset)
            B <= 8'h00;
        else if (execute && B_Load) begin
            B <= Bus2;
            $display("[DATAPATH] Register B loaded with value: %h", Bus2);
            if(IR == 8'h04) $display("[DATAPATH] Jump offset is: %d lines", Bus2);
        end
    end

    always @(posedge C_Load or negedge reset) begin
        if(!reset)
            C <= 8'h00;
        else if (execute && C_Load) begin
            C <= Bus2;
            $display("[DATAPATH] Register C loaded with ALU result: %h", Bus2);
        end
    end

    // Condition Code Register (CCR)
    always @(posedge CCR_Load or negedge reset) begin
        if (!reset)
            CCR_Result <= 8'h00;
        else if (execute && CCR_Load)
            CCR_Result <= NZVC;
    end

endmodule


//======================================================================================
// Module 3: Control Unit
// Description: A Finite State Machine (FSM) that generates control signals
//              to orchestrate the datapath based on the current instruction (IR).
//======================================================================================
module control_unit (
    input               clock,
    input               reset,
    input               execute,
    input       [7:0]   IR,
    input       [7:0]   CCR_Result,
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

    parameter S_STORE_IR_8  = 32, S_STORE_IR_9  = 33; // Store IR to memory (example)
    parameter S_STORE_C_10  = 42, S_STORE_C_11  = 43, S_STORE_C_12 = 44; // Store C to memory (example)
    
    parameter S_HALT        = 100; // Halt state

    // State Register Logic
    always @ (posedge clock or negedge reset) begin
        if (!reset)
            current_state <= S_FETCH_0;
        else if(execute)
            current_state <= next_state;
    end

    // Next State Logic (Combinational)
    always @ (current_state, IR) begin
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
            S_JMP_EXEC: next_state = S_FETCH_0; // Jumps also return to fetch

            default: next_state = S_FETCH_0;
        endcase
    end

    // Output Logic (Combinational)
    always @ (current_state) begin
        // Default values for all control signals
        IR_Load = 0; MAR_Load = 0; PC_Load = 0; PC_Inc = 0; PR_Inc = 0;
        Memory_Load = 0; A_Load = 0; B_Load = 0; C_Load = 0; CCR_Load = 0;
        Bus1_Sel = 3'b000; Bus2_Sel = 2'b00; write = 0; file_finished = 0;
        ALU_Sel = 4'hF; // Default to an invalid operation

        case (current_state)
            S_FETCH_0: begin
                MAR_Load = 1;
                $display("[CU] State: S_FETCH_0 | Action: MAR_Load");
            end
            S_FETCH_1: begin
                PC_Inc = 1;
                $display("[CU] State: S_FETCH_1 | Action: PC_Inc");
            end
            S_FETCH_2: begin
                Bus2_Sel = 2'b10; // from_memory
                IR_Load = 1;
                $display("[CU] State: S_FETCH_2 | Action: IR_Load from Memory");
            end
    
            S_DECODE: begin
                $display("[CU] State: S_DECODE  | Evaluating IR = %h", IR);
            end
        
            S_LDA_DIR_4: begin
                MAR_Load = 1;
                $display("[CU] State: S_LDA_DIR_4 | Action: MAR_Load (Operand A Addr)");
            end
            S_LDA_DIR_5: begin
                PC_Inc = 1;
                $display("[CU] State: S_LDA_DIR_5 | Action: PC_Inc");
            end
            S_LDA_DIR_6: begin
                Bus2_Sel = 2'b10; // from_memory
                A_Load = 1;
                $display("[CU] State: S_LDA_DIR_6 | Action: A_Load from Memory");
            end
            
            S_LDB_DIR_4: begin
                MAR_Load = 1;
                $display("[CU] State: S_LDB_DIR_4 | Action: MAR_Load (Operand B Addr)");
            end
            S_LDB_DIR_5: begin
                PC_Inc = 1;
                $display("[CU] State: S_LDB_DIR_5 | Action: PC_Inc");
            end
            S_LDB_DIR_6: begin
                Bus2_Sel = 2'b10; // from_memory
                B_Load = 1;
                $display("[CU] State: S_LDB_DIR_6 | Action: B_Load from Memory");
            end

            S_LDB_IMM_4: begin
                Bus2_Sel = 2'b01; // immediate 1
                B_Load = 1;
                $display("[CU] State: S_LDB_IMM_4 | Action: B_Load with Immediate Value 1");
            end

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
                $display("[CU] State: S_ALU_EXEC  | Action: ALU Operation Selected (ALU_Sel = %h)", ALU_Sel);
            end

            S_JMP_EXEC: begin
                Bus1_Sel = 3'b010; // Select Reg B (contains jump offset)
                Bus2_Sel = 2'b00;  // Pass through Bus1
                PC_Load = 1;
                $display("[CU] State: S_JMP_EXEC  | Action: PC_Load (Jumping)");
            end

            S_HALT: begin
                file_finished = 1;
                $display("[CU] State: S_HALT      | Action: Halting Execution.");
            end
        
            default: begin
                $display("[CU] State: DEFAULT   | Warning: Reached undefined state. Resetting FSM.");
            end
        endcase
    end
endmodule


//======================================================================================
// Module 4: Arithmetic Logic Unit (ALU) and its sub-modules
// Description: Performs all arithmetic and logical operations.
//======================================================================================

// Basic building block: 1-bit full adder
module full_adder (A, B, Cin, S, Cout);
    input A, B, Cin;
    output S, Cout;
    assign S = A ^ B ^ Cin;
    assign Cout = (A & B) | (B & Cin) | (A & Cin);
endmodule

// 8-bit ripple-carry adder
module adder_8bit (A, B, Cin, Sum, Cout);
    input  [7:0] A, B;
    input        Cin;
    output [7:0] Sum;
    output       Cout;

    wire [7:0] Carry;

    full_adder U0 (A[0], B[0], Cin,     Sum[0], Carry[0]);
    full_adder U1 (A[1], B[1], Carry[0], Sum[1], Carry[1]);
    full_adder U2 (A[2], B[2], Carry[1], Sum[2], Carry[2]);
    full_adder U3 (A[3], B[3], Carry[2], Sum[3], Carry[3]);
    full_adder U4 (A[4], B[4], Carry[3], Sum[4], Carry[4]);
    full_adder U5 (A[5], B[5], Carry[4], Sum[5], Carry[5]);
    full_adder U6 (A[6], B[6], Carry[5], Sum[6], Carry[6]);
    full_adder U7 (A[7], B[7], Carry[6], Sum[7], Cout);
endmodule

// 8-bit divider (combinational)
module divider_8bit (
    input  [7:0] Dividend, Divisor,
    output reg [7:0] Quotient,
    output reg [7:0] Remainder
);
    // Note: This is a behavioral, non-synthesizable model for division.
    // A synthesizable divider would require a sequential circuit (state machine).
    always @(*) begin
        if (Divisor != 0) begin
            Quotient = Dividend / Divisor;
            Remainder = Dividend % Divisor;
        end else begin
            Quotient = 8'hFF;  // Error indicator
            Remainder = 8'hFF; // Error indicator
        end
    end
endmodule

// 8-bit multiplier (combinational)
module multiplier_8bit (
    input  [7:0] A, B,
    output [15:0] Product
);
    // Behavioral model for multiplication
    assign Product = A * B;
endmodule

// 8-bit comparator
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

// Main ALU Module
module ALU (
    input wire  [7:0]   A, B,
    input wire  [3:0]   ALU_Sel,
    output reg  [7:0]   C,
    output reg  [6:0]   Flags, // 6:Sign, 5:Carry, 4:Zero, 3:Parity, 2:Overflow
    output reg  [1:0]   comparison_result,
    output reg          ALU_Cout
);

    wire [7:0] Sum_w, Sub_w, Quotient_w, Remainder_w;
    wire Sum_Cout_w, Sub_Cout_w;
    wire [15:0] Product_w;
    wire [1:0] comp_res_w;

    // Instantiate ALU sub-modules
    adder_8bit      adder_inst      (.A(A), .B(B), .Cin(1'b0), .Sum(Sum_w), .Cout(Sum_Cout_w));
    adder_8bit      subtractor_inst (.A(A), .B(~B), .Cin(1'b1), .Sum(Sub_w), .Cout(Sub_Cout_w)); // A - B = A + (~B) + 1
    multiplier_8bit multiplier_inst (.A(A), .B(B), .Product(Product_w));
    divider_8bit    divider_inst    (.Dividend(A), .Divisor(B), .Quotient(Quotient_w), .Remainder(Remainder_w));
    comparator_8bit comparator_inst (.A(A), .B(B), .comparison_result(comp_res_w));
    
    always @(*) begin
        // Default flag values
        Flags = 7'b0;
        comparison_result = 2'b00;
        
        case (ALU_Sel)
            4'h0: begin // ADD
                C = Sum_w;
                Flags[5] = Sum_Cout_w;                           // Carry Flag
                Flags[6] = C[7];                                 // Sign Flag
                Flags[4] = (C == 8'h00);                         // Zero Flag
                Flags[3] = ^C;                                   // Parity Flag
                Flags[2] = (A[7] == B[7]) && (C[7] != A[7]);     // Overflow Flag
                $display("[ALU] ADD operation. A=%h, B=%h. Result C=%h", A, B, C);
            end

            4'h1: begin // SUB
                C = Sub_w;
                Flags[5] = ~Sub_Cout_w;                          // Borrow Flag
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
                Flags[3] = ^C;
                Flags[2] = (A[7] != B[7]) && (C[7] != A[7]);
                $display("[ALU] SUB operation. A=%h, B=%h. Result C=%h", A, B, C);
            end

            4'h2: begin // MUL
                C = Product_w[7:0];
                Flags[4] = (Product_w == 16'h00);
                Flags[2] = |Product_w[15:8]; // Overflow if upper byte is non-zero
                $display("[ALU] MUL operation. A=%h, B=%h. Result C=%h", A, B, C);
            end

            4'h3: begin // DIV
                C = Quotient_w;
                Flags[4] = (C == 8'h00);
                if (B == 0) $display("[ALU] ERROR: Division by zero!");
                else $display("[ALU] DIV operation. A=%h, B=%h. Quotient C=%h", A, B, C);
            end

            4'h4: begin // MOD
                C = Remainder_w;
                if (B == 0) $display("[ALU] ERROR: Modulo by zero!");
                else $display("[ALU] MOD operation. A=%h, B=%h. Remainder C=%h", A, B, C);
            end

            4'h5: begin // COMP
                C = 8'h00;
                comparison_result = comp_res_w;
                Flags[4] = (comp_res_w == 2'b00); // Set Zero flag if equal
                $display("[ALU] COMP operation. A=%h, B=%h. Result code: %b", A, B, comp_res_w);
            end
            
            4'h6: begin // AND
                C = A & B;
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
                $display("[ALU] AND operation. A=%h, B=%h. Result C=%h", A, B, C);
            end
            
            4'h7: begin // OR
                C = A | B;
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
                $display("[ALU] OR operation. A=%h, B=%h. Result C=%h", A, B, C);
            end
            
            4'h8: begin // NOT A
                C = ~A;
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
                 $display("[ALU] NOT operation. A=%h. Result C=%h", A, C);
            end
            
            4'hA: begin // XOR
                C = A ^ B;
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
                $display("[ALU] XOR operation. A=%h, B=%h. Result C=%h", A, B, C);
            end
            
            4'hB: begin // NAND
                C = ~(A & B);
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
                $display("[ALU] NAND operation. A=%h, B=%h. Result C=%h", A, B, C);
            end
            
            4'hC: begin // NOR
                C = ~(A | B);
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
                $display("[ALU] NOR operation. A=%h, B=%h. Result C=%h", A, B, C);
            end
            
            4'hD: begin // XNOR
                C = ~(A ^ B);
                Flags[6] = C[7];
                Flags[4] = (C == 8'h00);
                $display("[ALU] XNOR operation. A=%h, B=%h. Result C=%h", A, B, C);
            end

            default: begin
                C = 8'hXX;
                Flags = 7'h7F;
            end
        endcase
    end
endmodule


//======================================================================================
// Module 5: Top-Level Processor Module
// Description: Instantiates and connects all sub-modules (datapath, control unit,
//              ALU, and memory) to form the complete 8-bit processor.
//======================================================================================
module processor_8bit_debug(
    input wire clock, 
    input wire reset,
    output wire done
);
    // Internal wires connecting the modules
    wire [7:0]  IR_w, A_w, B_w, C_w, PC_w, PR_w, MAR_w, ALU_Result_w;
    wire [7:0]  to_memory_w, from_memory_w, address_w;
    wire [6:0]  Flags_w;
    wire [2:0]  Bus1_Sel_w; 
    wire [1:0]  Bus2_Sel_w, comp_res_w;
    wire [3:0]  ALU_Sel_w;
    wire        PC_Load_w, PC_Inc_w, PR_Inc_w, A_Load_w, B_Load_w, C_Load_w;
    wire        IR_Load_w, MAR_Load_w, Memory_Load_w, CCR_Load_w, write_w;
    wire [7:0]  CCR_Result_w;
    
    // Execution control logic
    reg         execution_phase;
    assign      done = file_finished_w;
    wire        file_finished_w;

    initial begin
        execution_phase = 1;
    end
    
    always @(*) begin
        if(file_finished_w) 
            execution_phase = 0;
    end

    // Module Instantiations
    data_memory RAM_inst (
        .clock(clock),
        .reset(reset),
        .address(address_w),
        .data_in(to_memory_w),
        .write(write_w),
        .data_out(from_memory_w)
    );

    datapath Datapath_inst (
        .reset(reset), .execute(execution_phase),
        .Bus1_Sel(Bus1_Sel_w), .Bus2_Sel(Bus2_Sel_w),
        .PC_Load(PC_Load_w), .PC_Inc(PC_Inc_w), .PR_Inc(PR_Inc_w),
        .A_Load(A_Load_w), .B_Load(B_Load_w), .C_Load(C_Load_w),
        .IR_Load(IR_Load_w), .MAR_Load(MAR_Load_w), .CCR_Load(CCR_Load_w), .Memory_Load(Memory_Load_w),
        .ALU_Result(ALU_Result_w), .from_memory(from_memory_w), .NZVC(Flags_w),
        .to_memory(to_memory_w), .address(address_w),
        .IR(IR_w), .A(A_w), .B(B_w), .C(C_w), .PC(PC_w), .MAR(MAR_w), .PR(PR_w), .CCR_Result(CCR_Result_w)
    );

    control_unit CU_inst (
        .clock(clock), .reset(reset), .execute(execution_phase),
        .IR(IR_w), .CCR_Result(CCR_Result_w),
        .IR_Load(IR_Load_w), .MAR_Load(MAR_Load_w),
        .PC_Load(PC_Load_w), .PC_Inc(PC_Inc_w),
        .A_Load(A_Load_w), .B_Load(B_Load_w), .C_Load(C_Load_w),
        .ALU_Sel(ALU_Sel_w), .CCR_Load(CCR_Load_w),
        .Bus1_Sel(Bus1_Sel_w), .Bus2_Sel(Bus2_Sel_w),
        .write(write_w), .file_finished(file_finished_w)
    );

    ALU ALU_inst (
        .A(A_w), .B(B_w), 
        .ALU_Sel(ALU_Sel_w),
        .C(ALU_Result_w),
        .Flags(Flags_w),
        .comparison_result(comp_res_w),
        .ALU_Cout() // Not used in this design
    );

endmodule
