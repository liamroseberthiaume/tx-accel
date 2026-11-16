
module tx_accel_top #(
    parameter int N = 2,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32,
    parameter int FIFO_DEPTH = 4
)(
    // =====================================
    // Clock and Reset
    // =====================================

    input logic clk,
    input logic rst_n,

    // =====================================
    // External Input Interface
    // =====================================

    input logic [N*DATA_WIDTH-1:0] in_a,
    input logic [N*DATA_WIDTH-1:0] in_b,

    input logic in_first,
    input logic in_last,
    input logic in_valid,

    output logic in_ready,

    // =====================================
    // External Result Interface
    // =====================================

    output logic [N*N*ACC_WIDTH-1:0] result_c,
    output logic result_valid,

    input logic result_ready
);

    
    // =====================================
    // FIFO to Controller Connections
    // =====================================

    logic [N*DATA_WIDTH-1:0] fifo_a;
    logic [N*DATA_WIDTH-1:0] fifo_b;

    logic fifo_first;
    logic fifo_last;
    logic fifo_valid;
    logic fifo_ready;

    // =====================================
    // Controller to Systolic Array
    // =====================================

    logic [N*DATA_WIDTH-1:0] array_a_in;
    logic [N*DATA_WIDTH-1:0] array_b_in;

    logic array_valid_in;
    logic array_first_in;
    logic array_last_in;

    // =====================================
    // Systolic Array to Controller
    // =====================================

    logic [N*N*ACC_WIDTH-1:0] array_c_out;
    logic array_done;


    // =====================================
    // Input FIFO Instance
    // =====================================

    input_fifo #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) u_input_fifo (

        // Clock and reset
        .clk(clk),
        .rst_n(rst_n),

        // External input connections
        .in_a(in_a),
        .in_b(in_b),
        .in_first(in_first),
        .in_last(in_last),
        .in_valid(in_valid),
        .in_ready(in_ready),

        // FIFO output connections
        .out_a(fifo_a),
        .out_b(fifo_b),
        .out_first(fifo_first),
        .out_last(fifo_last),
        .out_valid(fifo_valid),
        .out_ready(fifo_ready)

    );

    // =====================================
    // Array Controller Instance
    // =====================================

    array_controller #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_array_controller (

        // Clock and reset
        .clk(clk),
        .rst_n(rst_n),

        // FIFO to controller
        .fifo_a(fifo_a),
        .fifo_b(fifo_b),
        .fifo_first(fifo_first),
        .fifo_last(fifo_last),
        .fifo_valid(fifo_valid),
        .fifo_ready(fifo_ready),

        // Controller to systolic array
        .array_a_in(array_a_in),
        .array_b_in(array_b_in),
        .array_valid_in(array_valid_in),
        .array_first_in(array_first_in),
        .array_last_in(array_last_in),

        // Systolic array to controller
        .array_c_out(array_c_out),
        .array_done(array_done),

        // External result interface
        .result_c(result_c),
        .result_valid(result_valid),
        .result_ready(result_ready)

    );

    // =====================================
    // Systolic Array Instance
    // =====================================

    systolic_array #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_systolic_array (

        // Clock and reset
        .clk(clk),
        .rst_n(rst_n),

        // Operands from controller
        .a_in(array_a_in),
        .b_in(array_b_in),

        // Control signals from controller
        .valid_in(array_valid_in),
        .first_in(array_first_in),
        .last_in(array_last_in),

        // Results back to controller
        .c_out(array_c_out),
        .done(array_done)

    );


endmodule
