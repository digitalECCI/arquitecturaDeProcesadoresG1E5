// ============================================================================
// mult_seq.v  -  Multiplicador secuencial suma-desplazamiento 8x8
// Handshake: pulso start (1 ciclo) -> done en alto 1 ciclo al terminar.
// product = 8 bits bajos del producto (rd = rs * rt, truncado a 8 bits).
// Latencia: 8 ciclos de cálculo + 2 de control.
// ============================================================================
module mult_seq (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [7:0] product,
    output wire       done
);
    localparam S_IDLE = 2'd0;
    localparam S_RUN  = 2'd1;
    localparam S_DONE = 2'd2;

    reg [1:0]  state;
    reg [15:0] acc;        // acumulador del producto
    reg [15:0] mcand;      // multiplicando desplazado a la izquierda
    reg [7:0]  mplier;     // multiplicador desplazado a la derecha
    reg [3:0]  cnt;

    assign product = acc[7:0];
    assign done    = (state == S_DONE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state  <= S_IDLE;
            acc    <= 16'd0;
            mcand  <= 16'd0;
            mplier <= 8'd0;
            cnt    <= 4'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        acc    <= 16'd0;
                        mcand  <= {8'd0, a};
                        mplier <= b;
                        cnt    <= 4'd0;
                        state  <= S_RUN;
                    end
                end
                S_RUN: begin
                    if (mplier[0]) acc <= acc + mcand;
                    mcand  <= mcand << 1;
                    mplier <= mplier >> 1;
                    cnt    <= cnt + 4'd1;
                    if (cnt == 4'd7) state <= S_DONE;
                end
                S_DONE:  state <= S_IDLE;
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
