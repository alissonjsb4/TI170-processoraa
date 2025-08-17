`timescale 1ns / 1ps

//======================================================================================
// Testbench for the 8-bit CPU (with Result Verification)
//
// Author: Alisson Jaime Sales Barros
// Course: Microprocessors - Federal University of Ceará (UFC)
//
// Description:
// This testbench simulates the 8-bit processor and includes a verification step.
// After the processor asserts its 'done' signal, the testbench reads the final
// state of the processor's data memory and writes it to an output file,
// 'answer.bin', for validation.
//
//======================================================================================

module processor_8bit_tb;

    // Testbench signals
    reg     clock;
    reg     reset;
    wire    done;

    // Instantiate the Unit Under Test (UUT)
    // We instantiate the _debug version to see the detailed simulation logs.
    processor_8bit_debug uut (
        .clock(clock),
        .reset(reset),
        .done(done)
    );

    // Clock Generation: 100MHz clock (10ns period)
    initial begin
        clock = 0;
        forever #5 clock = ~clock; // 5ns half-period -> 10ns full period
    end

    // Simulation Stimulus and Verification
    initial begin
        integer i;
        integer file_id;

        $display("[TB] Simulation Started.");
        
        // 1. Assert reset to initialize the processor
        reset = 1'b1;
        $display("[TB] Reset is Asserted.");
        #20; // Wait for 20ns

        // 2. De-assert reset to start program execution
        reset = 1'b0;
        $display("[TB] Reset is De-asserted. Processor execution begins.");

        // 3. Wait for the 'done' signal from the processor
        wait(uut.done);
        
        $display("[TB] 'done' signal received. Program finished.");
        $display("[TB] Writing memory contents to answer.bin...");

        // 4. Open the output file for writing
        file_id = $fopen("answer.bin", "wb");
        if (file_id == 0) begin
            $display("[TB] ERROR: Could not open answer.bin for writing.");
            $finish;
        end

        // 5. Read the processor's internal memory and write to the file
        // We use hierarchical names to access signals inside the UUT.
        for (i = 0; i < 128; i = i + 1) begin
            // Accessing the memory array RW inside the RAM_inst instance
            $fwrite(file_id, "%c", uut.RAM_inst.RW[i]);
        end

        // 6. Close the file and end the simulation
        $fclose(file_id);
        $display("[TB] Successfully wrote memory contents to answer.bin.");
        $finish;
    end
    
    // Simulation Timeout
    initial begin
        #5000; // Wait for 5000ns (5us)
        $display("[TB] ERROR: Simulation timed out after 5us. 'done' signal was not received.");
        $finish;
    end

endmodule
