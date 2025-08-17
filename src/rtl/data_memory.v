`timescale 1ns / 1ps

//======================================================================================
// Module: data_memory
//
// Author: Alisson Jaime Sales Barros
// Course: Microprocessors - Federal University of Ceará (UFC)
//
// Description:
// This module implements a 128-byte synchronous RAM for data storage. It functions
// as a unified memory for both instructions and data (Von Neumann architecture).
// For simulation purposes, it is initialized with a binary program file ("file.bin").
//
//======================================================================================
module data_memory(
    input               clock,      // System clock
    input               reset,      // System reset (not used in this module, but good practice)
    input       [7:0]   address,    // Memory address
    input       [7:0]   data_in,    // Data to be written
    input               write,      // Write enable signal
    output reg  [7:0]   data_out    // Data read from memory
);

    // Declare the 128x8-bit memory array
    reg [7:0] RW[0:127];

    // Initialize memory content from a file at the start of simulation.
    // This is a non-synthesizable block for simulation setup only.
    initial begin
        $readmemb("file.bin", RW);
    end
  
    // Internal enable logic to protect against out-of-bounds access.
    reg enable;
    always @ (*) begin
        if (address <= 127)
            enable = 1'b1;
        else
            enable = 1'b0;
    end

    // Synchronous read/write logic.
    // On the positive edge of the clock, either write new data or read existing data.
    always @ (posedge clock) begin
        if (write && enable) begin
            RW[address] <= data_in;
        end else if (!write && enable) begin
            data_out <= RW[address];
        end
    end

endmodule
