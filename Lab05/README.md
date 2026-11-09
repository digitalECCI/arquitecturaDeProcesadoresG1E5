## Lab 05 Multiplicadora de 3×3 bits

## Integrantes
* [Pedro Felipe Jimenez Celis](https://github.compedrofejimenezce-ship-it) 
* [Laura Alejandra Fuentes Ubaque](https://github.com/lauAlejandrxf) 
* [Sebastian Buitrago Oliveros](https://github.com/SebastianBuitrago16) 

## Introducción
En este laboratorio se armó en la FPGA una ALU de 4 bits hace ocho operaciones (suma, resta, multiplicación, mayor, desplazamiento, AND, NOR y XOR) con los números que se ponen en los switches. El resultado se puede guardar en un banco de 8 registros de 8 bits y mostrarse en los displays y LEDs en hexadecimal. Además, el valor se envía por UART a 9600 baudios hacia el computador, y se usa un anti-rebote para que el botón de ejecutar funcione limpio.

## Explicación de codigo
*Alu_4bit.v* 

    always @(*) begin
        case (opcode)
            3'b000: result = {4'b0000, A} + {4'b0000, B}; // Suma
            3'b001: result = {4'b0000, A} - {4'b0000, B}; // Resta
            3'b010: result = A * B;                       // Multiplicación
            3'b011: ... // Mayor de los dos
            3'b100: result = {3'b000, A, 1'b0};           // A << 1
            3'b101: result = {4'b0000, (A & B)};          // AND
            3'b110: result = {4'b0000, ~(A | B)};         // NOR
            3'b111: result = {4'b0000, (A ^ B)};          // XOR
        endcase
    end

