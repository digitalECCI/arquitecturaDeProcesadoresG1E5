// ============================================================================
// div_seq.v  -  Divisor secuencial restaurador 8/8 (cociente y residuo)
// Handshake: pulso start (1 ciclo) -> done en alto 1 ciclo al terminar.
// División por cero: quotient = 8'hFF, remainder = 0 (convención del diseño).
// ============================================================================
module div_seq (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [7:0] a,            // dividendo
    input  wire [7:0] b,            // divisor
    output wire [7:0] quotient,
    output wire [7:0] remainder,
    output wire       done
);
    localparam S_IDLE = 2'd0;
    localparam S_RUN  = 2'd1;
    localparam S_DONE = 2'd2;

    reg [1:0] state;
    reg [7:0] dividend;             // al terminar contiene el cociente
    reg [7:0] divisor;
    reg [8:0] rem;
    reg [3:0] cnt;

    wire [8:0] rem_sh = {rem[7:0], dividend[7]};
    wire       ge     = (rem_sh >= {1'b0, divisor});

    assign quotient  = dividend;
    assign remainder = rem[7:0];
    assign done      = (state == S_DONE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= S_IDLE;
            dividend <= 8'd0;
            divisor  <= 8'd0;
            rem      <= 9'd0;
            cnt      <= 4'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        if (b == 8'd0) begin
                            dividend <= 8'hFF;
                            divisor  <= 8'd0;
                            rem      <= 9'd0;
                            state    <= S_DONE;
                        end else begin
                            dividend <= a;
                            divisor  <= b;
                            rem      <= 9'd0;
                            cnt      <= 4'd0;
                            state    <= S_RUN;
                        end
                    end
                end
                S_RUN: begin
                    if (ge) begin
                        rem      <= rem_sh - {1'b0, divisor};
                        dividend <= {dividend[6:0], 1'b1};
                    end else begin
                        rem      <= rem_sh;
                        dividend <= {dividend[6:0], 1'b0};
                    end
                    cnt <= cnt + 4'd1;
                    if (cnt == 4'd7) state <= S_DONE;
                end
                S_DONE:  state <= S_IDLE;
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
