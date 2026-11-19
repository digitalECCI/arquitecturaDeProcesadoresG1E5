// ============================================================================
// uart_hex_sender.v  -  Envía un byte por UART como "XX " (2 hex ASCII + espacio)
// Es la FSM de transmisión del top del Lab 04, encapsulada con handshake:
//   start (pulso 1 ciclo) + data  ->  busy en alto hasta terminar los 3 caracteres
// Usa uart_tx.v sin cambios (9600 baudios, 8N1).
// ============================================================================
module uart_hex_sender (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [7:0] data,
    output wire       tx_serial,
    output wire       busy
);
    localparam S_IDLE     = 4'd0;
    localparam S_PRE      = 4'd1;
    localparam S_HI_START = 4'd2;
    localparam S_HI_WAIT  = 4'd3;
    localparam S_LO_START = 4'd4;
    localparam S_LO_WAIT  = 4'd5;
    localparam S_SP_START = 4'd6;
    localparam S_SP_WAIT  = 4'd7;

    reg [3:0] seq_state;
    reg [7:0] data_lat;
    reg [7:0] tx_data_reg;
    reg       tx_start_reg;
    wire      uart_busy;

    wire [3:0] nibble_high = data_lat[7:4];
    wire [3:0] nibble_low  = data_lat[3:0];
    wire [7:0] ascii_high  = (nibble_high < 4'd10) ? (8'd48 + {4'b0000, nibble_high})
                                                   : (8'd55 + {4'b0000, nibble_high});
    wire [7:0] ascii_low   = (nibble_low  < 4'd10) ? (8'd48 + {4'b0000, nibble_low})
                                                   : (8'd55 + {4'b0000, nibble_low});

    assign busy = (seq_state != S_IDLE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            seq_state    <= S_IDLE;
            data_lat     <= 8'd0;
            tx_data_reg  <= 8'd0;
            tx_start_reg <= 1'b0;
        end else begin
            tx_start_reg <= 1'b0;
            case (seq_state)
                S_IDLE: begin
                    if (start) begin
                        data_lat  <= data;
                        seq_state <= S_PRE;
                    end
                end
                S_PRE: begin
                    tx_data_reg  <= ascii_high;
                    tx_start_reg <= 1'b1;
                    seq_state    <= S_HI_START;
                end
                S_HI_START: if (uart_busy)  seq_state <= S_HI_WAIT;
                S_HI_WAIT: begin
                    if (!uart_busy) begin
                        tx_data_reg  <= ascii_low;
                        tx_start_reg <= 1'b1;
                        seq_state    <= S_LO_START;
                    end
                end
                S_LO_START: if (uart_busy)  seq_state <= S_LO_WAIT;
                S_LO_WAIT: begin
                    if (!uart_busy) begin
                        tx_data_reg  <= 8'd32;      // espacio ' '
                        tx_start_reg <= 1'b1;
                        seq_state    <= S_SP_START;
                    end
                end
                S_SP_START: if (uart_busy)  seq_state <= S_SP_WAIT;
                S_SP_WAIT:  if (!uart_busy) seq_state <= S_IDLE;
                default:    seq_state <= S_IDLE;
            endcase
        end
    end

    uart_tx u_uart (
        .clk       (clk),
        .rst       (rst),
        .tx_start  (tx_start_reg),
        .data_in   (tx_data_reg),
        .tx_serial (tx_serial),
        .tx_busy   (uart_busy)
    );
endmodule
