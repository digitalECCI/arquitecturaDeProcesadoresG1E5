// ============================================================================
// top_lab05.v  -  Procesador: ROM + UC + banco + ALU + mult/div + UART
//
// KEY[0] : reset (activo en bajo)
// KEY[1] : run   (con antirrebote) - inicia el programa; asi puede abrir la terminal antes
// El programa avanza UNA instruccion cada STEP_CYCLES ciclos (por defecto 1 s).
// HEX5   : PC                HEX4 : opcode de la instrucción en curso
// HEX3-2 : último valor escrito en un registro (tras el programa de ejemplo = 0x28)
// LEDR[7:0] = último valor escrito | LEDR[8] = bandera Z | LEDR[9] = HALT
// HEX0 y HEX1 permanecen apagados (displays dañados).
// ============================================================================
module top_lab05 #(
    parameter PROG        = 0,
    parameter STEP_CYCLES = 50000000   // pausa entre instrucciones: 50000000 = 1 s a 50 MHz
) (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    output wire       UART_TXD,
    output wire       UART_TXD_ALT,
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,
    output wire [9:0] LEDR
);
    wire clk = MAX10_CLK1_50;
    wire rst = ~KEY[0];

    assign HEX0 = 7'b1111111;
    assign HEX1 = 7'b1111111;

    // ---------------- Antirrebote del botón run ----------------
    wire run;
    debouncer u_debouncer (
        .clk(clk), .rst(rst), .btn_in(KEY[1]), .btn_out(), .btn_pulse(run)
    );

    // ---------------- Memoria de instrucciones y unidad de control ----------------
    wire [3:0]  pc;
    wire [15:0] instr, ir;
    wire [3:0]  opcode, state;
    wire [2:0]  rd_addr, rs_addr, rt_addr, alu_sel;
    wire [7:0]  imm;
    wire [1:0]  wsel;
    wire        we, mul_start, div_start, uart_start, flag_we, halted;
    wire        mul_done, div_done, uart_busy;

    rom_instr #(.PROG(PROG)) u_rom (.addr(pc), .instr(instr));

    control_unit #(.STEP_CYCLES(STEP_CYCLES)) u_uc (
        .clk(clk), .rst(rst), .run(run), .instr(instr),
        .mul_done(mul_done), .div_done(div_done), .uart_busy(uart_busy),
        .pc_out(pc), .ir_out(ir), .opcode(opcode),
        .rd_addr(rd_addr), .rs_addr(rs_addr), .rt_addr(rt_addr),
        .imm(imm), .alu_sel(alu_sel), .we(we), .wsel(wsel),
        .mul_start(mul_start), .div_start(div_start), .uart_start(uart_start),
        .flag_we(flag_we), .halted(halted), .state_out(state)
    );

    // ---------------- Datapath ----------------
    wire [7:0] rdata1, rdata2, alu_result, mul_p, div_q, div_r;
    wire       alu_eq, alu_lt;
    reg  [7:0] wdata;

    banco_registros u_banco (
        .clk(clk), .rst(rst),
        .raddr1(rs_addr), .raddr2(rt_addr), .rdata1(rdata1), .rdata2(rdata2),
        .we(we), .waddr(rd_addr), .wdata(wdata)
    );

    alu_8bit u_alu (
        .a(rdata1), .b(rdata2), .alu_sel(alu_sel),
        .result(alu_result), .eq(alu_eq), .lt(alu_lt)
    );

    mult_seq u_mult (
        .clk(clk), .rst(rst), .start(mul_start),
        .a(rdata1), .b(rdata2), .product(mul_p), .done(mul_done)
    );

    div_seq u_div (
        .clk(clk), .rst(rst), .start(div_start),
        .a(rdata1), .b(rdata2), .quotient(div_q), .remainder(div_r), .done(div_done)
    );

    // Multiplexor de escritura (MUL = 0110, DIV = 0111 -> opcode[0] distingue)
    always @(*) begin
        case (wsel)
            2'b00:   wdata = alu_result;
            2'b01:   wdata = imm;
            2'b10:   wdata = opcode[0] ? div_q : mul_p;
            2'b11:   wdata = rdata1;
            default: wdata = 8'd0;
        endcase
    end

    // ---------------- Banderas (se actualizan con CMP) y último valor escrito ----------------
    reg       flag_z, flag_lt;
    reg [7:0] last_wb;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            flag_z  <= 1'b0;
            flag_lt <= 1'b0;
            last_wb <= 8'd0;
        end else begin
            if (flag_we) begin
                flag_z  <= alu_eq;
                flag_lt <= alu_lt;
            end
            if (we) last_wb <= wdata;
        end
    end

    // ---------------- UART: OUT transmite rs como "XX " ----------------
    wire uart_signal;
    uart_hex_sender u_sender (
        .clk(clk), .rst(rst), .start(uart_start), .data(rdata1),
        .tx_serial(uart_signal), .busy(uart_busy)
    );
    assign UART_TXD     = uart_signal;
    assign UART_TXD_ALT = uart_signal;

    // ---------------- Displays y LEDs ----------------
    display_7seg u_hex5 (.hex_digit(pc),           .seg(HEX5));
    display_7seg u_hex4 (.hex_digit(opcode),       .seg(HEX4));
    display_7seg u_hex3 (.hex_digit(last_wb[7:4]), .seg(HEX3));
    display_7seg u_hex2 (.hex_digit(last_wb[3:0]), .seg(HEX2));

    assign LEDR[7:0] = last_wb;
    assign LEDR[8]   = flag_z;
    assign LEDR[9]   = halted;
endmodule