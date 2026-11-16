
`timescale 1ns/1ps

module tb_tx_accel_top_2x2;

    localparam int N = 2;
    localparam int DATA_WIDTH = 8;
    localparam int ACC_WIDTH = 32;

    // Expected matrix:
    // [19 22]
    // [43 50]
    localparam logic [127:0] EXPECTED = {
        32'd50, 32'd43,
        32'd22, 32'd19
    };

    logic clk = 0;
    logic rst_n;

    logic [15:0] in_a, in_b;
    logic in_first, in_last;
    logic in_valid, in_ready;

    logic [127:0] result_c;
    logic result_valid, result_ready;

    integer cycles;

    // 10 ns clock period
    always #5 clk = ~clk;

    // =====================================
    // Accelerator Under Test
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

    initial begin

        // =====================================
        // Reset
        // =====================================

        rst_n = 0;
        in_a = 0;
        in_b = 0;
        in_first = 0;
        in_last = 0;
        in_valid = 0;
        result_ready = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;

        // =====================================
        // Packet 1
        // =====================================

        @(negedge clk);

        in_a = {8'd3, 8'd1};
        in_b = {8'd6, 8'd5};

        in_first = 1;
        in_last = 0;
        in_valid = 1;

        #1;

        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: FIFO not ready for packet 1");

        // =====================================
        // Packet 2
        // =====================================

        // Packet 1 is accepted at the
        // intervening rising clock edge.
        @(negedge clk);

        in_a = {8'd4, 8'd2};
        in_b = {8'd8, 8'd7};

        in_first = 0;
        in_last = 1;
        in_valid = 1;

        #1;

        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: FIFO not ready for packet 2");

        // Packet 2 is accepted at the
        // intervening rising clock edge.
        @(negedge clk);

        in_valid = 0;
        in_first = 0;
        in_last = 0;

        // =====================================
        // Wait for Result
        // =====================================

        cycles = 0;

        while (result_valid !== 1'b1 &&
               cycles < 40) begin
            @(negedge clk);
            cycles = cycles + 1;
        end

        if (result_valid !== 1'b1)
            $fatal(1, "FAIL: 2x2 result timeout");

        // =====================================
        // Verify Matrix Multiplication
        // =====================================

        if (result_c !== EXPECTED) begin

            $display("Expected: %h", EXPECTED);
            $display("Received: %h", result_c);

            $fatal(1, "FAIL: Incorrect 2x2 result");
        end

        $display("PASS: 2x2 matrix multiplication");
        $display("Result = [19 22; 43 50]");

        // =====================================
        // Verify Result Backpressure
        // =====================================

        repeat (3) begin
            @(negedge clk);

            if (result_valid !== 1'b1 ||
                result_c !== EXPECTED)
                $fatal(1, "FAIL: Result not held");
        end

        $display("PASS: Result backpressure");

        // =====================================
        // Accept Completed Result
        // =====================================

        result_ready = 1;

        @(posedge clk);
        #1;

        if (result_valid !== 1'b0)
            $fatal(1, "FAIL: Result not accepted");

        $display("PASS: Result accepted");
        $display("Step 2.6C.2 PASSED");

        $finish;
    end


endmodule
