
`timescale 1ns/1ps

module tb_output_fifo;

    // =====================================
    // Test Configuration
    // =====================================

    localparam int N = 2;
    localparam int ACC_WIDTH = 32;
    localparam int DEPTH = 4;
    localparam int RESULT_WIDTH = N*N*ACC_WIDTH;

    // =====================================
    // Testbench Signals
    // =====================================

    logic clk = 0;
    logic rst_n;

    logic [RESULT_WIDTH-1:0] in_data;
    logic in_valid;
    logic in_ready;

    logic [RESULT_WIDTH-1:0] out_data;
    logic out_valid;
    logic out_ready;

    // Clock with a 10 ns period
    always #5 clk = ~clk;

    // =====================================
    // Device Under Test
    // =====================================

    output_fifo #(
        .N(N),
        .ACC_WIDTH(ACC_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(in_data),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .out_data(out_data),
        .out_valid(out_valid),
        .out_ready(out_ready)
    );

    // =====================================
    // Test 1: Reset
    // =====================================

    initial begin

        rst_n = 0;
        in_data = '0;
        in_valid = 0;
        out_ready = 0;

        // Hold reset for two clock cycles
        repeat (2) @(posedge clk);

        // Release reset
        @(negedge clk);
        rst_n = 1;

        #1;

        // FIFO must be empty
        if (out_valid !== 1'b0)
            $fatal(1, "FAIL: FIFO not empty after reset");

        // FIFO must be ready for incoming data
        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: FIFO not ready after reset");

        $display("PASS: FIFO empty and ready after reset");

        
        // =====================================
        // Test 2: Write and Read One Matrix
        // =====================================

        // Present a completed 2x2 matrix
        @(negedge clk);
        in_data = 128'h00000004_00000003_00000002_00000001;
        in_valid = 1'b1;
        out_ready = 1'b0;

        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: FIFO not ready for first write");

        // Write the matrix on the rising clock edge
        @(posedge clk);
        #1;

        // Check that the matrix is stored
        if (out_valid !== 1'b1)
            $fatal(1, "FAIL: FIFO did not become valid");

        if (out_data !== in_data)
            $fatal(1, "FAIL: Stored matrix does not match input");

        $display("PASS: Matrix successfully stored");

        // Stop writing and allow the receiver to read
        @(negedge clk);
        in_valid = 1'b0;
        out_ready = 1'b1;

        // Read the matrix on the next rising edge
        @(posedge clk);
        #1;

        // The FIFO should now be empty
        if (out_valid !== 1'b0)
            $fatal(1, "FAIL: FIFO not empty after reading");

        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: FIFO not ready after reading");

        $display("PASS: Matrix successfully read");
        $display("Step 2.10B.2: Single matrix test PASSED");
        
        // =====================================
        // Test 3: Multiple Matrices in FIFO Order
        // =====================================

        // Write three different matrices
        // without reading any of them.
        for (int i = 1; i <= 3; i++) begin

            @(negedge clk);
            out_ready = 1'b0;
            in_valid = 1'b1;

            in_data = {
                32'(4*i),
                32'(3*i),
                32'(2*i),
                32'(i)
            };

            if (in_ready !== 1'b1)
                $fatal(1, "FAIL: FIFO rejected matrix %0d", i);

            @(posedge clk);
            #1;

        end

        @(negedge clk);
        in_valid = 1'b0;

        $display("PASS: Three matrices stored");

        // Read the three matrices in FIFO order.
        for (int i = 1; i <= 3; i++) begin

            @(negedge clk);
            out_ready = 1'b1;

            if (out_valid !== 1'b1)
                $fatal(1, "FAIL: Missing matrix %0d", i);

            if (out_data !== {
                32'(4*i),
                32'(3*i),
                32'(2*i),
                32'(i)
            })
                $fatal(1, "FAIL: Matrix %0d incorrect or out of order", i);

            @(posedge clk);
            #1;

        end

        // All three matrices should now be removed.
        if (out_valid !== 1'b0)
            $fatal(1, "FAIL: FIFO not empty after three reads");

        $display("PASS: All three matrices retrieved in order");
        $display("Step 2.10B.3: FIFO ordering test PASSED");

        
        // =====================================
        // Test 4: FIFO Full and Backpressure
        // =====================================

        // Fill all four FIFO locations.
        for (int i = 1; i <= DEPTH; i++) begin

            @(negedge clk);
            out_ready = 1'b0;
            in_valid = 1'b1;

            in_data = {
                32'(400+i),
                32'(300+i),
                32'(200+i),
                32'(100+i)
            };

            if (in_ready !== 1'b1)
                $fatal(1, "FAIL: FIFO rejected write %0d", i);

            @(posedge clk);
            #1;
        end

        // FIFO should now be completely full.
        @(negedge clk);
        in_valid = 1'b1;
        out_ready = 1'b0;

        // Attempt a fifth write.
        in_data = {4{32'd999}};

        #1;

        if (in_ready !== 1'b0)
            $fatal(1, "FAIL: FIFO ready while full");

        if (out_valid !== 1'b1)
            $fatal(1, "FAIL: Full FIFO has no valid output");

        // Keep the fifth write request active
        // for two clock cycles.
        repeat (2) begin
            @(posedge clk);
            #1;

            if (in_ready !== 1'b0)
                $fatal(1, "FAIL: FIFO accepted extra write");
        end

        $display("PASS: FIFO rejected fifth matrix");

        // Stop requesting the fifth write.
        @(negedge clk);
        in_valid = 1'b0;

        // Read all four matrices and verify
        // they were not overwritten.
        for (int i = 1; i <= DEPTH; i++) begin

            @(negedge clk);
            out_ready = 1'b1;

            if (out_valid !== 1'b1)
                $fatal(1, "FAIL: Missing matrix %0d", i);

            if (out_data !== {
                32'(400+i),
                32'(300+i),
                32'(200+i),
                32'(100+i)
            })
                $fatal(1, "FAIL: Matrix %0d corrupted", i);

            @(posedge clk);
            #1;
        end

        // Verify FIFO is empty again.
        if (out_valid !== 1'b0)
            $fatal(1, "FAIL: FIFO not empty after draining");

        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: FIFO not ready after draining");

        $display("PASS: All four matrices preserved");
        $display("PASS: FIFO recovered after becoming full");
        $display("Step 2.10B.4: FIFO full test PASSED");

        
        // =====================================
        // Test 5: Simultaneous Read and Write
        // =====================================

        // Fill the FIFO with four matrices.
        for (int i = 1; i <= DEPTH; i++) begin

            @(negedge clk);
            in_valid = 1'b1;
            out_ready = 1'b0;

            in_data = {
                32'(40+i),
                32'(30+i),
                32'(20+i),
                32'(10+i)
            };

            #1;

            if (in_ready !== 1'b1)
                $fatal(1, "FAIL: Could not fill FIFO");

            @(posedge clk);
            #1;
        end

        $display("PASS: FIFO filled for simultaneous transfer");

        // FIFO is full. Read Matrix 1 while
        // writing Matrix 5 on the same clock edge.
        @(negedge clk);

        in_valid = 1'b1;
        out_ready = 1'b1;

        in_data = {
            32'd45, 32'd35, 32'd25, 32'd15
        };

        #1;

        // Oldest matrix must still be Matrix 1.
        if (out_data !== {
            32'd41, 32'd31, 32'd21, 32'd11
        })
            $fatal(1, "FAIL: Incorrect oldest matrix");

        // Full FIFO must accept a new write
        // because a read is occurring.
        if (in_ready !== 1'b1)
            $fatal(1, "FAIL: FIFO rejected simultaneous write");

        if (out_valid !== 1'b1)
            $fatal(1, "FAIL: FIFO output not valid");

        // Both transfers occur together.
        @(posedge clk);
        #1;

        if (out_valid !== 1'b1)
            $fatal(1, "FAIL: FIFO unexpectedly empty");

        $display("PASS: Simultaneous read/write accepted");

        // Stop writing.
        @(negedge clk);
        in_valid = 1'b0;
        out_ready = 1'b0;

        #1;

        // FIFO should still be full.
        if (in_ready !== 1'b0)
            $fatal(1, "FAIL: FIFO occupancy incorrect");

        // Remaining reading order:
        // Matrix 2, Matrix 3, Matrix 4, Matrix 5.
        for (int i = 2; i <= DEPTH+1; i++) begin

            @(negedge clk);
            out_ready = 1'b1;

            #1;

            if (out_valid !== 1'b1)
                $fatal(1, "FAIL: Missing matrix %0d", i);

            if (out_data !== {
                32'(40+i),
                32'(30+i),
                32'(20+i),
                32'(10+i)
            })
                $fatal(1, "FAIL: Matrix %0d out of order", i);

            @(posedge clk);
            #1;
        end

        if (out_valid !== 1'b0)
            $fatal(1, "FAIL: FIFO not empty after draining");

        $display("PASS: Matrices 2-5 retrieved in order");
        $display("Step 2.10B.5: Simultaneous transfer test PASSED");

        $finish;

    end

endmodule
