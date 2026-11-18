
module output_fifo #(
    parameter int N = 2,
    parameter int ACC_WIDTH = 32,
    parameter int DEPTH = 4
)(
    // Clock and reset
    input logic clk,
    input logic rst_n,

    // Input from array controller
    input logic [N*N*ACC_WIDTH-1:0] in_data,
    input logic in_valid,
    output logic in_ready,

    // Output to external receiver
    output logic [N*N*ACC_WIDTH-1:0] out_data,
    output logic out_valid,
    input logic out_ready
);

    
    // =====================================
    // FIFO Parameters
    // =====================================

    localparam int RESULT_WIDTH = N*N*ACC_WIDTH;

    localparam int PTR_WIDTH =
        (DEPTH > 1) ? $clog2(DEPTH) : 1;

    localparam int COUNT_WIDTH =
        $clog2(DEPTH + 1);

    // =====================================
    // FIFO Storage
    // =====================================

    logic [RESULT_WIDTH-1:0] storage [0:DEPTH-1];

    // =====================================
    // Read and Write Pointers
    // =====================================

    logic [PTR_WIDTH-1:0] write_ptr;
    logic [PTR_WIDTH-1:0] read_ptr;

    // Number of results stored
    logic [COUNT_WIDTH-1:0] count;


    // =====================================
    // FIFO Transfer Control
    // =====================================

    logic write_fire;
    logic read_fire;

    // A result is available when FIFO is not empty.
    assign out_valid = (count != 0);

    // A read occurs when the receiver accepts data.
    assign read_fire = out_valid && out_ready;

    // Accept a new result when space is available,
    // or when a read frees space on the same cycle.
    assign in_ready =
        (count < COUNT_WIDTH'(DEPTH)) || read_fire;

    // A write occurs when input is valid and ready.
    assign write_fire = in_valid && in_ready;


    // =====================================
    // FIFO Write Logic
    // =====================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= '0;
        end
        else if (write_fire) begin

            // Store the incoming matrix result
            storage[write_ptr] <= in_data;

            // Advance write pointer with wraparound
            if (write_ptr == PTR_WIDTH'(DEPTH - 1))
                write_ptr <= '0;
            else
                write_ptr <= write_ptr + 1'b1;

        end
    end


    // =====================================
    // FIFO Read Logic
    // =====================================

    // Present the oldest stored matrix result
    assign out_data = storage[read_ptr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr <= '0;
        end
        else if (read_fire) begin

            // Advance read pointer with wraparound
            if (read_ptr == PTR_WIDTH'(DEPTH - 1))
                read_ptr <= '0;
            else
                read_ptr <= read_ptr + 1'b1;

        end
    end

    // =====================================
    // FIFO Occupancy Counter
    // =====================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end
        else begin
            case ({write_fire, read_fire})

                // Write only: one new result stored
                2'b10: count <= count + 1'b1;

                // Read only: one result removed
                2'b01: count <= count - 1'b1;

                // Simultaneous read/write or no transfer
                default: count <= count;

            endcase
        end
    end

endmodule
