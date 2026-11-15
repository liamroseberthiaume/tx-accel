
`timescale 1ns/1ps

module tb_systolic_array_8x8;

    localparam int N = 8;
    localparam int DATA_WIDTH = 8;
    localparam int ACC_WIDTH = 32;
    localparam int DONE_CYCLE = 3*N - 2;

    logic clk = 0;
    logic rst_n;

    logic [N*DATA_WIDTH-1:0] a_in, b_in;
    logic valid_in, first_in, last_in;
    logic [N*N*ACC_WIDTH-1:0] c_out;
    logic done;

    logic signed [7:0] A [0:N-1][0:N-1];
    logic signed [7:0] B [0:N-1][0:N-1];

    integer r, c, k, cycle;
    integer expected, actual;
    integer checks_passed;

    systolic_array #(
        .N(N)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .a_in(a_in),
        .b_in(b_in),
        .valid_in(valid_in),
        .first_in(first_in),
        .last_in(last_in),
        .c_out(c_out),
        .done(done)
    );

    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        a_in = '0;
        b_in = '0;
        valid_in = 0;
        first_in = 0;
        last_in = 0;
        checks_passed = 0;

        // Generate deterministic signed test matrices.
        // Values are within the signed INT8 range.
        for (r = 0; r < N; r = r + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                A[r][c] = ((r*17 + c*11 + 3) % 61) - 30;
                B[r][c] = ((r*13 + c*19 + 7) % 67) - 33;
            end
        end

        $display("Starting 8x8 systolic array test...");

        repeat (2) @(negedge clk);
        rst_n = 1;

        // Feed eight valid input cycles.
        for (k = 0; k < N; k = k + 1) begin
            @(negedge clk);

            for (r = 0; r < N; r = r + 1)
                a_in[r*8 +: 8] = A[r][k];

            for (c = 0; c < N; c = c + 1)
                b_in[c*8 +: 8] = B[k][c];

            valid_in = 1;
            first_in = (k == 0);
            last_in = (k == N-1);

            @(posedge clk);
            #1;

            if (done !== 1'b0)
                $fatal(1, "8x8 done asserted too early");
        end

        // Flush the pipeline and check done timing.
        for (cycle = N+1; cycle <= DONE_CYCLE+1;
             cycle = cycle + 1) begin

            @(negedge clk);

            a_in = '0;
            b_in = '0;
            valid_in = 0;
            first_in = 0;
            last_in = 0;

            @(posedge clk);
            #1;

            if (done !== (cycle == DONE_CYCLE))
                $fatal(1,
                    "8x8 done timing FAILED at cycle %0d",
                    cycle);

            $display("Cycle %0d: done=%0b PASSED",
                     cycle, done);

            // Check every output when computation completes.
            if (cycle == DONE_CYCLE) begin

                for (r = 0; r < N; r = r + 1) begin
                    for (c = 0; c < N; c = c + 1) begin

                        expected = 0;

                        for (k = 0; k < N; k = k + 1)
                            expected = expected
                                + A[r][k] * B[k][c];

                        actual = $signed(
                            c_out[(r*N+c)*32 +: 32]
                        );

                        if (actual !== expected)
                            $fatal(1,
                                "C[%0d][%0d] FAILED: got %0d, expected %0d",
                                r, c, actual, expected);

                        checks_passed = checks_passed + 1;
                    end
                end

                $display("All %0d matrix outputs PASSED",
                         checks_passed);
            end
        end

        $display("ALL 8x8 SYSTOLIC ARRAY TESTS PASSED");
        $finish;
    end

endmodule
