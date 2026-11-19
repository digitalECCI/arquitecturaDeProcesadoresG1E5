// ============================================================================
// alu_8bit.v  -  ALU combinacional de 8 bits (ADD, SUB, AND, OR, XOR, CMP)
// alu_sel = opcode[2:0] del ISA, por lo que la decodificación es directa.
//   000 ADD   001 SUB   010 AND   011 OR   100 XOR   101 CMP
// CMP calcula a-b (solo informativo); lo importante son eq y lt, que la
// unidad de control guarda como banderas Z y LT.
// ============================================================================
module alu_8bit (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [2:0] alu_sel,
    output reg  [7:0] result,
    output wire       eq,        // a == b
    output wire       lt         // a <  b (sin signo)
);
    assign eq = (a == b);
    assign lt = (a <  b);

    always @(*) begin
        case (alu_sel)
            3'b000:  result = a + b;
            3'b001:  result = a - b;
            3'b010:  result = a & b;
            3'b011:  result = a | b;
            3'b100:  result = a ^ b;
            3'b101:  result = a - b;     // CMP
            default: result = 8'd0;
        endcase
    end
endmodule
