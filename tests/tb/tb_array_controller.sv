
`timescale 1ns/1ps

module tb_array_controller;

    localparam int N = 2;
    localparam int DATA_WIDTH = 8;
    localparam int ACC_WIDTH = 32;

    // Clock and reset
    logic clk = 0;
    logic rst_n;

    // FIFO signals
    logic [N*DATA_WIDTH-1:0] fifo_a, fifo_b;
    logic fifo_first, fifo_last, fifo_valid;
    logic fifo_ready;

    // Systolic array signals
    logic [N*DATA_WIDTH-1:0] array_a_in, array_b_in;
    logic array_valid_in, array_first_in, array_last_in;
    logic [N*N*ACC_WIDTH-1:0] array_c_out;
    logic array_done;

    // Result signals
    logic [N*N*ACC_WIDTH-1:0] result_c;
    logic result_valid, result_ready;

    // Generate clock: 10 ns period
    always #5 clk = ~clk;

    // Device Under Test (DUT)
    array_controller #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .fifo_a(fifo_a),
        .fifo_b(fifo_b),
        .fifo_first(fifo_first),
        .fifo_last(fifo_last),
        .fifo_valid(fifo_valid),
        .fifo_ready(fifo_ready),

        .array_a_in(array_a_in),
        .array_b_in(array_b_in),
        .array_valid_in(array_valid_in),
        .array_first_in(array_first_in),
        .array_last_in(array_last_in),
        .array_c_out(array_c_out),
        .array_done(array_done),

        .result_c(result_c),
        .result_valid(result_valid),
        .result_ready(result_ready)
    );

    // =====================================
    // Test 1: Reset
    // =====================================

    initial begin
        rst_n = 0;

        fifo_a = '0;
        fifo_b = '0;
        fifo_first = 0;
        fifo_last = 0;
        fifo_valid = 0;

        array_c_out = '0;
        array_done = 0;
        result_ready = 0;

        #12;

        if (result_c !== '0 ||
            result_valid !== 1'b0 ||
            array_valid_in !== 1'b0 ||
            fifo_ready !== 1'b0)
            $fatal(1, "FAIL: Controller reset");

        $display("PASS: Controller reset");

        rst_n = 1;
        #10;

        
        $display("Step 2.5C.1 PASSED");

        // =====================================
        // Test 2: IDLE to FEED Transition
        // =====================================

        // Present the first packet before a
        // rising clock edge.
        @(negedge clk);

        fifo_a = 16'h0102;
        fifo_b = 16'h0304;

        fifo_first = 1;
        fifo_last = 0;
        fifo_valid = 1;

        #1;

        // Verify the packet is accepted and
        // forwarded correctly to the array.
        if (fifo_ready !== 1'b1 ||
            array_valid_in !== 1'b1 ||
            array_first_in !== 1'b1 ||
            array_last_in !== 1'b0 ||
            array_a_in !== 16'h0102 ||
            array_b_in !== 16'h0304)
            $fatal(1, "FAIL: First packet transfer");

        // Allow the controller to enter FEED.
        @(posedge clk);
        #1;

        // Remove the packet after its transfer.
        fifo_valid = 0;
        fifo_first = 0;

        #1;

        // In FEED, the controller remains ready
        // for another packet, even when empty.
        if (fifo_ready !== 1'b1 ||
            array_valid_in !== 1'b0 ||
            result_valid !== 1'b0)
            $fatal(1, "FAIL: IDLE to FEED transition");

        $display("PASS: IDLE to FEED transition");
        $display("Step 2.5C.2 PASSED");

        
        // =====================================
        // Test 3: FEED to WAIT_DONE
        // =====================================

        // Test A: FIFO temporarily empty.
        // The controller should stay in FEED.
        @(negedge clk);
        #1;

        if (fifo_ready !== 1'b1 ||
            array_valid_in !== 1'b0)
            $fatal(1, "FAIL: FIFO empty during FEED");

        // Test B: Send a middle packet.
        @(negedge clk);

        fifo_a = 16'h0506;
        fifo_b = 16'h0708;

        fifo_first = 0;
        fifo_last = 0;
        fifo_valid = 1;

        #1;

        if (array_valid_in !== 1'b1 ||
            array_first_in !== 1'b0 ||
            array_last_in !== 1'b0 ||
            array_a_in !== 16'h0506 ||
            array_b_in !== 16'h0708)
            $fatal(1, "FAIL: Middle packet transfer");

        @(posedge clk);
        #1;

        fifo_valid = 0;

        // Test C: Send the final packet.
        @(negedge clk);

        fifo_a = 16'h090A;
        fifo_b = 16'h0B0C;

        fifo_first = 0;
        fifo_last = 1;
        fifo_valid = 1;

        #1;

        if (fifo_ready !== 1'b1 ||
            array_valid_in !== 1'b1 ||
            array_last_in !== 1'b1 ||
            array_a_in !== 16'h090A ||
            array_b_in !== 16'h0B0C)
            $fatal(1, "FAIL: Final packet transfer");

        // The final packet is accepted here.
        @(posedge clk);
        #1;

        fifo_valid = 0;
        fifo_last = 0;

        #1;

        // Controller should now be in WAIT_DONE.
        // It must stop accepting new FIFO packets.
        if (fifo_ready !== 1'b0 ||
            array_valid_in !== 1'b0 ||
            result_valid !== 1'b0)
            $fatal(1, "FAIL: FEED to WAIT_DONE transition");

        $display("PASS: FEED to WAIT_DONE transition");
        $display("Step 2.5C.3 PASSED");

        
        // =====================================
        // Test 4: Result Capture and Backpressure
        // =====================================

        // Test A: Array has not finished.
        @(negedge clk);

        array_done = 0;
        result_ready = 0;

        #1;

        if (result_valid !== 1'b0)
            $fatal(1, "FAIL: Result valid before array done");

        // Test B: Array finishes calculation.
        @(negedge clk);

        array_c_out = {
            32'd50,
            32'd43,
            32'd22,
            32'd19
        };

        array_done = 1;

        // Result should be captured on the
        // next rising clock edge.
        @(posedge clk);
        #1;

        array_done = 0;

        if (result_valid !== 1'b1 ||
            result_c !== {32'd50, 32'd43, 32'd22, 32'd19})
            $fatal(1, "FAIL: Result capture");

        $display("PASS: Result captured");

        // Test C: Receiver is not ready.
        // Change the array output to verify
        // that the stored result stays unchanged.

        array_c_out = '0;
        result_ready = 0;

        repeat (3) begin
            @(posedge clk);
            #1;

            if (result_valid !== 1'b1 ||
                result_c !== {32'd50, 32'd43, 32'd22, 32'd19})
                $fatal(1, "FAIL: Result backpressure");
        end

        $display("PASS: Result held during backpressure");

        // Test D: Receiver accepts result.
        @(negedge clk);

        result_ready = 1;

        #1;

        if (result_valid !== 1'b1)
            $fatal(1, "FAIL: Result not available for transfer");

        @(posedge clk);
        #1;

        // Controller should return to IDLE.
        if (result_valid !== 1'b0 ||
            fifo_ready !== 1'b0)
            $fatal(1, "FAIL: RESULT to IDLE transition");

        $display("PASS: RESULT to IDLE transition");
        $display("Step 2.5C.4 PASSED");

        
        // =====================================
        // Test 5: Single-Packet Operation
        // =====================================

        // Controller should now be in IDLE.
        @(negedge clk);

        result_ready = 0;

        fifo_a = 16'h0102;
        fifo_b = 16'h0304;

        fifo_first = 1;
        fifo_last = 1;
        fifo_valid = 1;

        #1;

        // First and last flags must both
        // reach the systolic array.
        if (fifo_ready !== 1'b1 ||
            array_valid_in !== 1'b1 ||
            array_first_in !== 1'b1 ||
            array_last_in !== 1'b1 ||
            array_a_in !== 16'h0102 ||
            array_b_in !== 16'h0304)
            $fatal(1, "FAIL: Single-packet transfer");

        // Accept the single packet.
        @(posedge clk);
        #1;

        fifo_valid = 0;
        fifo_first = 0;
        fifo_last = 0;

        #1;

        // Controller must go directly
        // to WAIT_DONE, skipping FEED.
        if (fifo_ready !== 1'b0 ||
            array_valid_in !== 1'b0 ||
            result_valid !== 1'b0)
            $fatal(1, "FAIL: Single-packet WAIT_DONE");

        $display("PASS: Single-packet WAIT_DONE");

        // Simulate completion of the calculation.
        @(negedge clk);

        array_c_out = {
            32'd40,
            32'd30,
            32'd20,
            32'd10
        };

        array_done = 1;

        @(posedge clk);
        #1;

        array_done = 0;

        // Check that the result was captured.
        if (result_valid !== 1'b1 ||
            result_c !== {32'd40, 32'd30, 32'd20, 32'd10})
            $fatal(1, "FAIL: Single-packet result");

        $display("PASS: Single-packet result captured");

        // Receiver accepts the result.
        @(negedge clk);
        result_ready = 1;

        @(posedge clk);
        #1;

        if (result_valid !== 1'b0 ||
            fifo_ready !== 1'b0)
            $fatal(1, "FAIL: Single-packet return to IDLE");

        $display("PASS: Single-packet operation");
        $display("Step 2.5C.5 PASSED");

        $finish;

    end

endmodule
