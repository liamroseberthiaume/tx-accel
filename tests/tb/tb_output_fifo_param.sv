
`timescale 1ns/1ps

module tb_output_fifo_param #(
    parameter int DEPTH = 3
);

    localparam int N = 2;
    localparam int ACC_WIDTH = 32;
    localparam int RESULT_WIDTH = N*N*ACC_WIDTH;

    logic clk = 0;
    logic rst_n;

    logic [RESULT_WIDTH-1:0] in_data;
    logic in_valid;
    logic in_ready;

    logic [RESULT_WIDTH-1:0] out_data;
    logic out_valid;
    logic out_ready;

    always #5 clk = ~clk;

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

    initial begin

        rst_n = 0;
        in_data = '0;
        in_valid = 0;
        out_ready = 0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1;

        #1;

        if (out_valid !== 1'b0 || in_ready !== 1'b1)
            $fatal(1, "FAIL: Reset, DEPTH=%0d", DEPTH);

        // Repeat twice to test pointer reuse/wraparound.
        for (int round = 0; round < 2; round++) begin

            // Fill every FIFO slot.
            for (int i = 0; i < DEPTH; i++) begin

                @(negedge clk);
                in_valid = 1'b1;
                out_ready = 1'b0;

                in_data = {
                    32'(round*100+i+4),
                    32'(round*100+i+3),
                    32'(round*100+i+2),
                    32'(round*100+i+1)
                };

                #1;

                if (in_ready !== 1'b1)
                    $fatal(1, "FAIL: Write rejected");

                @(posedge clk);
                #1;
            end

            @(negedge clk);
            in_valid = 1'b0;
            #1;

            // FIFO should be completely full.
            if (in_ready !== 1'b0)
                $fatal(1, "FAIL: FIFO not full");

            // Drain every slot and check the data.
            for (int i = 0; i < DEPTH; i++) begin

                @(negedge clk);
                out_ready = 1'b1;
                #1;

                if (out_valid !== 1'b1)
                    $fatal(1, "FAIL: Missing result");

                if (out_data !== {
                    32'(round*100+i+4),
                    32'(round*100+i+3),
                    32'(round*100+i+2),
                    32'(round*100+i+1)
                })
                    $fatal(1, "FAIL: Incorrect result");

                @(posedge clk);
                #1;
            end

            @(negedge clk);
            out_ready = 1'b0;
            #1;

            if (out_valid !== 1'b0 || in_ready !== 1'b1)
                $fatal(1, "FAIL: FIFO not empty");

            $display("PASS: DEPTH=%0d, round=%0d",
                     DEPTH, round+1);
        end

        $display("Output FIFO parameter test PASSED");
        $finish;

    end

endmodule
