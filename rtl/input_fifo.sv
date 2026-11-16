
module input_fifo #(
    // Configuration parameters
    parameter int N = 2,
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH = 4
)(
    // Clock and reset
    input logic clk,
    input logic rst_n,

    // =====================================
    // Input side: Sender to FIFO
    // =====================================

    // Matrix operands
    input logic [N*DATA_WIDTH-1:0] in_a,
    input logic [N*DATA_WIDTH-1:0] in_b,

    // Packet control flags
    input logic in_first,
    input logic in_last,

    // Input handshake
    input logic in_valid,
    output logic in_ready,

    // =====================================
    // Output side: FIFO to Controller
    // =====================================

    // Stored matrix operands
    output logic [N*DATA_WIDTH-1:0] out_a,
    output logic [N*DATA_WIDTH-1:0] out_b,

    // Stored packet control flags
    output logic out_first,
    output logic out_last,

    // Output handshake
    output logic out_valid,
    input logic out_ready
);

    
    // =====================================
    // FIFO Internal Storage
    // =====================================

    // Width of one complete packet:
    // A operands + B operands + first + last
    localparam int PACKET_WIDTH = 2*N*DATA_WIDTH + 2;

    // Number of bits needed for storage addresses
    localparam int PTR_WIDTH =
        (DEPTH > 1) ? $clog2(DEPTH) : 1;

    // Number of bits needed to count 0 through DEPTH
    localparam int COUNT_WIDTH =
        $clog2(DEPTH + 1);

    // Storage array containing DEPTH packets
    logic [PACKET_WIDTH-1:0] storage [0:DEPTH-1];

    // Points to the next location to write
    logic [PTR_WIDTH-1:0] write_ptr;

    // Points to the next location to read
    logic [PTR_WIDTH-1:0] read_ptr;

    // Number of packets currently stored
    logic [COUNT_WIDTH-1:0] count;


    // =====================================
    // FIFO Handshake Control
    // =====================================

    // Internal transfer indicators
    logic write_fire;
    logic read_fire;

    // Data is available whenever the FIFO is not empty
    assign out_valid = (count != 0);

    // A packet leaves when the controller accepts it
    assign read_fire = out_valid && out_ready;

    // Accept data when there is space, or when a
    // packet is being removed on the same clock edge
    assign in_ready =
        (count < COUNT_WIDTH'(DEPTH)) || read_fire;

    // A packet enters when the sender transfers it
    assign write_fire = in_valid && in_ready;


    // =====================================
    // FIFO Clocked Storage and Pointers
    // =====================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            // Reset FIFO to an empty state
            write_ptr <= '0;
            read_ptr  <= '0;
            count     <= '0;

        end else begin

            // Accept and store a new packet
            if (write_fire) begin

                storage[write_ptr] <= {
                    in_first,
                    in_last,
                    in_a,
                    in_b
                };

                // Advance write pointer with wraparound
                if (write_ptr == PTR_WIDTH'(DEPTH - 1))
                    write_ptr <= '0;
                else
                    write_ptr <= write_ptr + 1'b1;
            end

            // Remove the oldest packet
            if (read_fire) begin

                // Advance read pointer with wraparound
                if (read_ptr == PTR_WIDTH'(DEPTH - 1))
                    read_ptr <= '0;
                else
                    read_ptr <= read_ptr + 1'b1;
            end

            // Update number of stored packets
            case ({write_fire, read_fire})

                2'b10: count <= count + 1'b1;

                2'b01: count <= count - 1'b1;

                // No transfers or simultaneous transfers:
                // occupancy stays unchanged
                default: count <= count;

            endcase
        end
    end


    // =====================================
    // FIFO Output Data
    // =====================================

    // Present the oldest stored packet.
    // Output zeros when the FIFO is empty.
    assign {
        out_first,
        out_last,
        out_a,
        out_b
    } = out_valid ? storage[read_ptr] : '0;

endmodule