Es un circuito combinacional: según el opcode de 3 bits elige una de 8 operaciones entre A y B. El resultado es de 8 bits para que quepa la multiplicación (15×15 = 225) y el desplazamiento sin perder bits; en las demás operaciones se rellena con ceros a la izquierda.

    assign zero = (result == 8'd0);

Bandera zero: vale 1 cuando el resultado es cero (en el top se muestra en LEDR[8]).

*banco_registros.v*

    reg [7:0] registros [0:7];
    assign data_out = registros[addr];

Memoria de 8 registros de 8 bits. La lectura es combinacional: data_out siempre muestra el registro apuntado por addr, sin necesidad de reloj ni señal de lectura.

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            registros[0] <= 8'b0; ... registros[7] <= 8'b0;
        end else if (write_en) begin
            case (addr)
                3'b000: registros[0] <= data_in;
                ...
                3'b111: registros[7] <= data_in;
            endcase
        end
    end

La escritura es síncrona: solo en el flanco de reloj y únicamente si write_en=1, se guarda data_in en el registro que indica addr. El reset pone los 8 registros en cero.

*deboucer.v* - Anti-rebote con pulso (activo en bajo)

    if (btn_sync_1 != btn_out) begin
        if (count < COUNT_MAX) count <= count + 19'd1;
        else begin
            btn_out <= btn_sync_1;
            count   <= 19'd0;
        end
    end else count <= 19'd0;

Dos flip-flops sincronizan la entrada y un contador exige que el botón se mantenga estable 10 ms (500,000 ciclos a 50 MHz) antes de cambiar btn_out.

    btn_out_prev <= btn_out;
    btn_pulse    <= (btn_out_prev == 1'b1) && (btn_out == 1'b0);

Detector de flanco de bajada: como los botones KEY de la DE10-Lite son activos en bajo, el pulso de un ciclo se genera cuando el botón pasa de 1 a 0 (al presionarlo). Por eso el reset deja btn_out en 1.

*uart_tx.v* - Transmisor Serial UART

    localparam CLKS_PER_BIT = 13'd5208; // 50 MHz / 9600 baudios

Cada bit dura 5208 ciclos de reloj (50,000,000 / 9600), lo que fija la velocidad a 9600 baudios.

    STATE_IDLE: begin
        tx_serial <= 1'b1;
        if (tx_start) begin
            data_reg <= data_in;
            tx_busy  <= 1'b1;
            state    <= STATE_START;
        end else tx_busy <= 1'b0;
    end

En reposo la línea se mantiene en 1. Al llegar tx_start, guarda el byte a enviar en data_reg, levanta tx_busy y pasa al bit de inicio.

    STATE_START: begin
        tx_serial <= 1'b0;
        if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 13'd1;
        else begin clk_count <= 13'd0; state <= STATE_DATA; end
    end

Bit de start: pone la línea en 0 durante un tiempo de bit completo, para avisar al receptor que viene un dato.

    STATE_DATA: begin
        tx_serial <= data_reg[bit_index];
        if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 13'd1;
        else begin
            clk_count <= 13'd0;
            if (bit_index < 3'd7) bit_index <= bit_index + 3'd1;
            else begin bit_index <= 3'd0; state <= STATE_STOP; end
        end
    end

Envía los 8 bits de datos empezando por el menos significativo (bit_index va de 0 a 7), manteniendo cada bit 5208 ciclos.

    STATE_STOP: begin
        tx_serial <= 1'b1;
        ... tx_busy <= 1'b0; state <= STATE_IDLE;
    end

Bit de stop: línea en 1 por un tiempo de bit, baja tx_busy y vuelve a reposo. El formato resultante es 8N1 (8 datos, sin paridad, 1 stop).

*display_7seg.v* - Decodificador hexadecimal a 7 segmentos

    case (hex_digit)
        4'h0: seg = 7'b1000000;
        ...
        4'hA: seg = 7'b0001000;
        ...
        4'hF: seg = 7'b0001110;
    endcase

Misma tabla del laboratorio anterior (activo en bajo), pero ampliada a los 16 valores (0–F) porque ahora se muestra el resultado en hexadecimal.

*Top_lab04.v* - Integración del sistema

    wire [2:0] opcode   = GPIO[3:1];
    wire [2:0] addr     = GPIO[6:4];
    wire       write_en = GPIO[7];
    wire       read_en  = GPIO[8];

Los DIP switches externos definen la operación (opcode), el registro (addr) y los modos de escritura/lectura. Los operandos vienen de SW[3:0] (A) y SW[7:4] (B).


    wire reg_write_trigger = write_en & btn_ejecutar_pulse;
    wire [7:0] display_val = read_en ? reg_data_out : alu_result;
    wire uart_tx_trigger   = read_en & btn_ejecutar_pulse;

Control del sistema con KEY[1] como botón “Ejecutar”:

- Escribir: con write_en=1, al presionar el botón se guarda el resultado de la ALU en el registro addr.
- Mostrar: con read_en=1 los displays y LEDs muestran el registro; con read_en=0 muestran la ALU en tiempo real.
- Transmitir: con read_en=1, al presionar el botón se dispara el envío por UART.

    wire [7:0] ascii_high = (nibble_high < 4'd10) ? (8'd48 + {4'b0000, nibble_high}) : (8'd55 + {4'b0000, nibble_high});
    wire [7:0] ascii_low  = (nibble_low  < 4'd10) ? (8'd48 + {4'b0000, nibble_low})  : (8'd55 + {4'b0000, nibble_low});

Convierte cada nibble a su carácter ASCII hexadecimal: de 0 a 9 suma 48 (código de ‘0’), y de A a F suma 55 (para que 10 dé 65 = ‘A’).

    SEQ_IDLE: if (uart_tx_trigger) begin
        tx_data_reg <= ascii_high; tx_start_reg <= 1'b1; seq_state <= SEQ_HIGH_START;
    end
    SEQ_HIGH_START: if (uart_busy) seq_state <= SEQ_HIGH_WAIT;
    SEQ_HIGH_WAIT:  if (!uart_busy) begin tx_data_reg <= ascii_low; tx_start_reg <= 1'b1; seq_state <= SEQ_LOW_START; end
    ...
    SEQ_LOW_WAIT:   if (!uart_busy) begin tx_data_reg <= 8'd32; tx_start_reg <= 1'b1; seq_state <= SEQ_SPC_START; end

Máquina de estados que envía 3 caracteres seguidos: nibble alto, nibble bajo y un espacio (ej. "3F "). Para cada byte: carga el dato, pulsa tx_start, espera a que el UART se ponga ocupado (uart_busy=1) y luego espera a que termine (uart_busy=0) antes de mandar el siguiente.

    assign LEDR[7:0] = display_val;
    assign LEDR[8]   = alu_zero;
    assign LEDR[9]   = (seq_state != SEQ_IDLE) || uart_busy;

los LEDs muestran el valor actual, la bandera zero y si hay una transmisión en curso. Además, HEX2/HEX3 muestran el resultado, HEX4 la dirección y HEX5 el opcode (HEX0 y HEX1 se apagan por estar dañados).
## Esquemas y Diagramas

### Figura 1. Simulación de la transmisión UART (testbench `tb_top_lab04`)

![Simulación UART](https://github.com/user-attachments/assets/4435fc9e-a2a9-4364-a286-52edf5b33cdd)

Esta figura muestra la forma de onda del sistema completo en la ventana de 35 ms a 37 ms. Las señales relevantes son:

- **KEY[1:0] / KEY[1]:** KEY[1] es el botón "Ejecutar". Pasa de 0 a 1 cerca de los 36 ms, es decir, el botón se suelta (es activo en bajo). El pulso de ejecución sale del anti-rebote en el flanco de bajada, o sea al presionarlo.
- **GPIO[8:1] = 0x97:** configuración de los DIP switches externos. Con `GPIO[8]=1` está activo `read_en`, con `GPIO[7]=0` no se escribe, `GPIO[6:4]=010` selecciona el registro 2 y `GPIO[3:1]=111` es el opcode.
- **UART_TXD:** línea serial de salida. Se ve en reposo en 1 y los bits de start, datos y stop de cada byte, cada uno de duración constante (≈104 µs, 9600 baudios).
- **rx_byte[7:0]:** byte recibido y decodificado por el testbench a partir de `UART_TXD`. Los valores `30`, `31`, `35`, `34`, `30` y `20` en hexadecimal corresponden a los caracteres ASCII `'0'`, `'1'`, `'5'`, `'4'`, `'0'` y espacio. Esto confirma que el dato se transmite como caracteres hexadecimales ASCII seguidos de un espacio, tal como lo genera la máquina de estados del top.

### Figura 2. Simulación de la ALU de 4 bits (`u_alu`)

![Simulación ALU](https://github.com/user-attachments/assets/c26cd847-1e4f-4304-be18-131c1297a467)

Esta figura muestra las entradas y salidas de la ALU durante la prueba con los operandos **A = 7** y **B = 2**, mientras cambia el opcode:

| Opcode | Operación | Resultado esperado | Resultado en simulación |
|:---:|:---|:---:|:---:|
| `000` | Suma (7 + 2) | 9 | `09` |
| `100` | Desplazamiento A << 1 | 14 | `0E` |
| `101` | AND (7 & 2) | 2 | `02` |
| `111` | XOR (7 ^ 2) | 5 | `05` |

La bandera **zero** está en 1 al inicio, cuando el resultado es `00`, y baja a 0 cuando aparece el primer resultado distinto de cero. Como la ALU es combinacional, el resultado cambia de inmediato al modificarse A, B o el opcode, sin necesidad de reloj.

### Figura 3. Simulación del banco de registros (`u_banco`)

![Simulación banco de registros](https://github.com/user-attachments/assets/3d4792da-78ab-4ca2-804b-119c46966cfa)

Esta figura muestra el comportamiento del banco de registros de 8×8 bits:

- **rst:** pulso inicial en alto que pone los 8 registros en cero, por lo que `data_out` arranca en `00`.
- **clk:** reloj del sistema, que sincroniza la escritura.
- **data_in[7:0]:** toma sucesivamente los valores `09`, `0E`, `02` y `05`, que son los resultados de la ALU de la figura anterior y los datos que se quieren guardar.
- **addr[2:0]:** dirección del registro; pasa de `000` a `010` cerca de los 5.7 µs, y con ello se apunta al registro 2.
- **write_en:** habilita la escritura. El dato solo se almacena en el flanco de reloj en que `write_en = 1`.
- **data_out[7:0]:** valor del registro apuntado por `addr`. La lectura es combinacional, por lo que cambia apenas varía la dirección.


## Conclusiones
- La ALU realizó correctamente todas las operaciones, y el resultado de 8 bits permitió mostrar bien la multiplicación sin perder datos.
- El banco de registros guardó y leyó los valores sin problema: escritura sincronizada con el reloj y lectura inmediata según la dirección.
- El anti-rebote evitó lecturas falsas del botón y dio un solo pulso por cada pulsación.
La transmisión UART funcionó bien: los datos llegaron a la terminal en hexadecimal ASCII, gracias a la máquina de estados que envía los dos caracteres y el espacio de forma ordenada.
En general, el laboratorio integró ALU, memoria, comunicación serial y visualización en un solo diseño funcional al 100%.



