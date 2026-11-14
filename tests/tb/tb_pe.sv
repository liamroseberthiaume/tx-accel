`timescale 1ns/1ps

module tb_pe;

    // =====================================
    // 1. Signal declarations
    // =====================================

    logic clk;
    logic rst_n;

    logic signed [7:0] a_in;
    logic signed [7:0] b_in;

    logic valid_in;
    logic first_in;
    logic last_in;

    logic signed [7:0] a_out;
    logic signed [7:0] b_out;

    logic valid_out;
    logic first_out;
    logic last_out;

    logic signed [31:0] acc_out;

    integer test_count = 0;


    // =====================================
    // 2. Instantiate our PE
    // =====================================

    pe dut (
        .clk(clk),
        .rst_n(rst_n),

        .a_in(a_in),
        .b_in(b_in),

        .valid_in(valid_in),
        .first_in(first_in),
        .last_in(last_in),

        .a_out(a_out),
        .b_out(b_out),

        .valid_out(valid_out),
        .first_out(first_out),
        .last_out(last_out),

        .acc_out(acc_out)
    );


    // =====================================
    // 3. Clock generation
    // =====================================

    initial clk = 0;

    always #5 clk = ~clk;


    // =====================================
    // 4. Reusable test task
    // =====================================

    task automatic run_case(
        input logic signed [7:0] next_a,
        input logic signed [7:0] next_b,
        input logic next_valid,
        input logic next_first,
        input logic next_last,
        input logic signed [31:0] expected_acc
    );

        begin

            @(negedge clk);

            a_in = next_a;
            b_in = next_b;

            valid_in = next_valid;
            first_in = next_first;
            last_in = next_last;

            @(posedge clk);
            #1;

            test_count = test_count + 1;

            // Check accumulator
            if (acc_out !== expected_acc) begin
                $fatal(1,
                    "Test %0d FAILED: expected %0d, got %0d",
                    test_count, expected_acc, acc_out);
            end

            // Check operand forwarding
            if (a_out !== next_a ||
                b_out !== next_b) begin
                $fatal(1,
                    "Test %0d FAILED: operand forwarding",
                    test_count);
            end

            // Check control forwarding
            if (valid_out !== next_valid ||
                first_out !== next_first ||
                last_out !== next_last) begin
                $fatal(1,
                    "Test %0d FAILED: control forwarding",
                    test_count);
            end

            $display(
                "Test %0d PASSED: accumulator = %0d",
                test_count, acc_out
            );

        end

    endtask


    // =====================================
    // 5. Main test sequence
    // =====================================

    initial begin

        // Initialize signals
        rst_n = 0;

        a_in = 0;
        b_in = 0;

        valid_in = 0;
        first_in = 0;
        last_in = 0;


        // Initial reset test
        repeat (2) @(posedge clk);
        #1;

        if (acc_out !== 32'sd0 ||
            a_out !== 8'sd0 ||
            b_out !== 8'sd0 ||
            valid_out !== 1'b0 ||
            first_out !== 1'b0 ||
            last_out !== 1'b0) begin

            $fatal(1, "Initial reset FAILED");

        end

        $display("Initial reset PASSED");


        // Release reset
        @(negedge clk);
        rst_n = 1;


        // Test 1: Start accumulation
        // 2 * 3 = 6
        run_case(2, 3, 1, 1, 0, 6);


        // Test 2: Continue accumulation
        // 6 + (4 * 5) = 26
        run_case(4, 5, 1, 0, 0, 26);


        // Test 3: Invalid cycle
        // Accumulator stays 26
        run_case(9, 9, 0, 0, 0, 26);


        // Test 4: Negative multiplication
        // 26 + (-1 * 7) = 19
        run_case(-1, 7, 1, 0, 1, 19);


        // Test 5: Signed extremes
        // (-128) * (-128) = 16384
        run_case(8'sh80, 8'sh80, 1, 1, 0, 16384);


        // Test 6: Signed accumulation
        // 16384 + (127 * -128) = 128
        run_case(8'sh7f, 8'sh80, 1, 0, 1, 128);


        // Test 7: Negative result
        // (-128) * 127 = -16256
        run_case(8'sh80, 8'sh7f, 1, 1, 1, -16256);


        // Test 8: Invalid first/last flags
        // Accumulator stays -16256
        run_case(5, 5, 0, 1, 1, -16256);


        // Test 9: Zero multiplication
        run_case(0, 4, 1, 1, 0, 0);


        // Test 10: Negative accumulation
        // 0 + (2 * -3) = -6
        run_case(2, -3, 1, 0, 1, -6);


        // =====================================
        // 6. Final reset test
        // =====================================

        @(negedge clk);
        rst_n = 0;
        #1;

        if (acc_out !== 32'sd0 ||
            a_out !== 8'sd0 ||
            b_out !== 8'sd0 ||
            valid_out !== 1'b0 ||
            first_out !== 1'b0 ||
            last_out !== 1'b0) begin

            $fatal(1, "Final reset FAILED");

        end

        $display("Final reset PASSED");


        // =====================================
        // 7. Results
        // =====================================

        $display("");
        $display("==============================");
        $display("All %0d PE tests PASSED!", test_count);
        $display("==============================");

        $finish;

    end

endmodule