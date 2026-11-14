`timescale 1ns/1ps

module tb_and_gate;

    logic a, b;
    logic y;

    // Connect our AND gate to the testbench
    and_gate dut (
        .a(a),
        .b(b),
        .y(y)
    );

    initial begin

        // Test 1: 0 AND 0 = 0
        a = 0;
        b = 0;
        #1;
        if (y !== 1'b0)
            $fatal(1, "Test 1 FAILED");

        // Test 2: 0 AND 1 = 0
        a = 0;
        b = 1;
        #1;
        if (y !== 1'b0)
            $fatal(1, "Test 2 FAILED");

        // Test 3: 1 AND 0 = 0
        a = 1;
        b = 0;
        #1;
        if (y !== 1'b0)
            $fatal(1, "Test 3 FAILED");

        // Test 4: 1 AND 1 = 1
        a = 1;
        b = 1;
        #1;
        if (y !== 1'b1)
            $fatal(1, "Test 4 FAILED");

        $display("All 4 AND gate tests PASSED!");

        $finish;

    end

endmodule