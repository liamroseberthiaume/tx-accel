
`timescale 1ns/1ps

module tb_systolic_array_1x1;

    // Clock and reset
    logic clk;
    logic rst_n;

    // One 8-bit A input and one 8-bit B input
    logic [7:0] a_in;
    logic [7:0] b_in;

    // Control signals
    logic valid_in;
    logic first_in;
    logic last_in;

    // One 32-bit result
    logic [31:0] c_out;
    logic done;

    // Instantiate the 1x1 systolic array
    systolic_array #(
        .N(1)
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

    // Clock changes every 5 ns
    always #5 clk = ~clk;

    initial begin
        // Initialize inputs
        clk = 0;
        rst_n = 0;
        a_in = 0;
        b_in = 0;
        valid_in = 0;
        first_in = 0;
        last_in = 0;

        $display("Starting 1x1 systolic array test...");

        // Hold reset for two clock cycles
        repeat (2) @(negedge clk);
        rst_n = 1;

        // TEST 1: Multiply 3 by -4
        @(negedge clk);
        a_in = 8'sd3;
        b_in = -8'sd4;

        valid_in = 1;
        first_in = 1;
        last_in = 1;

        // Check output after the first rising edge
        @(posedge clk);
        #1;

        if ($signed(c_out) !== -32'sd12)
            $fatal(1, "1x1 multiplication FAILED");

        if (done !== 1'b1)
            $fatal(1, "1x1 done signal FAILED");

        $display("Multiplication PASSED: 3 * -4 = %0d",
                 $signed(c_out));

        // TEST 2: Invalid data should not update result
        @(negedge clk);
        a_in = 0;
        b_in = 0;
        valid_in = 0;
        first_in = 0;
        last_in = 0;

        @(posedge clk);
        #1;

        if ($signed(c_out) !== -32'sd12)
            $fatal(1, "1x1 accumulator hold FAILED");

        if (done !== 1'b0)
            $fatal(1, "1x1 done clear FAILED");

        $display("Accumulator hold PASSED");
        $display("Done signal PASSED");
        $display("ALL 1x1 SYSTOLIC ARRAY TESTS PASSED");

        $finish;
    end

endmodule
