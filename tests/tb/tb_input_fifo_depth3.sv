
`timescale 1ns/1ps

module tb_input_fifo_depth3;

    localparam int N = 2;
    localparam int DATA_WIDTH = 8;
    localparam int DEPTH = 3;

    logic clk = 0;
    logic rst_n;

    // Input interface
    logic [N*DATA_WIDTH-1:0] in_a, in_b;
    logic in_first, in_last;
    logic in_valid, in_ready;

    // Output interface
    logic [N*DATA_WIDTH-1:0] out_a, out_b;
    logic out_first, out_last;
    logic out_valid, out_ready;

    // Instantiate FIFO with three storage locations
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

        $display("Starting DEPTH=3 FIFO tests...");

        
        // =====================================
        // TEST 1: DEPTH=3 FIFO Wraparound
        // =====================================

        for (int round = 0; round < 2; round = round + 1) begin

            $display("Starting DEPTH=3 round %0d...", round + 1);

            // Fill all three locations
            for (int i = 0; i < DEPTH; i = i + 1) begin

                @(negedge clk);

                out_ready = 0;
                in_valid = 1;

                in_a = 16'h1000 + round*DEPTH + i;
                in_b = 16'h2000 + round*DEPTH + i;

                in_first = (i == 0);
                in_last = (i == DEPTH-1);

                #1;

                if (in_ready !== 1'b1)
                    $fatal(1, "FIFO not ready during fill");

                @(posedge clk);
                #1;
            end

            // The FIFO should now be full
            if (in_ready !== 1'b0)
                $fatal(1, "DEPTH=3 FIFO not full");

            if (out_valid !== 1'b1)
                $fatal(1, "DEPTH=3 output not valid");

            $display("Round %0d: FIFO full PASSED", round + 1);

            // Read back all three packets in order
            for (int i = 0; i < DEPTH; i = i + 1) begin

                @(negedge clk);

                in_valid = 0;
                out_ready = 1;

                #1;

                if (out_valid !== 1'b1)
                    $fatal(1, "Missing packet %0d", i);

                if (out_a !== (16'h1000 + round*DEPTH + i))
                    $fatal(1, "A data mismatch at packet %0d", i);

                if (out_b !== (16'h2000 + round*DEPTH + i))
                    $fatal(1, "B data mismatch at packet %0d", i);

                if (out_first !== (i == 0))
                    $fatal(1, "First flag mismatch");

                if (out_last !== (i == DEPTH-1))
                    $fatal(1, "Last flag mismatch");

                @(posedge clk);
                #1;
            end

            // All three packets must be removed
            if (out_valid !== 1'b0)
                $fatal(1, "FIFO not empty after drain");

            if (in_ready !== 1'b1)
                $fatal(1, "FIFO not ready after drain");

            $display("Round %0d: Ordering and wraparound PASSED",
                     round + 1);
        end

        $display("ALL DEPTH=3 FIFO TESTS PASSED");


        $finish;
    end

endmodule
