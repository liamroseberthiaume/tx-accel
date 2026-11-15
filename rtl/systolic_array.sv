
module systolic_array #(
    parameter int N = 2,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32
)(
    // Clock and reset
    input logic clk,
    input logic rst_n,

    // Packed input operands
    input logic [N*DATA_WIDTH-1:0] a_in,
    input logic [N*DATA_WIDTH-1:0] b_in,

    // Control signals
    input logic valid_in,
    input logic first_in,
    input logic last_in,

    // Packed matrix results
    output logic [N*N*ACC_WIDTH-1:0] c_out,

    // Completion signal
    output logic done
);

    // ==========================================
    // Internal connections between PEs
    // ==========================================

    // Forwarded A operands (move right)
    logic signed [DATA_WIDTH-1:0] a_forward [0:N-1][0:N-1];

    // Forwarded B operands (move down)
    logic signed [DATA_WIDTH-1:0] b_forward [0:N-1][0:N-1];

    // Forwarded control signals
    logic valid_forward [0:N-1][0:N-1];
    logic first_forward [0:N-1][0:N-1];
    logic last_forward  [0:N-1][0:N-1];

    // Accumulator result from each PE
    logic signed [ACC_WIDTH-1:0] pe_acc [0:N-1][0:N-1]; 

    // ==========================================
    // A input skewing and control alignment
    // ==========================================

    logic signed [DATA_WIDTH-1:0] a_row_skewed [0:N-1];

    logic valid_row_skewed [0:N-1];
    logic first_row_skewed [0:N-1];
    logic last_row_skewed  [0:N-1];

    // Generate delay pipelines for each A row
    for (genvar row = 0; row < N; row++) begin : gen_a_input_skew

        // Row 'row' requires exactly 'row' delays
        logic signed [DATA_WIDTH-1:0] a_pipe [0:row];

        logic valid_pipe [0:row];
        logic first_pipe [0:row];
        logic last_pipe  [0:row];

        // Stage 0: incoming data, no delay
        always @* begin
            a_pipe[0] =
                $signed(a_in[row*DATA_WIDTH +: DATA_WIDTH]);

            valid_pipe[0] = valid_in;
            first_pipe[0] = first_in;
            last_pipe[0]  = last_in;
        end

        // Add one register for each required delay
        for (genvar stage = 1; stage <= row; stage++)
            begin : gen_a_delay

            always_ff @(posedge clk or negedge rst_n) begin

                if (!rst_n) begin

                    a_pipe[stage]     <= '0;
                    valid_pipe[stage] <= 1'b0;
                    first_pipe[stage] <= 1'b0;
                    last_pipe[stage]  <= 1'b0;

                end else begin

                    a_pipe[stage]     <= a_pipe[stage-1];
                    valid_pipe[stage] <= valid_pipe[stage-1];
                    first_pipe[stage] <= first_pipe[stage-1];
                    last_pipe[stage]  <= last_pipe[stage-1];

                end

            end

        end

        // Output of the row's delay pipeline
        assign a_row_skewed[row] = a_pipe[row];

        assign valid_row_skewed[row] = valid_pipe[row];
        assign first_row_skewed[row] = first_pipe[row];
        assign last_row_skewed[row]  = last_pipe[row];

    end

    // ==========================================
    // B input skewing
    // ==========================================

    // Delayed B operand for each column
    logic signed [DATA_WIDTH-1:0] b_col_skewed [0:N-1];

    // Generate delay pipelines for B columns
    for (genvar col = 0; col < N; col++)
        begin : gen_b_input_skew

        // Column 'col' requires 'col' delays
        logic signed [DATA_WIDTH-1:0] b_pipe [0:col];

        // Stage 0: Incoming B operand
        always @* begin
        b_pipe[0] =
            $signed(b_in[col*DATA_WIDTH +: DATA_WIDTH]);
        end

        // Create the required delay registers
        for (genvar stage = 1; stage <= col; stage++)
            begin : gen_b_delay

            always_ff @(posedge clk or negedge rst_n) begin

                if (!rst_n) begin

                    // Reset the delay register
                    b_pipe[stage] <= '0;

                end else begin

                    // Move B to the next pipeline stage
                    b_pipe[stage] <= b_pipe[stage-1];

                end

            end

        end

        // Output of the column's delay pipeline
        assign b_col_skewed[col] = b_pipe[col];

    end
    
    // ==========================================
    // Generate the N x N grid of PEs
    // ==========================================

    for (genvar r = 0; r < N; r++) begin : gen_rows

        for (genvar c = 0; c < N; c++) begin : gen_cols

            // Inputs to this particular PE
            logic signed [DATA_WIDTH-1:0] pe_a;
            logic signed [DATA_WIDTH-1:0] pe_b;

            logic pe_valid;
            logic pe_first;
            logic pe_last;

            // ==================================
            // A input: left edge or left neighbor
            // ==================================

        if (c == 0) begin : left_edge

            // A comes from the row-specific delay pipeline
            assign pe_a = a_row_skewed[r];

            // Control flags use the same row delay
            assign pe_valid = valid_row_skewed[r];
            assign pe_first = first_row_skewed[r];
            assign pe_last  = last_row_skewed[r];

        end else begin : from_left

                assign pe_a = a_forward[r][c-1];

                assign pe_valid = valid_forward[r][c-1];
                assign pe_first = first_forward[r][c-1];
                assign pe_last  = last_forward[r][c-1];

            end

            // ==================================
            // B input: top edge or upper neighbor
            // ==================================

            if (r == 0) begin : top_edge

                // Receive B from the column delay pipeline
                assign pe_b = b_col_skewed[c];

            end else begin : from_above

                // Receive B from the PE directly above
                assign pe_b = b_forward[r-1][c];

            end

            // ==================================
            // Instantiate one processing element
            // ==================================

            pe #(
                .DATA_WIDTH(DATA_WIDTH),
                .ACC_WIDTH(ACC_WIDTH)
            ) u_pe (

                .clk(clk),
                .rst_n(rst_n),

                .a_in(pe_a),
                .b_in(pe_b),

                .valid_in(pe_valid),
                .first_in(pe_first),
                .last_in(pe_last),

                .a_out(a_forward[r][c]),
                .b_out(b_forward[r][c]),

                .valid_out(valid_forward[r][c]),
                .first_out(first_forward[r][c]),
                .last_out(last_forward[r][c]),

                .acc_out(pe_acc[r][c])

            );

            // Place this PE's result into c_out
            assign c_out[(r*N+c)*ACC_WIDTH +: ACC_WIDTH]
                = pe_acc[r][c];

        end

    end

    // Completion from the bottom-right PE
    assign done =
        valid_forward[N-1][N-1] &
        last_forward[N-1][N-1];

endmodule
