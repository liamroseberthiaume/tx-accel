
`timescale 1ns/1ps

module tb_tx_accel_fifo_backpressure;

    // Start with a 1x1 array
    localparam int N = 1;
    localparam int DATA_WIDTH = 8;
    localparam int ACC_WIDTH = 32;

    // Clock and reset
    logic clk = 0;
    logic rst_n;

    // Accelerator inputs
    logic [N*DATA_WIDTH-1:0] in_a;
    logic [N*DATA_WIDTH-1:0] in_b;

    logic in_first;
    logic in_last;
    logic in_valid;
    logic in_ready;

    // Accelerator outputs
    logic [N*N*ACC_WIDTH-1:0] result_c;
    logic result_valid;
    logic result_ready;

    integer cycles;

    // Clock period = 10 ns
    always #5 clk = ~clk;

    // =====================================
    // Device Under Test
    // =====================================

    tx_accel_top #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .FIFO_DEPTH(4)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .in_a(in_a),
        .in_b(in_b),
        .in_first(in_first),
        .in_last(in_last),
        .in_valid(in_valid),
        .in_ready(in_ready),

        .result_c(result_c),
        .result_valid(result_valid),
        .result_ready(result_ready)
    );

    // =====================================
    // Test 1: End-to-End 1x1 Multiplication
    // =====================================

    initial begin

        // Reset the accelerator
        rst_n = 0;

        in_a = 0;
        in_b = 0;
        in_first = 0;
        in_last = 0;
        in_valid = 0;

        result_ready = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;

        // Send A = 3 and B = 4
        @(negedge clk);

        in_a = 8'd3;
        in_b = 8'd4;

        in_first = 1;
        in_last = 1;
        in_valid = 1;

        #1;

        // FIFO should be ready to accept data
        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: FIFO not ready");

        // Accept the input packet
        @(posedge clk);
        @(negedge clk);

        in_valid = 0;
        in_first = 0;
        in_last = 0;

        // Wait for completed result
        // Limit waiting to 30 clock cycles
        cycles = 0;

        while (result_valid !== 1'b1 &&
               cycles < 30) begin
            @(negedge clk);
            cycles = cycles + 1;
        end

        if (result_valid !== 1'b1)
            $fatal(1, "FAIL: Result timeout");

        // Verify 3 * 4 = 12
        if (result_c !== 32'd12)
            $fatal(1,
                "FAIL: Expected 12, got %0d",
                $signed(result_c));

        $display("PASS: 1x1 multiplication = 12");

        // Check that result stays valid
        // while receiver is not ready
        repeat (3) begin
            @(negedge clk);

            if (result_valid !== 1'b1 ||
                result_c !== 32'd12)
                $fatal(1, "FAIL: Result not held");
        end

        $display("PASS: Result backpressure");


        // =====================================
        // Test 2: Fill FIFO While Controller Busy
        // =====================================

        // The controller is still holding the
        // previous result because result_ready = 0.

        for (int p = 0; p < 4; p = p + 1) begin

            @(negedge clk);

            // Each packet represents a new
            // single-element matrix operation.
            in_a = 8'(p + 1);
            in_b = 8'd2;

            in_first = 1;
            in_last = 1;
            in_valid = 1;

            #1;

            // There should be room for this packet.
            if (in_ready !== 1'b1)
                $fatal(1,
                    "FAIL: FIFO rejected packet %0d",
                    p + 1);

            // Packet is accepted on this edge.
            @(posedge clk);

            $display("FIFO accepted packet %0d", p + 1);

        end

        // Stop sending once all four packets
        // have been accepted.
        @(negedge clk);

        in_valid = 0;
        in_first = 0;
        in_last = 0;

        #1;

        // FIFO is full and controller is busy.
        if (in_ready !== 1'b0)
            $fatal(1, "FAIL: FIFO should be full");

        // Original result must still be held.
        if (result_valid !== 1'b1 ||
            result_c !== 32'd12)
            $fatal(1, "FAIL: Original result changed");

        $display("PASS: FIFO filled to capacity");
        $display("PASS: Original result preserved");


        // =====================================
        // Test 3: Fifth Packet Must Wait
        // =====================================

        @(negedge clk);

        // Attempt to send a fifth packet.
        in_a = 8'd5;
        in_b = 8'd2;

        in_first = 1;
        in_last = 1;
        in_valid = 1;

        #1;

        // The FIFO is full, so it must
        // reject the new transfer.
        if (in_ready !== 1'b0)
            $fatal(1, "FAIL: Fifth packet was not blocked");

        // Keep the fifth packet available
        // for three clock cycles.
        repeat (3) begin
            @(posedge clk);
            #1;

            if (in_ready !== 1'b0)
                $fatal(1, "FAIL: FIFO accepted fifth packet too early");

            if (result_valid !== 1'b1 ||
                result_c !== 32'd12)
                $fatal(1, "FAIL: Previous result changed");
        end

        $display("PASS: Fifth packet blocked while FIFO full");

       
        // =====================================
        // Test 4: FIFO Recovery
        // =====================================

        // Allow the original result to be accepted.
        @(negedge clk);
        result_ready = 1;

        @(posedge clk);
        #1;

        if (result_valid !== 1'b0)
            $fatal(1, "FAIL: Original result not accepted");

        $display("PASS: Original result accepted");

        // The controller is now in IDLE.
        // The fifth packet is still waiting.
        @(negedge clk);
        #1;

        // A FIFO read should make room for P5.
        if (in_valid !== 1'b1 ||
            in_ready !== 1'b1)
            $fatal(1, "FAIL: FIFO did not recover");

        // Accept the fifth packet.
        @(posedge clk);
        #1;

        // Stop sending to avoid duplicates.
        in_valid = 0;
        in_first = 0;
        in_last = 0;

        // Hold subsequent results for verification.
        result_ready = 0;

        $display("PASS: Fifth packet accepted after FIFO read");
        $display("Step 2.9B: FIFO recovery handshake PASSED");

        
        // =====================================
        // Test 5: Verify All Five Queued Results
        // =====================================

        for (int p = 1; p <= 5; p = p + 1) begin

            // Wait for the next completed result.
            cycles = 0;

            while (result_valid !== 1'b1 &&
                   cycles < 50) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (result_valid !== 1'b1)
                $fatal(1,
                    "FAIL: Timeout waiting for result %0d", p);

            // Each packet calculated p * 2.
            if ($signed(result_c) !== (p * 2))
                $fatal(1,
                    "FAIL: Result %0d got %0d, expected %0d",
                    p, $signed(result_c), p * 2);

            $display(
                "PASS: Queued result %0d = %0d",
                p, $signed(result_c)
            );

            // Accept the result on a rising edge.
            @(negedge clk);
            result_ready = 1;

            @(posedge clk);
            #1;

            if (result_valid !== 1'b0)
                $fatal(1,
                    "FAIL: Result %0d not accepted", p);

            // Stop accepting results until
            // the next one has been checked.
            @(negedge clk);
            result_ready = 0;

        end

        $display("PASS: All five queued results verified");
        $display("Step 2.9B: FIFO backpressure PASSED");

        $finish;

    end


endmodule
