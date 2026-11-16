
module array_controller #(
    parameter int N = 2,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32
)(
    // Clock and reset
    input logic clk,
    input logic rst_n,

    // =====================================
    // Input FIFO Interface
    // =====================================

    input logic [N*DATA_WIDTH-1:0] fifo_a,
    input logic [N*DATA_WIDTH-1:0] fifo_b,

    input logic fifo_first,
    input logic fifo_last,
    input logic fifo_valid,

    output logic fifo_ready,

    // =====================================
    // Systolic Array Interface
    // =====================================

    output logic [N*DATA_WIDTH-1:0] array_a_in,
    output logic [N*DATA_WIDTH-1:0] array_b_in,

    output logic array_valid_in,
    output logic array_first_in,
    output logic array_last_in,

    input logic [N*N*ACC_WIDTH-1:0] array_c_out,
    input logic array_done,

    // =====================================
    // Result Interface
    // =====================================

    output logic [N*N*ACC_WIDTH-1:0] result_c,
    output logic result_valid,
    input logic result_ready
);

    // =====================================
    // Controller FSM State Definitions
    // =====================================

    // Define the four controller states
    typedef enum logic [1:0] {
        IDLE,
        FEED,
        WAIT_DONE,
        RESULT
    } state_t;

    // Current state of the controller
    state_t state;

    // State the controller will enter next
    state_t next_state;


    // =====================================
    // FSM State Register
    // =====================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // =====================================
    // FSM Next-State Logic
    // =====================================

    always_comb begin

        // Stay in the current state by default
        next_state = state;

        case (state)

            
IDLE: begin
    if (fifo_valid && fifo_ready && fifo_first) begin

        if (fifo_last)
            next_state = WAIT_DONE;
        else
            next_state = FEED;

    end
end


            FEED: begin
                if (fifo_valid && fifo_ready && fifo_last)
                    next_state = WAIT_DONE;
            end

            WAIT_DONE: begin
                if (array_done)
                    next_state = RESULT;
            end

            RESULT: begin
                if (result_ready)
                    next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end

        endcase
    end

    // =====================================
    // FIFO Read Control
    // =====================================

    // Accept the first packet in IDLE.
    // Accept subsequent packets in FEED.
    assign fifo_ready =
        (state == FEED) ||
        ((state == IDLE) && fifo_first);

    // =====================================
    // Systolic Array Input Control
    // =====================================

    // A transfer occurs when both valid
    // and ready are asserted.
    assign array_valid_in = fifo_valid && fifo_ready;

    // Forward operands only during a valid transfer.
    assign array_a_in = array_valid_in ? fifo_a : '0;
    assign array_b_in = array_valid_in ? fifo_b : '0;

    // Forward packet boundary flags.
    assign array_first_in = array_valid_in && fifo_first;
    assign array_last_in  = array_valid_in && fifo_last;

    // =====================================
    // Result Register
    // =====================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            result_c <= '0;

        else if ((state == WAIT_DONE) && array_done)
            result_c <= array_c_out;
    end

    // =====================================
    // Result Valid Signal
    // =====================================

    assign result_valid = (state == RESULT);


endmodule
