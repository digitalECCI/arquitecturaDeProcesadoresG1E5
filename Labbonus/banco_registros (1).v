// ============================================================================
// banco_registros.v  -  Banco de 8 registros x 8 bits (R0..R7)
// Cambios respecto al Lab 04:
//   * DOS puertos de lectura combinacionales (rs y rt a la vez)
//   * R0 cableado a 0: siempre se lee 0 y las escrituras a R0 se ignoran
//   * Escritura síncrona con we; sin bucles for ni function
// ============================================================================
module banco_registros (
    input  wire       clk,
    input  wire       rst,
    // Puertos de lectura (combinacionales)
    input  wire [2:0] raddr1,
    input  wire [2:0] raddr2,
    output wire [7:0] rdata1,
    output wire [7:0] rdata2,
    // Puerto de escritura (síncrono)
    input  wire       we,
    input  wire [2:0] waddr,
    input  wire [7:0] wdata
);
    reg [7:0] regs [0:7];

    assign rdata1 = (raddr1 == 3'd0) ? 8'd0 : regs[raddr1];
    assign rdata2 = (raddr2 == 3'd0) ? 8'd0 : regs[raddr2];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            regs[0] <= 8'd0; regs[1] <= 8'd0; regs[2] <= 8'd0; regs[3] <= 8'd0;
            regs[4] <= 8'd0; regs[5] <= 8'd0; regs[6] <= 8'd0; regs[7] <= 8'd0;
        end else if (we) begin
            case (waddr)
                3'd0:    ;                      // R0 = 0 fijo: se ignora
                3'd1:    regs[1] <= wdata;
                3'd2:    regs[2] <= wdata;
                3'd3:    regs[3] <= wdata;
                3'd4:    regs[4] <= wdata;
                3'd5:    regs[5] <= wdata;
                3'd6:    regs[6] <= wdata;
                3'd7:    regs[7] <= wdata;
                default: ;
            endcase
        end
    end
endmodule
