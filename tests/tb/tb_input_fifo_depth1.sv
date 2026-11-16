
`timescale 1ns/1ps

module tb_input_fifo_depth1;

    localparam int N = 2;
    localparam int DATA_WIDTH = 8;
    localparam int DEPTH = 1;

    logic clk = 0;
    logic rst_n;

    // Input signals
    logic [15:0] in_a, in_b;
    logic in_first, in_last;
    logic in_valid, in_ready;

    // Output signals
    logic [15:0] out_a, out_b;
    logic out_first, out_last;
    logic out_valid, out_ready;

    // Instantiate single-slot FIFO
    input_fifo #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .in_a(in_a),
        .in_b(in_b),
        .in_first(in_first),
        .in_last(in_last),
        .in_valid(in_valid),
        .in_ready(in_ready),

        .out_a(out_a),
        .out_b(out_b),
        .out_first(out_first),
        .out_last(out_last),
        .out_valid(out_valid),
        .out_ready(out_ready)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;

        in_a = '0;
        in_b = '0;
        in_first = 0;
        in_last = 0;
        in_valid = 0;
        out_ready = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;

        $display("Starting DEPTH=1 FIFO tests...");

        
        // =====================================
        // TEST 1: Single-Slot Storage and Hold
        // =====================================

        $display("Starting TEST 1: Storage and backpressure...");

        // Supply the first packet
        @(negedge clk);

        in_a = 16'h1357;
        in_b = 16'h2468;
        in_first = 1;
        in_last = 0;
        in_valid = 1;
        out_ready = 0;

        #1;

        // Empty FIFO must be ready to accept data
        if (in_ready !== 1'b1)
            $fatal(1, "TEST 1 FAILED: FIFO not ready");

        // Store the packet on the rising edge
        @(posedge clk);
        #1;

        // FIFO should now contain one packet
        if (out_valid !== 1'b1)
            $fatal(1, "TEST 1 FAILED: Output not valid");

        if (in_ready !== 1'b0)
            $fatal(1, "TEST 1 FAILED: FIFO not full");

        // Check the complete stored packet
        if (out_a !== 16'h1357 ||
            out_b !== 16'h2468 ||
            out_first !== 1'b1 ||
            out_last !== 1'b0)
            $fatal(1, "TEST 1 FAILED: Stored data incorrect");

        // Stop supplying data and change the inputs
        @(negedge clk);

        in_valid = 0;
        in_a = 16'h0000;
        in_b = 16'h0000;
        in_first = 0;
        in_last = 0;

        // Receiver remains not ready
        out_ready = 0;

        // Hold the packet for three clock cycles
        repeat (3) begin
            @(posedge clk);
            #1;

            if (out_valid !== 1'b1)
                $fatal(1, "TEST 1 FAILED: Packet disappeared");

            if (in_ready !== 1'b0)
                $fatal(1, "TEST 1 FAILED: FIFO not full");

            if (out_a !== 16'h1357 ||
                out_b !== 16'h2468 ||
                out_first !== 1'b1 ||
                out_last !== 1'b0)
                $fatal(1, "TEST 1 FAILED: Packet changed");
        end

        $display("TEST 1 PASSED: Single-slot storage and hold");

        // =====================================
        // TEST 2: Simultaneous Read and Write
        // =====================================

        $display("Starting TEST 2: Simultaneous transfer...");

        // TEST 1 left the FIFO full with:
        // A = 1357, B = 2468, first = 1, last = 0

        @(negedge clk);

        // Present a new packet
        in_a = 16'hABCD;
        in_b = 16'hEF01;
        in_first = 0;
        in_last = 1;
        in_valid = 1;

        // Receiver is ready to take the old packet
        out_ready = 1;

        #1;

        // Full FIFO must allow a simultaneous transfer
        if (in_ready !== 1'b1)
            $fatal(1, "TEST 2 FAILED: Input not ready");

        // Old packet must still be available
        if (out_valid !== 1'b1 ||
            out_a !== 16'h1357 ||
            out_b !== 16'h2468 ||
            out_first !== 1'b1 ||
            out_last !== 1'b0)
            $fatal(1, "TEST 2 FAILED: Old packet incorrect");

        // Both transfers occur on this rising edge
        @(posedge clk);
        #1;

        // FIFO should now contain the NEW packet
        if (out_valid !== 1'b1 ||
            out_a !== 16'hABCD ||
            out_b !== 16'hEF01 ||
            out_first !== 1'b0 ||
            out_last !== 1'b1)
            $fatal(1, "TEST 2 FAILED: New packet incorrect");

        // Stop incoming and outgoing transfers
        @(negedge clk);
        in_valid = 0;
        out_ready = 0;

        #1;

        // The FIFO must still be full
        if (in_ready !== 1'b0)
            $fatal(1, "TEST 2 FAILED: FIFO not full");

        $display("TEST 2: Simultaneous replacement PASSED");

        // Remove the new packet
        @(negedge clk);
        out_ready = 1;

        @(posedge clk);
        #1;

        // FIFO should now be empty
        if (out_valid !== 1'b0)
            $fatal(1, "TEST 2 FAILED: FIFO not empty");

        if (in_ready !== 1'b1)
            $fatal(1, "TEST 2 FAILED: FIFO not ready");

        $display("TEST 2 PASSED: Single-slot read/write");


        $finish;
    end

endmodule
