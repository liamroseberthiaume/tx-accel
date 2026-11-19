
`timescale 1ns/1ps

module tb_tx_accel_tiling_4x4;

    localparam int N = 2;
    localparam int DATA_WIDTH = 8;
    localparam int ACC_WIDTH = 32;

    // =====================================
    // 4x4 Matrix Tiling Configuration
    // =====================================

    localparam int M = 4;

    // Complete 4x4 input matrices
    logic signed [DATA_WIDTH-1:0] matrix_a [0:M-1][0:M-1];
    logic signed [DATA_WIDTH-1:0] matrix_b [0:M-1][0:M-1];

    // Expected complete 4x4 result
    logic signed [ACC_WIDTH-1:0] expected_c [0:M-1][0:M-1];

    // Accumulates partial tile results from the accelerator
    logic signed [ACC_WIDTH-1:0] tiled_c [0:M-1][0:M-1];

    // Temporary 2x2 operand tiles
    logic signed [DATA_WIDTH-1:0] tile_a [0:N-1][0:N-1];
    logic signed [DATA_WIDTH-1:0] tile_b [0:N-1][0:N-1];

    // Expected matrix:
    // [19 22]
    // [43 50]
    localparam logic [127:0] EXPECTED = {
    32'hFFFF_FFFF, 32'd9,
    32'hFFFF_FFFB, 32'd21
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
        // Initialize 4x4 Input Matrices
        // =====================================

        for (int r = 0; r < M; r++) begin
            for (int c = 0; c < M; c++) begin

                matrix_a[r][c] = (r*4 + c + 1) - 8;

                matrix_b[r][c] =
                    ((r*3 + c*2) % 7) - 3;

            end
        end

        $display("PASS: 4x4 input matrices initialized");

        // =====================================
        // Calculate Expected 4x4 Result
        // =====================================

        for (int r = 0; r < M; r++) begin
            for (int c = 0; c < M; c++) begin

                // Accumulate the four products
                int signed sum;
                sum = 0;

                for (int k = 0; k < M; k++) begin
                    sum = sum
                        + $signed(matrix_a[r][k])
                        * $signed(matrix_b[k][c]);
                end

                expected_c[r][c] = sum;

            end
        end

        $display("PASS: Expected 4x4 result calculated");
        $display("Expected C[0][0] = %0d", expected_c[0][0]);

        // Initialize the tiled result accumulator to zero
        for (int r = 0; r < M; r++) begin
            for (int c = 0; c < M; c++) begin
                tiled_c[r][c] = 0;
            end
        end

        $display("PASS: 4x4 tiled result accumulator initialized");

        // =====================================
        // Extract First 2x2 Tiles: A00 and B00
        // =====================================

        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin

                tile_a[r][c] = matrix_a[r][c];
                tile_b[r][c] = matrix_b[r][c];

            end
        end

        $display("A00 = [%0d %0d; %0d %0d]",
            tile_a[0][0], tile_a[0][1],
            tile_a[1][0], tile_a[1][1]);

        $display("B00 = [%0d %0d; %0d %0d]",
            tile_b[0][0], tile_b[0][1],
            tile_b[1][0], tile_b[1][1]);

        // =====================================
        // Packet 1
        // =====================================

        @(negedge clk);

        // Packet 1: Column 0 of A00, Row 0 of B00
        in_a = {tile_a[1][0], tile_a[0][0]};
        in_b = {tile_b[0][1], tile_b[0][0]};


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

        // Packet 2: Column 1 of A00, Row 1 of B00
        in_a = {tile_a[1][1], tile_a[0][1]};
        in_b = {tile_b[1][1], tile_b[1][0]};


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
 
        $display("PASS: First 2x2 tile multiplication");

        // =====================================
        // Accumulate First Partial Tile Result
        // =====================================

        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin

                tiled_c[r][c] = tiled_c[r][c]
                    + $signed(result_c[
                        (r*N+c)*ACC_WIDTH +: ACC_WIDTH
                    ]);

            end
        end

        // Verify the first partial tile was stored
        if (tiled_c[0][0] !== 32'sd21 ||
            tiled_c[0][1] !== -32'sd5 ||
            tiled_c[1][0] !== 32'sd9 ||
            tiled_c[1][1] !== -32'sd1)
            $fatal(1, "FAIL: First partial tile accumulation");

        $display("PASS: First partial tile accumulated");

        $display("Tiled result = [%0d %0d; %0d %0d]",
            tiled_c[0][0], tiled_c[0][1],
            tiled_c[1][0], tiled_c[1][1]);

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

        // =====================================
        // Extract Second Tile Pair: A01 and B10
        // =====================================

        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin

                // Upper-right tile of A
                tile_a[r][c] = matrix_a[r][N+c];

                // Lower-left tile of B
                tile_b[r][c] = matrix_b[N+r][c];

            end
        end

        $display("A01 = [%0d %0d; %0d %0d]",
            tile_a[0][0], tile_a[0][1],
            tile_a[1][0], tile_a[1][1]);

        $display("B10 = [%0d %0d; %0d %0d]",
            tile_b[0][0], tile_b[0][1],
            tile_b[1][0], tile_b[1][1]);


        // =====================================
        // Second Partial Product: Packet 1
        // =====================================

        @(negedge clk);

        // Hold the next result until verification
        result_ready = 1'b0;

        // Column 0 of A01: [-5, -1]
        in_a = {tile_a[1][0], tile_a[0][0]};

        // Row 0 of B10: [3, -2]
        in_b = {tile_b[0][1], tile_b[0][0]};

        in_first = 1'b1;
        in_last = 1'b0;
        in_valid = 1'b1;

        #1;

        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: Second multiplication packet 1 not ready");

        // Accept the packet
        @(posedge clk);
        #1;

        $display("PASS: Second multiplication packet 1 accepted");

        // Stop sending until packet 2
        @(negedge clk);
        in_valid = 1'b0;
        in_first = 1'b0;
        in_last = 1'b0;


        // =====================================
        // Second Partial Product: Packet 2
        // =====================================

        @(negedge clk);

        // Column 1 of A01: [-4, 0]
        in_a = {tile_a[1][1], tile_a[0][1]};

        // Row 1 of B10: [-1, 1]
        in_b = {tile_b[1][1], tile_b[1][0]};

        in_first = 1'b0;
        in_last = 1'b1;
        in_valid = 1'b1;

        #1;

        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: Second multiplication packet 2 not ready");

        // Accept the second packet
        @(posedge clk);
        #1;

        $display("PASS: Second multiplication packet 2 accepted");

        // Stop sending after the second packet
        @(negedge clk);
        in_valid = 1'b0;
        in_first = 1'b0;
        in_last = 1'b0;

        $display("PASS: Both packets for second multiplication sent");


        // =====================================
        // Verify Second Partial Product
        // =====================================

        // Wait for the second multiplication result
        cycles = 0;

        while (result_valid !== 1'b1 && cycles < 80) begin
            @(negedge clk);
            cycles = cycles + 1;
        end

        if (result_valid !== 1'b1)
            $fatal(1, "FAIL: Second tile result timeout");

        // Expected partial result:
        // [-11   6]
        // [ -3   2]
        if (result_c !== {
            32'sd2, -32'sd3,
            32'sd6, -32'sd11
        })
            $fatal(1, "FAIL: Incorrect second partial product");

        $display("PASS: Second partial product verified");

        // =====================================
        // Accumulate Second Partial Product
        // =====================================

        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin

                tiled_c[r][c] = tiled_c[r][c]
                    + $signed(result_c[
                        (r*N+c)*ACC_WIDTH +: ACC_WIDTH
                    ]);

            end
        end

        // Expected completed upper-left tile:
        // [10 1]
        // [ 6 1]
        if (tiled_c[0][0] !== 32'sd10 ||
            tiled_c[0][1] !== 32'sd1 ||
            tiled_c[1][0] !== 32'sd6 ||
            tiled_c[1][1] !== 32'sd1)
            $fatal(1, "FAIL: Completed C00 tile incorrect");

        $display("PASS: Upper-left output tile completed");

        
        $display("C00 = [%0d %0d; %0d %0d]",
            tiled_c[0][0], tiled_c[0][1],
            tiled_c[1][0], tiled_c[1][1]);

        // =====================================
        // Accept Second Partial Result
        // =====================================

        @(negedge clk);
        result_ready = 1'b1;

        // Transfer result on the next rising edge
        @(posedge clk);
        #1;

        // Verify the output FIFO is empty
        if (result_valid !== 1'b0)
            $fatal(1, "FAIL: Second result not accepted");

        $display("PASS: Second partial result accepted");
        $display("PASS: Output FIFO empty");

        
        // Prepare for the next tile
        @(negedge clk);
        result_ready = 1'b0;

        // =====================================
        // Extract Tiles for Upper-Right C01
        // =====================================

        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin

                // Upper-left tile of A
                tile_a[r][c] = matrix_a[r][c];

                // Upper-right tile of B
                tile_b[r][c] = matrix_b[r][N+c];

            end
        end

        $display("C01 Tile A00 = [%0d %0d; %0d %0d]",
            tile_a[0][0], tile_a[0][1],
            tile_a[1][0], tile_a[1][1]);

        $display("C01 Tile B01 = [%0d %0d; %0d %0d]",
            tile_b[0][0], tile_b[0][1],
            tile_b[1][0], tile_b[1][1]);

        
        // =====================================
        // C01 First Partial Product: Packet 1
        // =====================================

        @(negedge clk);

        result_ready = 1'b0;

        // Column 0 of A00: [-7, -3]
        in_a = {tile_a[1][0], tile_a[0][0]};

        // Row 0 of B01: [1, 3]
        in_b = {tile_b[0][1], tile_b[0][0]};

        in_first = 1'b1;
        in_last = 1'b0;
        in_valid = 1'b1;

        #1;

        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: C01 packet 1 not ready");

        // Accept packet 1
        @(posedge clk);
        #1;

        $display("PASS: C01 packet 1 accepted");

        // Stop sending until packet 2
        @(negedge clk);
        in_valid = 1'b0;
        in_first = 1'b0;
        in_last = 1'b0;


        // =====================================
        // C01 First Partial Product: Packet 2
        // =====================================

        @(negedge clk);

        // Column 1 of A00: [-6, -2]
        in_a = {tile_a[1][1], tile_a[0][1]};

        // Row 1 of B01: [-3, -1]
        in_b = {tile_b[1][1], tile_b[1][0]};

        in_first = 1'b0;
        in_last = 1'b1;
        in_valid = 1'b1;

        #1;

        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: C01 packet 2 not ready");

        // Accept packet 2
        @(posedge clk);
        #1;

        $display("PASS: C01 packet 2 accepted");

        // Stop sending after packet 2
        @(negedge clk);
        in_valid = 1'b0;
        in_first = 1'b0;
        in_last = 1'b0;

        $display("PASS: Both C01 partial-product packets sent");

        
        // =====================================
        // Verify C01 First Partial Product
        // =====================================

        cycles = 0;

        // Wait for the accelerator result
        while (result_valid !== 1'b1 && cycles < 80) begin
            @(negedge clk);
            cycles = cycles + 1;
        end

        if (result_valid !== 1'b1)
            $fatal(1, "FAIL: C01 partial result timeout");

        // Expected:
        // [11 -15]
        // [ 3  -7]
        if (result_c !== {
            -32'sd7, 32'sd3,
            -32'sd15, 32'sd11
        }) begin
            $display("Received: %h", result_c);
            $fatal(1, "FAIL: Incorrect C01 partial product");
        end

        $display("PASS: C01 first partial product verified");

        
        // =====================================
        // Accumulate First C01 Partial Product
        // =====================================

        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin

                // Store in columns 2 and 3
                tiled_c[r][N+c] = tiled_c[r][N+c]
                    + $signed(result_c[
                        (r*N+c)*ACC_WIDTH +: ACC_WIDTH
                    ]);

            end
        end

        // Verify partial C01 result
        if (tiled_c[0][2] !== 32'sd11 ||
            tiled_c[0][3] !== -32'sd15 ||
            tiled_c[1][2] !== 32'sd3 ||
            tiled_c[1][3] !== -32'sd7)
            $fatal(1, "FAIL: First C01 accumulation incorrect");

        $display("PASS: First C01 partial result accumulated");

        $display("C01 partial = [%0d %0d; %0d %0d]",
            tiled_c[0][2], tiled_c[0][3],
            tiled_c[1][2], tiled_c[1][3]);

        
        // =====================================
        // Accept First C01 Partial Result
        // =====================================

        @(negedge clk);
        result_ready = 1'b1;

        // Accept result on the rising clock edge
        @(posedge clk);
        #1;

        // FIFO should now be empty
        if (result_valid !== 1'b0)
            $fatal(1, "FAIL: C01 partial result not accepted");

        $display("PASS: First C01 partial result accepted");
        $display("PASS: Output FIFO empty after C01 partial");

        // Prepare for the next multiplication
        @(negedge clk);
        result_ready = 1'b0;


        // =====================================
        // Extract Tiles A01 and B11
        // =====================================

        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin

                // Upper-right tile of A
                tile_a[r][c] = matrix_a[r][N+c];

                // Lower-right tile of B
                tile_b[r][c] = matrix_b[N+r][N+c];

            end
        end

        $display("C01 Tile A01 = [%0d %0d; %0d %0d]",
            tile_a[0][0], tile_a[0][1],
            tile_a[1][0], tile_a[1][1]);

        $display("C01 Tile B11 = [%0d %0d; %0d %0d]",
            tile_b[0][0], tile_b[0][1],
            tile_b[1][0], tile_b[1][1]);

        
        // =====================================
        // C01 Second Partial Product: Packet 1
        // =====================================

        @(negedge clk);

        result_ready = 1'b0;

        // Column 0 of A01: [-5, -1]
        in_a = {tile_a[1][0], tile_a[0][0]};

        // Row 0 of B11: [0, 2]
        in_b = {tile_b[0][1], tile_b[0][0]};

        in_first = 1'b1;
        in_last = 1'b0;
        in_valid = 1'b1;

        #1;

        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: C01 second product packet 1 not ready");

        // Accept packet 1
        @(posedge clk);
        #1;

        $display("PASS: C01 second product packet 1 accepted");

        // Stop sending until packet 2
        @(negedge clk);
        in_valid = 1'b0;
        in_first = 1'b0;
        in_last = 1'b0;

        
        // =====================================
        // C01 Second Partial Product: Packet 2
        // =====================================

        @(negedge clk);

        // Column 1 of A01: [-4, 0]
        in_a = {tile_a[1][1], tile_a[0][1]};

        // Row 1 of B11: [3, -2]
        in_b = {tile_b[1][1], tile_b[1][0]};

        in_first = 1'b0;
        in_last = 1'b1;
        in_valid = 1'b1;

        #1;

        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: C01 second product packet 2 not ready");

        // Accept packet 2
        @(posedge clk);
        #1;

        $display("PASS: C01 second product packet 2 accepted");

        // Stop sending after packet 2
        @(negedge clk);
        in_valid = 1'b0;
        in_first = 1'b0;
        in_last = 1'b0;

        $display("PASS: Both C01 second-product packets sent");

        
        // =====================================
        // Verify C01 Second Partial Product
        // =====================================

        cycles = 0;

        // Wait for the result to become available
        while (result_valid !== 1'b1 && cycles < 80) begin
            @(negedge clk);
            cycles = cycles + 1;
        end

        if (result_valid !== 1'b1)
            $fatal(1, "FAIL: C01 second partial result timeout");

        // Expected result:
        // [-12 -2]
        // [  0 -2]
        if (result_c !== {
            -32'sd2, 32'sd0,
            -32'sd2, -32'sd12
        }) begin
            $display("Received: %h", result_c);
            $fatal(1, "FAIL: Incorrect C01 second partial product");
        end

        $display("PASS: C01 second partial product verified");

        
        // =====================================
        // Complete Upper-Right Tile C01
        // =====================================

        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin

                // Accumulate in columns 2 and 3
                tiled_c[r][N+c] = tiled_c[r][N+c]
                    + $signed(result_c[
                        (r*N+c)*ACC_WIDTH +: ACC_WIDTH
                    ]);

            end
        end

        // Verify completed upper-right tile
        if (tiled_c[0][2] !== -32'sd1 ||
            tiled_c[0][3] !== -32'sd17 ||
            tiled_c[1][2] !== 32'sd3 ||
            tiled_c[1][3] !== -32'sd9)
            $fatal(1, "FAIL: Completed C01 tile incorrect");

        // Compare against the full 4x4 reference
        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < M; c++) begin
                if (tiled_c[r][c] !== expected_c[r][c])
                    $fatal(1,
                        "FAIL: Top-half result [%0d][%0d]",
                        r, c);
            end
        end

        $display("PASS: Upper-right output tile completed");
        $display("PASS: Top half matches expected 4x4 result");

        $display("C01 = [%0d %0d; %0d %0d]",
            tiled_c[0][2], tiled_c[0][3],
            tiled_c[1][2], tiled_c[1][3]);

        
        // =====================================
        // Accept Completed C01 Result
        // =====================================

        @(negedge clk);
        result_ready = 1'b1;

        // Accept the result on the next rising edge
        @(posedge clk);
        #1;

        if (result_valid !== 1'b0)
            $fatal(1, "FAIL: C01 result not accepted");

        $display("PASS: Completed C01 result accepted");
        $display("PASS: Output FIFO empty after C01");

        // Prepare for the next tile
        @(negedge clk);
        result_ready = 1'b0;

        $finish;

    end

endmodule
