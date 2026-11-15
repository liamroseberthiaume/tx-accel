
`timescale 1ns/1ps

module tb_systolic_array;

    // ========================================
    // 1. Parameters
    // ========================================

    localparam int N = 2;
    localparam int DATA_WIDTH = 8;
    localparam int ACC_WIDTH = 32;

    // ========================================
    // 2. Signals
    // ========================================

    logic clk = 0;
    logic rst_n = 0;

    logic [N*DATA_WIDTH-1:0] a_in = '0;
    logic [N*DATA_WIDTH-1:0] b_in = '0;

    logic valid_in = 0;
    logic first_in = 0;
    logic last_in = 0;

    logic [N*N*ACC_WIDTH-1:0] c_out;
    logic done;

    // ========================================
    // 3. Instantiate the systolic array
    // ========================================

    systolic_array #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
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

    // ========================================
    // 4. Generate a 10 ns clock
    // ========================================

    always #5 clk = ~clk;

    // ========================================
    // 5. Check the done signal
    // ========================================

    task automatic check_done(
        input int cycle_number,
        input logic expected_done
    );

        if (done !== expected_done) begin
            $fatal(1,
                "Cycle %0d: expected done=%b, got %b",
                cycle_number, expected_done, done);
        end

        $display("Cycle %0d: done=%b PASSED",
                 cycle_number, done);

    endtask

    // ========================================
    // 6. Main test sequence
    // ========================================

    initial begin

        // Allow reset to initialize the array
        repeat (2) @(posedge clk);
        #1;

        if (c_out !== '0 || done !== 1'b0)
            $fatal(1, "Initial reset FAILED");

        $display("Initial reset PASSED");

        // ====================================
        // Input cycle 1: k = 0
        // A column 0 = [1, 3]
        // B row 0 = [5, 6]
        // ====================================

        @(negedge clk);

        rst_n = 1;

        a_in = {8'd3, 8'd1};
        b_in = {8'd6, 8'd5};

        valid_in = 1;
        first_in = 1;
        last_in = 0;

        @(posedge clk);
        #1;
        check_done(1, 0);

        // ====================================
        // Input cycle 2: k = 1
        // A column 1 = [2, 4]
        // B row 1 = [7, 8]
        // ====================================

        @(negedge clk);

        a_in = {8'd4, 8'd2};
        b_in = {8'd8, 8'd7};

        valid_in = 1;
        first_in = 0;
        last_in = 1;

        @(posedge clk);
        #1;
        check_done(2, 0);

        // ====================================
        // Cycle 3: No new inputs
        // Existing data continues propagating
        // ====================================

        @(negedge clk);

        a_in = '0;
        b_in = '0;

        valid_in = 0;
        first_in = 0;
        last_in = 0;

        @(posedge clk);
        #1;
        check_done(3, 0);

        // ====================================
        // Cycle 4: Final result arrives
        // ====================================

        @(posedge clk);
        #1;
        check_done(4, 1);

        // ====================================
        // 7. Verify matrix results
        // ====================================

        if (c_out[31:0] !== 32'd19)
            $fatal(1, "C[0][0] FAILED");

        if (c_out[63:32] !== 32'd22)
            $fatal(1, "C[0][1] FAILED");

        if (c_out[95:64] !== 32'd43)
            $fatal(1, "C[1][0] FAILED");

        if (c_out[127:96] !== 32'd50)
            $fatal(1, "C[1][1] FAILED");

        $display("Matrix multiplication PASSED!");

        $display("C = [[%0d, %0d], [%0d, %0d]]",
            $signed(c_out[31:0]),
            $signed(c_out[63:32]),
            $signed(c_out[95:64]),
            $signed(c_out[127:96]));

        // ====================================
        // 8. Check done returns to zero
        // ====================================

        @(posedge clk);
        #1;
        check_done(5, 0);

        
    // =========================================
    // TEST 2: Signed matrix multiplication
    // =========================================

    $display("Starting signed matrix test...");

    // A = [[-1, 2], [3, -4]]
    // B = [[5, -6], [-7, 8]]
    // Expected C = [[-19, 22], [43, -50]]

    // Cycle 1: First pair of operands
    @(negedge clk);

    a_in = {8'sd3, -8'sd1};
    b_in = {-8'sd6, 8'sd5};

    valid_in = 1;
    first_in = 1;
    last_in = 0;

    @(posedge clk);
    #1;
    check_done(1, 0);

    // Cycle 2: Second pair of operands
    @(negedge clk);

    a_in = {-8'sd4, 8'sd2};
    b_in = {8'sd8, -8'sd7};

    valid_in = 1;
    first_in = 0;
    last_in = 1;

    @(posedge clk);
    #1;
    check_done(2, 0);

    // Cycle 3: Stop providing new data
    @(negedge clk);

    a_in = '0;
    b_in = '0;

    valid_in = 0;
    first_in = 0;
    last_in = 0;

    @(posedge clk);
    #1;
    check_done(3, 0);

    // Cycle 4: Final results should be ready
    @(posedge clk);
    #1;
    check_done(4, 1);

    // Verify all four signed outputs
    if (c_out[31:0] !== -32'sd19)
        $fatal(1, "Signed C[0][0] FAILED");

    if (c_out[63:32] !== 32'sd22)
        $fatal(1, "Signed C[0][1] FAILED");

    if (c_out[95:64] !== 32'sd43)
        $fatal(1, "Signed C[1][0] FAILED");

    if (c_out[127:96] !== -32'sd50)
        $fatal(1, "Signed C[1][1] FAILED");

    $display("Signed matrix multiplication PASSED!");
    $display("C = [[%0d, %0d], [%0d, %0d]]",
             $signed(c_out[31:0]),
             $signed(c_out[63:32]),
             $signed(c_out[95:64]),
             $signed(c_out[127:96]));

    // Cycle 5: Completion signal should clear
    @(posedge clk);
    #1;
    check_done(5, 0);

    // =========================================
    // TEST 3: Idle cycle between valid inputs
    // =========================================
    $display("Starting idle-cycle test...");

    // A = [[1, 2], [3, 4]]
    // B = [[5, 6], [7, 8]]
    // Expected C = [[19, 22], [43, 50]]

    // Cycle 1: First valid operands
    @(negedge clk);
    a_in = {8'd3, 8'd1};
    b_in = {8'd6, 8'd5};
    valid_in = 1;
    first_in = 1;
    last_in = 0;

    @(posedge clk);
    #1;
    check_done(1, 0);

    // Cycle 2: Insert an idle bubble
    @(negedge clk);
    a_in = '0;
    b_in = '0;
    valid_in = 0;
    first_in = 0;
    last_in = 0;

    @(posedge clk);
    #1;
    check_done(2, 0);

    // Cycle 3: Resume with final valid operands
    @(negedge clk);
    a_in = {8'd4, 8'd2};
    b_in = {8'd8, 8'd7};
    valid_in = 1;
    first_in = 0;
    last_in = 1;

    @(posedge clk);
    #1;
    check_done(3, 0);

    // Cycle 4: Stop supplying valid data
    @(negedge clk);
    a_in = '0;
    b_in = '0;
    valid_in = 0;
    first_in = 0;
    last_in = 0;

    @(posedge clk);
    #1;
    check_done(4, 0);

    // Cycle 5: All results should be ready
    @(posedge clk);
    #1;
    check_done(5, 1);

    if (c_out[31:0] !== 32'd19)
        $fatal(1, "Idle test C[0][0] FAILED");

    if (c_out[63:32] !== 32'd22)
        $fatal(1, "Idle test C[0][1] FAILED");

    if (c_out[95:64] !== 32'd43)
        $fatal(1, "Idle test C[1][0] FAILED");

    if (c_out[127:96] !== 32'd50)
        $fatal(1, "Idle test C[1][1] FAILED");

    $display("Idle-cycle matrix multiplication PASSED!");
    $display("C = [[%0d, %0d], [%0d, %0d]]",
             $signed(c_out[31:0]),
             $signed(c_out[63:32]),
             $signed(c_out[95:64]),
             $signed(c_out[127:96]));

    // Cycle 6: Done should clear
    @(posedge clk);
    #1;
    check_done(6, 0);

    // =========================================
    // TEST 4: Signed INT8 boundary values
    // =========================================
    $display("Starting INT8 boundary test...");

    // A = [[-128, 127], [127, -128]]
    // B = [[-128, 127], [127, -128]]
    // Expected C = [[32513, -32512],
    //               [-32512, 32513]]

    // 8'sh80 represents -128 in signed INT8.

    // Cycle 1: First operands
    @(negedge clk);
    a_in = {8'sd127, 8'sh80};
    b_in = {8'sd127, 8'sh80};
    valid_in = 1;
    first_in = 1;
    last_in = 0;

    @(posedge clk);
    #1;
    check_done(1, 0);

    // Cycle 2: Final operands
    @(negedge clk);
    a_in = {8'sh80, 8'sd127};
    b_in = {8'sh80, 8'sd127};
    valid_in = 1;
    first_in = 0;
    last_in = 1;

    @(posedge clk);
    #1;
    check_done(2, 0);

    // Cycle 3: Stop supplying valid data
    @(negedge clk);
    a_in = '0;
    b_in = '0;
    valid_in = 0;
    first_in = 0;
    last_in = 0;

    @(posedge clk);
    #1;
    check_done(3, 0);

    // Cycle 4: Results should be ready
    @(posedge clk);
    #1;
    check_done(4, 1);

    // Verify all four boundary-value results
    if (c_out[31:0] !== 32'sd32513)
        $fatal(1, "Boundary C[0][0] FAILED");

    if (c_out[63:32] !== -32'sd32512)
        $fatal(1, "Boundary C[0][1] FAILED");

    if (c_out[95:64] !== -32'sd32512)
        $fatal(1, "Boundary C[1][0] FAILED");

    if (c_out[127:96] !== 32'sd32513)
        $fatal(1, "Boundary C[1][1] FAILED");

    $display("INT8 boundary test PASSED!");
    $display("C = [[%0d, %0d], [%0d, %0d]]",
             $signed(c_out[31:0]),
             $signed(c_out[63:32]),
             $signed(c_out[95:64]),
             $signed(c_out[127:96]));

    // Cycle 5: Completion should clear
    @(posedge clk);
    #1;
    check_done(5, 0);




        $display("==============================");
        $display("ALL SYSTOLIC ARRAY TESTS PASSED");
        $display("==============================");

        $finish;

    end

endmodule
