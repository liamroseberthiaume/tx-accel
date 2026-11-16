
`timescale 1ns/1ps

module tb_input_fifo;

    localparam int N = 2;
    localparam int DATA_WIDTH = 8;
    localparam int DEPTH = 4;

    logic clk = 0;
    logic rst_n;

    // Input interface
    logic [N*DATA_WIDTH-1:0] in_a, in_b;
    logic in_first, in_last;
    logic in_valid;
    logic in_ready;

    // Output interface
    logic [N*DATA_WIDTH-1:0] out_a, out_b;
    logic out_first, out_last;
    logic out_valid;
    logic out_ready;

    // Instantiate the FIFO
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

    // Clock period = 10 ns
    always #5 clk = ~clk;

    initial begin
        // Initialize all inputs
        rst_n = 0;

        in_a = '0;
        in_b = '0;
        in_first = 0;
        in_last = 0;
        in_valid = 0;
        out_ready = 0;

        // Hold reset for two cycles
        repeat (2) @(negedge clk);
        rst_n = 1;

        $display("FIFO testbench initialized.");

        
        // =====================================
        // TEST 1: Reset and Empty FIFO
        // =====================================

        #1; // Allow signals to settle after reset

        if (out_valid !== 1'b0)
            $fatal(1, "TEST 1 FAILED: FIFO is not empty");

        if (in_ready !== 1'b1)
            $fatal(1, "TEST 1 FAILED: FIFO is not ready");

        if (out_a !== '0 || out_b !== '0)
            $fatal(1, "TEST 1 FAILED: Output data not zero");

        if (out_first !== 1'b0 || out_last !== 1'b0)
            $fatal(1, "TEST 1 FAILED: Output flags not zero");

        $display("TEST 1 PASSED: FIFO reset and empty");


        // =====================================
        // TEST 2: Store and retrieve one packet
        // =====================================

        $display("Starting TEST 2: Packet storage...");

        // Supply a packet on the falling clock edge
        @(negedge clk);

        in_a = 16'h1234;
        in_b = 16'hABCD;
        in_first = 1;
        in_last = 0;
        in_valid = 1;
        out_ready = 0;

        // FIFO should have space to accept the packet
        #1;
        if (in_ready !== 1'b1)
            $fatal(1, "TEST 2 FAILED: FIFO not ready");

        // Wait for the FIFO to store the packet
        @(posedge clk);
        #1;

        // Verify the stored packet appears at the output
        if (out_valid !== 1'b1)
            $fatal(1, "TEST 2 FAILED: Output not valid");

        if (out_a !== 16'h1234)
            $fatal(1, "TEST 2 FAILED: A data incorrect");

        if (out_b !== 16'hABCD)
            $fatal(1, "TEST 2 FAILED: B data incorrect");

        if (out_first !== 1'b1 || out_last !== 1'b0)
            $fatal(1, "TEST 2 FAILED: Flags incorrect");

        $display("TEST 2: Packet stored correctly");

        // Allow the receiver to accept the packet
        @(negedge clk);

        in_valid = 0;
        out_ready = 1;

        @(posedge clk);
        #1;

        // The FIFO should now be empty
        if (out_valid !== 1'b0)
            $fatal(1, "TEST 2 FAILED: FIFO not empty");

        $display("TEST 2 PASSED: Packet stored and retrieved");

        // =====================================
        // TEST 3: Backpressure
        // =====================================

        $display("Starting TEST 3: Backpressure...");

        // Send one packet into the FIFO
        @(negedge clk);

        in_a = 16'hCAFE;
        in_b = 16'hBEEF;
        in_first = 0;
        in_last = 1;
        in_valid = 1;

        // Receiver is not ready
        out_ready = 0;

        @(posedge clk);
        #1;

        // The packet should now be stored
        if (out_valid !== 1'b1)
            $fatal(1, "TEST 3 FAILED: Packet not valid");

        // Stop sending data and change input values
        @(negedge clk);

        in_valid = 0;
        in_a = 16'h0000;
        in_b = 16'h0000;
        in_first = 0;
        in_last = 0;

        // Wait three clock cycles while receiver is busy
        repeat (3) begin
            @(posedge clk);
            #1;

            if (out_valid !== 1'b1)
                $fatal(1, "TEST 3 FAILED: Packet disappeared");

            if (out_a !== 16'hCAFE)
                $fatal(1, "TEST 3 FAILED: A changed");

            if (out_b !== 16'hBEEF)
                $fatal(1, "TEST 3 FAILED: B changed");

            if (out_first !== 1'b0 ||
                out_last !== 1'b1)
                $fatal(1, "TEST 3 FAILED: Flags changed");
        end

        $display("TEST 3: Packet held during backpressure");

        // Receiver becomes ready
        @(negedge clk);
        out_ready = 1;

        @(posedge clk);
        #1;

        // Packet should now have been removed
        if (out_valid !== 1'b0)
            $fatal(1, "TEST 3 FAILED: FIFO not empty");

        $display("TEST 3 PASSED: Backpressure handled");

        // =====================================
        // TEST 4: Full FIFO
        // =====================================

        $display("Starting TEST 4: Full FIFO...");

        // Stop the receiver from removing packets
        out_ready = 0;

        // Fill all four storage locations
        for (int i = 0; i < DEPTH; i = i + 1) begin

            @(negedge clk);

            in_a = 16'h1000 + i;
            in_b = 16'h2000 + i;
            in_first = (i == 0);
            in_last = (i == DEPTH - 1);
            in_valid = 1;

            #1;

            if (in_ready !== 1'b1)
                $fatal(1, "TEST 4 FAILED: FIFO filled too early");

            @(posedge clk);
            #1;
        end

        // After four writes, the FIFO must be full
        if (in_ready !== 1'b0)
            $fatal(1, "TEST 4 FAILED: FIFO should be full");

        if (out_valid !== 1'b1)
            $fatal(1, "TEST 4 FAILED: FIFO output not valid");

        $display("TEST 4: FIFO full correctly");

        // Attempt to send a fifth packet
        @(negedge clk);

        in_a = 16'hDEAD;
        in_b = 16'hBEEF;
        in_first = 0;
        in_last = 1;
        in_valid = 1;

        #1;

        if (in_ready !== 1'b0)
            $fatal(1, "TEST 4 FAILED: Accepted fifth packet");

        @(posedge clk);
        #1;

        // The oldest stored packet must remain unchanged
        if (out_a !== 16'h1000 ||
            out_b !== 16'h2000 ||
            out_first !== 1'b1 ||
            out_last !== 1'b0)
            $fatal(1, "TEST 4 FAILED: Oldest packet corrupted");

        if (in_ready !== 1'b0)
            $fatal(1, "TEST 4 FAILED: FIFO no longer full");

        $display("TEST 4 PASSED: Full FIFO blocks new data");

        // =====================================
        // TEST 5: Simultaneous Read and Write
        // =====================================

        $display("Starting TEST 5: Simultaneous transfer...");

        // TEST 4 left the fifth packet waiting:
        // in_a = DEAD, in_b = BEEF, in_valid = 1.
        // Keep that packet unchanged until accepted.

        @(negedge clk);

        // Receiver is now ready to take the oldest packet
        out_ready = 1;

        #1;

        // Even though the FIFO is full, it can accept
        // a new packet because one will leave.
        if (in_ready !== 1'b1)
            $fatal(1, "TEST 5 FAILED: Simultaneous write blocked");

        if (out_a !== 16'h1000 || out_b !== 16'h2000)
            $fatal(1, "TEST 5 FAILED: Wrong oldest packet");

        // One read and one write happen on this edge
        @(posedge clk);
        #1;

        // The next oldest packet should now be visible
        if (out_valid !== 1'b1)
            $fatal(1, "TEST 5 FAILED: Output not valid");

        if (out_a !== 16'h1001 || out_b !== 16'h2001)
            $fatal(1, "TEST 5 FAILED: Packet order incorrect");

        // Stop sending and receiving
        @(negedge clk);
        in_valid = 0;
        out_ready = 0;

        #1;

        // FIFO should still be full
        if (in_ready !== 1'b0)
            $fatal(1, "TEST 5 FAILED: Occupancy incorrect");

        $display("TEST 5 PASSED: Simultaneous read/write");

        // =====================================
        // TEST 6: FIFO Ordering and Wraparound
        // =====================================

        $display("Starting TEST 6: Packet ordering...");

        // TEST 5 left four packets in this order:
        // 1001, 1002, 1003, DEAD
        // The FIFO is full and out_ready is currently 0.

        for (int i = 0; i < DEPTH; i = i + 1) begin

            // Prepare to read the oldest packet
            @(negedge clk);
            out_ready = 1;
            in_valid = 0;

            #1;

            if (out_valid !== 1'b1)
                $fatal(1, "TEST 6 FAILED: Missing packet %0d", i);

            // Verify the complete packet BEFORE removing it.
            case (i)

                0: begin
                    if ({out_first, out_last, out_a, out_b}
                        !== {1'b0, 1'b0, 16'h1001, 16'h2001})
                        $fatal(1, "TEST 6 FAILED: Packet 1001");
                end

                1: begin
                    if ({out_first, out_last, out_a, out_b}
                        !== {1'b0, 1'b0, 16'h1002, 16'h2002})
                        $fatal(1, "TEST 6 FAILED: Packet 1002");
                end

                2: begin
                    if ({out_first, out_last, out_a, out_b}
                        !== {1'b0, 1'b1, 16'h1003, 16'h2003})
                        $fatal(1, "TEST 6 FAILED: Packet 1003");
                end

                3: begin
                    if ({out_first, out_last, out_a, out_b}
                        !== {1'b0, 1'b1, 16'hDEAD, 16'hBEEF})
                        $fatal(1, "TEST 6 FAILED: Packet DEAD");
                end

            endcase

            $display("TEST 6: Packet %0d ordering PASSED", i+1);

            // Receiver accepts the packet on this edge
            @(posedge clk);
            #1;
        end

        // All four packets should now be removed.
        if (out_valid !== 1'b0)
            $fatal(1, "TEST 6 FAILED: FIFO not empty");

        if (in_ready !== 1'b1)
            $fatal(1, "TEST 6 FAILED: FIFO not ready after drain");

        if (out_a !== '0 || out_b !== '0)
            $fatal(1, "TEST 6 FAILED: Empty outputs not zero");

        $display("TEST 6 PASSED: Ordering and wraparound");


        $finish;
    end

endmodule
