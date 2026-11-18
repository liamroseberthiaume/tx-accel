
`timescale 1ns/1ps

module tb_tx_accel_output_buffering;

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

        $display("PASS: First result buffered correctly");

        // =====================================
        // Test 2: Buffer a Second Result
        // =====================================

        // Keep the receiver blocked.
        @(negedge clk);
        result_ready = 1'b0;

        // Send the second operation: 5 * 6 = 30
        in_a = 8'd5;
        in_b = 8'd6;
        in_first = 1'b1;
        in_last = 1'b1;
        in_valid = 1'b1;

        #1;

        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: Second packet not accepted");

        // Accept the second packet.
        @(posedge clk);

        // Stop sending packets.
        @(negedge clk);
        in_valid = 1'b0;
        in_first = 1'b0;
        in_last = 1'b0;

        $display("PASS: Second operation sent");

        // Wait until the output FIFO contains
        // both completed results.
        cycles = 0;

        while (dut.u_output_fifo.count !== 2 && cycles < 50) begin
            @(negedge clk);
            cycles = cycles + 1;
        end

        if (dut.u_output_fifo.count !== 2)
            $fatal(1, "FAIL: Two results were not buffered");

        // The oldest result must still be 12.
        if (result_valid !== 1'b1 || result_c !== 32'd12)
            $fatal(1, "FAIL: First buffered result changed");

        $display("PASS: Two completed results buffered");
        $display("PASS: First result still equals 12");


        // =====================================
        // Test 3: Retrieve Both Buffered Results
        // =====================================

        // Allow the receiver to accept results.
        @(negedge clk);
        result_ready = 1'b1;

        #1;

        // Check the first result before accepting it.
        if (result_valid !== 1'b1 || result_c !== 32'd12)
            $fatal(1, "FAIL: First result should be 12");

        $display("PASS: First buffered result = 12");

        // Accept the first result.
        @(posedge clk);
        #1;

        // The second result should now be available.
        if (result_valid !== 1'b1 || result_c !== 32'd30)
            $fatal(1, "FAIL: Second result should be 30");

        $display("PASS: Second buffered result = 30");

        // Accept the second result.
        @(posedge clk);
        #1;

        // FIFO should now be empty.
        if (result_valid !== 1'b0)
            $fatal(1, "FAIL: Output FIFO not empty");

        if (dut.u_output_fifo.count !== 0)
            $fatal(1, "FAIL: Output FIFO count not zero");

        $display("PASS: Both buffered results accepted");
        $display("PASS: Output FIFO empty after draining");
        $display("Step 2.10D.7: Output buffering test PASSED");
        
        $finish;

    end


endmodule
