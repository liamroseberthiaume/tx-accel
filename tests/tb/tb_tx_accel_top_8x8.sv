
`timescale 1ns/1ps

module tb_tx_accel_top_8x8;

    localparam int N = 8;
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

    logic [N*DATA_WIDTH-1:0] in_a, in_b;
    logic in_first, in_last;
    logic in_valid, in_ready;

    logic [N*N*ACC_WIDTH-1:0] result_c;
    logic result_valid, result_ready;

    integer cycles;

    // Expected 8x8 matrix result
    logic [N*N*ACC_WIDTH-1:0] expected_c;

    // Temporary variable for reference calculation
    integer expected_sum;


    // 8x8 input matrices
    logic signed [DATA_WIDTH-1:0] A [0:N-1][0:N-1];
    logic signed [DATA_WIDTH-1:0] B [0:N-1][0:N-1];


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

        
        // =====================================
        // Generate 8x8 Test Matrices
        // =====================================

        // Reuse the deterministic signed INT8
        // values from our Milestone 1 test.

        for (int r = 0; r < N; r = r + 1) begin
            for (int c = 0; c < N; c = c + 1) begin

                A[r][c] = ((r*17 + c*11 + 3) % 61) - 30;
                B[r][c] = ((r*13 + c*19 + 7) % 67) - 33;

            end
        end


        // =====================================
        // Calculate Expected 8x8 Result
        // =====================================

        expected_c = '0;

        // Loop through each output row
        for (int r = 0; r < N; r = r + 1) begin

            // Loop through each output column
            for (int c = 0; c < N; c = c + 1) begin

                expected_sum = 0;

                // Multiply and accumulate
                for (int k = 0; k < N; k = k + 1) begin
                    expected_sum = expected_sum
                                 + $signed(A[r][k])
                                 * $signed(B[k][c]);
                end

                // Store the expected output
                expected_c[(r*N+c)*ACC_WIDTH +: ACC_WIDTH]
                    = expected_sum;

            end
        end


        repeat (2) @(negedge clk);
        rst_n = 1;

   
        // =====================================
        // Send Four Matrix Operand Packets
        // =====================================

        for (int k = 0; k < N; k = k + 1) begin

            @(negedge clk);

            // Pack column k of matrix A
            for (int r = 0; r < N; r = r + 1)
                in_a[r*DATA_WIDTH +: DATA_WIDTH] = A[r][k];

            // Pack row k of matrix B
            for (int c = 0; c < N; c = c + 1)
                in_b[c*DATA_WIDTH +: DATA_WIDTH] = B[k][c];

            // Set packet control flags
            in_first = (k == 0);
            in_last  = (k == N-1);
            in_valid = 1;

            #1;

            // Hold the packet until FIFO is ready
            while (in_ready !== 1'b1) begin
                @(negedge clk);
                #1;
            end

            // Packet accepted on rising edge
            @(posedge clk);

            $display("Packet %0d accepted", k + 1);

        end

        // Stop sending after the final packet
        @(negedge clk);

        in_valid = 0;
        in_first = 0;
        in_last  = 0;

        $display("All eight matrix packets sent");


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
        // Verify 8x8 Matrix Multiplication
        // =====================================

        // Compare every output element
        for (int r = 0; r < N; r = r + 1) begin
            for (int c = 0; c < N; c = c + 1) begin

                if (result_c[(r*N+c)*ACC_WIDTH +: ACC_WIDTH]
                    !== expected_c[(r*N+c)*ACC_WIDTH +: ACC_WIDTH]) begin

                    $fatal(1,
                        "FAIL: C[%0d][%0d] got %0d, expected %0d",
                        r, c,
                        $signed(result_c[(r*N+c)*ACC_WIDTH +: ACC_WIDTH]),
                        $signed(expected_c[(r*N+c)*ACC_WIDTH +: ACC_WIDTH])
                    );

                end

                $display(
                    "PASS: C[%0d][%0d] = %0d",
                    r, c,
                    $signed(result_c[(r*N+c)*ACC_WIDTH +: ACC_WIDTH])
                );

            end
        end

        $display("PASS: All 64 matrix elements verified");


        // =====================================
        // Verify Result Backpressure
        // =====================================

        repeat (3) begin
            @(negedge clk);

            if (result_valid !== 1'b1 ||
                result_c !== expected_c)
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
        $display("Step 2.8: 8x8 integration PASSED");

        $finish;
    end


endmodule
