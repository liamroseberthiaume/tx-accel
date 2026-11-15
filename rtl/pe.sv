module pe #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
)(
    // Clock and reset
    input logic clk,
    input logic rst_n,

    // Input operands
    input logic signed [DATA_WIDTH-1:0] a_in,
    input logic signed [DATA_WIDTH-1:0] b_in,

    // Input control signals
    input logic valid_in,
    input logic first_in,
    input logic last_in,

    // Forwarded operands
    output logic signed [DATA_WIDTH-1:0] a_out,
    output logic signed [DATA_WIDTH-1:0] b_out,

    // Forwarded control signals
    output logic valid_out,
    output logic first_out,
    output logic last_out,

    // Accumulated result
    output logic signed [ACC_WIDTH-1:0] acc_out
);

    // The product of two DATA_WIDTH-bit numbers
    // requires up to 2 * DATA_WIDTH bits.
    localparam int PRODUCT_WIDTH = 2 * DATA_WIDTH;

    logic signed [PRODUCT_WIDTH-1:0] a_extended;
    logic signed [PRODUCT_WIDTH-1:0] b_extended;
    logic signed [PRODUCT_WIDTH-1:0] product;
    logic signed [ACC_WIDTH-1:0] product_extended;

    // Sign-extend the operands before multiplying.
    assign a_extended = {
        {DATA_WIDTH{a_in[DATA_WIDTH-1]}}, a_in
    };

    assign b_extended = {
        {DATA_WIDTH{b_in[DATA_WIDTH-1]}}, b_in
    };

    // Signed multiplication
    assign product = a_extended * b_extended;

    // Extend the product to accumulator width.
    assign product_extended = {
        {(ACC_WIDTH-PRODUCT_WIDTH){product[PRODUCT_WIDTH-1]}},
        product
    };

    // Clocked processing logic
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            // Initialize all registers
            a_out     <= '0;
            b_out     <= '0;
            valid_out <= 1'b0;
            first_out <= 1'b0;
            last_out  <= 1'b0;
            acc_out   <= '0;

        end else begin

            // Forward operands to neighbouring PEs
            a_out <= a_in;
            b_out <= b_in;

            // Forward control signals
            valid_out <= valid_in;
            first_out <= first_in;
            last_out  <= last_in;

            // Multiply and accumulate valid inputs
            if (valid_in) begin

                if (first_in) begin
                    // Start a new accumulation
                    acc_out <= product_extended;
                end else begin
                    // Continue the existing sum
                    acc_out <= acc_out + product_extended;
                end

            end
            // Otherwise, retain the accumulator value.

        end

    end

endmodule
