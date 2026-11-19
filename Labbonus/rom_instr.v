// ============================================================================
// rom_instr.v  -  Memoria de instrucciones (ROM de 16 x 16 bits)
// PROG = 0 : programa de ejemplo del enunciado  (5+3)*5 -> UART
// PROG = 1 : programa de prueba extendido (SUB, AND, OR, XOR, DIV, MOV, CMP, R0)
// Direcciones sin definir devuelven HALT (16'hF000).
// ============================================================================
module rom_instr #(parameter PROG = 0) (
    input  wire [3:0]  addr,
    output reg  [15:0] instr
);
    always @(*) begin
        if (PROG == 0) begin
            case (addr)
                4'd0:    instr = 16'h8205;   // LI   R1, 5
                4'd1:    instr = 16'h8403;   // LI   R2, 3
                4'd2:    instr = 16'h0650;   // ADD  R3, R1, R2   (R3 = 8)
                4'd3:    instr = 16'h68C8;   // MUL  R4, R3, R1   (R4 = 40)
                4'd4:    instr = 16'hA100;   // OUT  R4           (UART "28 ")
                4'd5:    instr = 16'hF000;   // HALT
                default: instr = 16'hF000;
            endcase
        end else begin
            case (addr)
                4'd0:    instr = 16'h820C;   // LI   R1, 12
                4'd1:    instr = 16'h8405;   // LI   R2, 5
                4'd2:    instr = 16'h1650;   // SUB  R3, R1, R2   (7)
                4'd3:    instr = 16'h2850;   // AND  R4, R1, R2   (4)
                4'd4:    instr = 16'h3A50;   // OR   R5, R1, R2   (13)
                4'd5:    instr = 16'h4C50;   // XOR  R6, R1, R2   (9)
                4'd6:    instr = 16'h7E50;   // DIV  R7, R1, R2   (2)
                4'd7:    instr = 16'h93C0;   // MOV  R1, R7       (R1 = 2)
                4'd8:    instr = 16'h5050;   // CMP  R1, R2       (2 < 5 -> LT=1, Z=0)
                4'd9:    instr = 16'h8063;   // LI   R0, 99       (ignorado: R0 = 0)
                4'd10:   instr = 16'h0408;   // ADD  R2, R0, R1   (R2 = 0 + 2 = 2)
                4'd11:   instr = 16'hA0C0;   // OUT  R3           (UART "07 ")
                4'd12:   instr = 16'hF000;   // HALT
                default: instr = 16'hF000;
            endcase
        end
    end
endmodule
