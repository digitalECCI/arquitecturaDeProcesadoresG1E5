// ============================================================================
// control_unit.v  -  Unidad de control (FSM fetch-decode-execute-writeback)
//
// Formato de instrucción (16 bits):
//   Tipo R: | opcode[15:12] | rd[11:9] | rs[8:6] | rt[5:3] | sin uso[2:0] |
//   Tipo I: | opcode[15:12] | rd[11:9] |        imm[8:0]                  |
//
// Estados:
//   IDLE      espera el pulso run (KEY[1] con antirrebote)
//   FETCH     ir <= ROM[pc]; pc <= pc+1
//   DECODE    separa campos (combinacional) y elige el camino según opcode
//   EXEC      la ALU opera; en CMP se actualizan las banderas (sin WB)
//   MD_START  pulso start al multiplicador o al divisor
//   MD_WAIT   espera done (handshake start/done)
//   WB        escribe rd con la fuente elegida por wsel (we = 1)
//   OUT_START pulso start a la UART
//   OUT_WAIT  espera a que la UART termine (busy = 0)
//   WAIT      pausa de STEP_CYCLES ciclos entre una instrucción y la siguiente
//   HALT      detenido hasta reset (también para opcodes inválidos)
// ============================================================================
module control_unit #(
    parameter STEP_CYCLES = 50000000   // ciclos de espera entre instrucciones (50 MHz -> 1 s)
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        run,
    input  wire [15:0] instr,        // palabra que entrega la ROM para pc
    input  wire        mul_done,
    input  wire        div_done,
    input  wire        uart_busy,

    output wire [3:0]  pc_out,
    output wire [15:0] ir_out,
    output wire [3:0]  opcode,
    output wire [2:0]  rd_addr,
    output wire [2:0]  rs_addr,
    output wire [2:0]  rt_addr,
    output wire [7:0]  imm,
    output wire [2:0]  alu_sel,
    output wire        we,
    output wire [1:0]  wsel,         // 00 ALU | 01 inmediato | 10 mult/div | 11 rs (MOV)
    output wire        mul_start,
    output wire        div_start,
    output wire        uart_start,
    output wire        flag_we,
    output wire        halted,
    output wire [3:0]  state_out
);
    // ---------------- Opcodes del ISA ----------------
    localparam OP_ADD  = 4'b0000;
    localparam OP_SUB  = 4'b0001;
    localparam OP_AND  = 4'b0010;
    localparam OP_OR   = 4'b0011;
    localparam OP_XOR  = 4'b0100;
    localparam OP_CMP  = 4'b0101;
    localparam OP_MUL  = 4'b0110;
    localparam OP_DIV  = 4'b0111;
    localparam OP_LI   = 4'b1000;
    localparam OP_MOV  = 4'b1001;
    localparam OP_OUT  = 4'b1010;
    localparam OP_HALT = 4'b1111;

    // ---------------- Estados ----------------
    localparam S_IDLE      = 4'd0;
    localparam S_FETCH     = 4'd1;
    localparam S_DECODE    = 4'd2;
    localparam S_EXEC      = 4'd3;
    localparam S_MD_START  = 4'd4;
    localparam S_MD_WAIT   = 4'd5;
    localparam S_WB        = 4'd6;
    localparam S_OUT_START = 4'd7;
    localparam S_OUT_WAIT  = 4'd8;
    localparam S_HALT      = 4'd9;
    localparam S_WAIT      = 4'd10;

    localparam [31:0] STEP_MAX = STEP_CYCLES - 1;

    reg [3:0]  state, next_state;
    reg [3:0]  pc;
    reg [15:0] ir;
    reg [31:0] step_cnt;               // cuenta los ciclos de la pausa entre instrucciones

    // ---------------- Campos de la instrucción ----------------
    assign opcode  = ir[15:12];
    assign rd_addr = ir[11:9];
    assign rs_addr = ir[8:6];
    assign rt_addr = ir[5:3];
    assign imm     = ir[7:0];          // inmediato de 9 bits recortado a 8 (complemento a 2)
    assign alu_sel = ir[14:12];        // opcode[2:0] coincide con alu_sel

    assign pc_out    = pc;
    assign ir_out    = ir;
    assign state_out = state;

    // ---------------- Registro de estado, PC e IR ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            pc    <= 4'd0;
            ir    <= 16'd0;
        end else begin
            state <= next_state;
            if (state == S_FETCH) begin
                ir <= instr;
                pc <= pc + 4'd1;
            end
        end
    end

    // ---------------- Contador de la pausa entre instrucciones ----------------
    always @(posedge clk or posedge rst) begin
        if (rst)                    step_cnt <= 32'd0;
        else if (state == S_WAIT)   step_cnt <= step_cnt + 32'd1;
        else                        step_cnt <= 32'd0;
    end

    // ---------------- Lógica de siguiente estado ----------------
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:   if (run) next_state = S_FETCH;
            S_FETCH:  next_state = S_DECODE;
            S_DECODE: begin
                case (opcode)
                    OP_ADD, OP_SUB, OP_AND, OP_OR, OP_XOR, OP_CMP: next_state = S_EXEC;
                    OP_MUL, OP_DIV:                                next_state = S_MD_START;
                    OP_LI,  OP_MOV:                                next_state = S_WB;
                    OP_OUT:                                        next_state = S_OUT_START;
                    OP_HALT:                                       next_state = S_HALT;
                    default:                                       next_state = S_HALT; // opcode inválido
                endcase
            end
            S_EXEC:      next_state = (opcode == OP_CMP) ? S_WAIT : S_WB;
            S_MD_START:  next_state = S_MD_WAIT;
            S_MD_WAIT:   if ((opcode == OP_MUL && mul_done) || (opcode == OP_DIV && div_done))
                             next_state = S_WB;
            S_WB:        next_state = S_WAIT;
            S_OUT_START: next_state = S_OUT_WAIT;
            S_OUT_WAIT:  if (!uart_busy) next_state = S_WAIT;
            S_WAIT:      if (step_cnt == STEP_MAX) next_state = S_FETCH;
            S_HALT:      next_state = S_HALT;
            default:     next_state = S_IDLE;
        endcase
    end

    // ---------------- Señales de control (salidas Moore) ----------------
    assign we         = (state == S_WB);
    assign mul_start  = (state == S_MD_START) && (opcode == OP_MUL);
    assign div_start  = (state == S_MD_START) && (opcode == OP_DIV);
    assign uart_start = (state == S_OUT_START);
    assign flag_we    = (state == S_EXEC) && (opcode == OP_CMP);
    assign halted     = (state == S_HALT);

    assign wsel = (opcode == OP_LI)                      ? 2'b01 :
                  (opcode == OP_MUL || opcode == OP_DIV) ? 2'b10 :
                  (opcode == OP_MOV)                     ? 2'b11 :
                                                           2'b00;
endmodule