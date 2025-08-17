`timescale 1ns / 1ps

//======================================================================================
// Module: processor_top
//
// Author: Alisson Jaime Sales Barros
// Course: Microprocessors - Federal University of Ceará (UFC)
//
// Description:
// This is the top-level module for the 8-bit CPU. It instantiates and connects
// all the core components: the datapath, the control unit, the ALU, and the
// data memory. This module represents the complete, integrated processor design.
//
//======================================================================================
module processor_top(
    input wire clock, 
    input wire reset,
    output wire done
);
    //==================================================================================
    // Internal Wires for Inter-Module Communication
    //==================================================================================

    // Control Signals
    wire        PC_Load_w, PC_Inc_w, PR_Inc_w, A_Load_w, B_Load_w, C_Load_w;
    wire        IR_Load_w, MAR_Load_w, CCR_Load_w, Memory_Load_w, write_w;
    wire [2:0]  Bus1_Sel_w; 
    wire [1:0]  Bus2_Sel_w;
    wire [3:0]  ALU_Sel_w;

    // Data Busses and Register Values
    wire [7:0]  IR_w, A_w, B_w, C_w, PC_w, PR_w, MAR_w, ALU_Result_w;
    wire [7:0]  to_memory_w, from_memory_w, address_w;
    wire [7:0]  CCR_Result_w;
    wire [6:0]  Flags_w;
    wire [1:0]  comp_res_w;
    
    // Execution Control
    reg         execution_phase;
    assign      done = file_finished_w;
    wire        file_finished_w;

    initial begin
        execution_phase = 1'b1;
    end
    
    always @(*) begin
        if(file_finished_w) 
            execution_phase = 1'b0;
    end

    //==================================================================================
    // Module Instantiations
    //==================================================================================

    // 1. Data Memory (RAM)
    data_memory RAM_inst (
        .clock(clock),
        .reset(reset),
        .address(address_w),
        .data_in(to_memory_w),
        .write(write_w),
        .data_out(from_memory_w)
    );

    // 2. Datapath
    datapath Datapath_inst (
        .clock(clock),
        .reset(reset),
        .Bus1_Sel(Bus1_Sel_w), 
        .Bus2_Sel(Bus2_Sel_w),
        .PC_Load(PC_Load_w), .PC_Inc(PC_Inc_w), .PR_Inc(PR_Inc_w),
        .A_Load(A_Load_w), .B_Load(B_Load_w), .C_Load(C_Load_w),
        .IR_Load(IR_Load_w), .MAR_Load(MAR_Load_w), .CCR_Load(CCR_Load_w), .Memory_Load(Memory_Load_w),
        .ALU_Result(ALU_Result_w), 
        .from_memory(from_memory_w), 
        .NZVC(Flags_w),
        .to_memory(to_memory_w), 
        .address(address_w),
        .IR(IR_w), .A(A_w), .B(B_w), .C(C_w), .PC(PC_w), .MAR(MAR_w), .PR(PR_w), .CCR_Result(CCR_Result_w)
    );

    // 3. Control Unit (FSM)
    control_unit CU_inst (
        .clock(clock), 
        .reset(reset), 
        .execute(execution_phase),
        .IR(IR_w), 
        .CCR_Result(CCR_Result_w),
        .IR_Load(IR_Load_w), .MAR_Load(MAR_Load_w),
        .PC_Load(PC_Load_w), .PC_Inc(PC_Inc_w),
        .A_Load(A_Load_w), .B_Load(B_Load_w), .C_Load(C_Load_w),
        .ALU_Sel(ALU_Sel_w), .CCR_Load(CCR_Load_w),
        .Bus1_Sel(Bus1_Sel_w), .Bus2_Sel(Bus2_Sel_w),
        .write(write_w), 
        .file_finished(file_finished_w)
    );

    // 4. Arithmetic Logic Unit (ALU)
    ALU ALU_inst (
        .A(A_w), 
        .B(B_w), 
        .ALU_Sel(ALU_Sel_w),
        .C(ALU_Result_w),
        .Flags(Flags_w),
        .comparison_result(comp_res_w),
        .ALU_Cout() // Carry-out not used in this top-level design
    );

endmodule
