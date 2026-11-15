
`timescale 1ns/1ps

module tb_systolic_array_4x4;

    localparam int N = 4;

    logic clk = 0;
    logic rst_n;

    logic [N*8-1:0] a_in, b_in;
    logic valid_in, first_in, last_in;
    logic [N*N*32-1:0] c_out;
    logic done;

    // Matrices used to generate the test inputs
    logic signed [7:0] A [0:N-1][0:N-1];
    logic signed [7:0] B [0:N-1][0:N-1];

    integer r, c, k, cycle;
    integer expected, actual;

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

        // A = [[ 1,  2,  3,  4],
        //      [ 5,  6,  7,  8],
        //      [-1, -2, -3, -4],
        //      [ 9,  0, -5,  2]]

        A[0][0]=1;  A[0][1]=2;  A[0][2]=3;  A[0][3]=4;
        A[1][0]=5;  A[1][1]=6;  A[1][2]=7;  A[1][3]=8;
        A[2][0]=-1; A[2][1]=-2; A[2][2]=-3; A[2][3]=-4;
        A[3][0]=9;  A[3][1]=0;  A[3][2]=-5; A[3][3]=2;

        // B = [[ 2, -1,  0,  3],
        //      [ 4,  1, -2,  5],
        //      [-3,  2,  1, -1],
        //      [ 6,  0, -4,  2]]

        B[0][0]=2;  B[0][1]=-1; B[0][2]=0;  B[0][3]=3;
        B[1][0]=4;  B[1][1]=1;  B[1][2]=-2; B[1][3]=5;
        B[2][0]=-3; B[2][1]=2;  B[2][2]=1;  B[2][3]=-1;
        B[3][0]=6;  B[3][1]=0;  B[3][2]=-4; B[3][3]=2;

        $display("Starting 4x4 systolic array test...");

        repeat (2) @(negedge clk);
        rst_n = 1;

        // Supply four sets of matrix operands.
        for (k = 0; k < N; k = k + 1) begin
            @(negedge clk);

            // Send column k of A, one value per row.
            for (r = 0; r < N; r = r + 1)
                a_in[r*8 +: 8] = A[r][k];

            // Send row k of B, one value per column.
            for (c = 0; c < N; c = c + 1)
                b_in[c*8 +: 8] = B[k][c];

            valid_in = 1;
            first_in = (k == 0);
            last_in = (k == N-1);

            @(posedge clk);
            #1;

            if (done !== 1'b0)
                $fatal(1, "Done asserted too early");
        end

        // Allow the remaining data to move through the array.
        for (cycle = N+1; cycle <= 11; cycle = cycle + 1) begin
            @(negedge clk);

            a_in = '0;
            b_in = '0;
            valid_in = 0;
            first_in = 0;
            last_in = 0;

            @(posedge clk);
            #1;

            if (done !== (cycle == 10))
                $fatal(1,
                    "Done timing FAILED at cycle %0d", cycle);

            $display("Cycle %0d: done=%0b PASSED",
                     cycle, done);

            // Compare every output with a reference calculation.
            if (cycle == 10) begin
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

                        $display(
                            "C[%0d][%0d] = %0d PASSED",
                            r, c, actual
                        );
                    end
                end
            end
        end

        $display("ALL 4x4 SYSTOLIC ARRAY TESTS PASSED");
        $finish;
    end

endmodule
