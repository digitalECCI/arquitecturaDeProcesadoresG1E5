module uart_tx (
    input  wire       clk,
    input  wire       rst,
    input  wire       tx_start,
    input  wire [7:0] data_in,
    output reg        tx_serial,
    output reg        tx_busy
);
    localparam CLKS_PER_BIT = 13'd5208; // 50 MHz / 9600 baudios

    localparam STATE_IDLE  = 2'd0;
    localparam STATE_START = 2'd1;
    localparam STATE_DATA  = 2'd2;
    localparam STATE_STOP  = 2'd3;

    reg [1:0]  state;
    reg [12:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  data_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= STATE_IDLE;
            clk_count <= 13'd0;
            bit_index <= 3'd0;
            data_reg  <= 8'd0;
            tx_serial <= 1'b1;
            tx_busy   <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    tx_serial <= 1'b1;
                    clk_count <= 13'd0;
                    bit_index <= 3'd0;
                    if (tx_start) begin
                        data_reg <= data_in;
                        tx_busy  <= 1'b1;
                        state    <= STATE_START;
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end

                STATE_START: begin
                    tx_serial <= 1'b0;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 13'd1;
                    end else begin
                        clk_count <= 13'd0;
                        state     <= STATE_DATA;
                    end
                end

                STATE_DATA: begin
                    tx_serial <= data_reg[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 13'd1;
                    end else begin
                        clk_count <= 13'd0;
                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 3'd1;
                        end else begin
                            bit_index <= 3'd0;
                            state     <= STATE_STOP;
                        end
                    end
                end

                STATE_STOP: begin
                    tx_serial <= 1'b1;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 13'd1;
                    end else begin
                        clk_count <= 13'd0;
                        tx_busy   <= 1'b0;
                        state     <= STATE_IDLE;
                    end
                end

                default: begin
                    state     <= STATE_IDLE;
                    tx_serial <= 1'b1;
                    tx_busy   <= 1'b0;
                end
            endcase
        end
    end
endmodule