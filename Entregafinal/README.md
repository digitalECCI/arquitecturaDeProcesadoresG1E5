## Lab Entrega Final 

## Integrantes
* [Pedro Felipe Jimenez Celis](https://github.compedrofejimenezce-ship-it) 
* [Laura Alejandra Fuentes Ubaque](https://github.com/lauAlejandrxf) 
* [Sebastian Buitrago Oliveros](https://github.com/SebastianBuitrago16) 

## Introducción
En este laboratorio se programó en C un shell por UART que corre sobre un procesador PicoSoC dentro de la FPGA DE10-Lite. Desde una terminal en el computador se escriben comandos para controlar los LEDs, leer los switches, hacer parpadear un LED, usar una calculadora y ver una animación ASCII, todo accediendo al hardware por registros mapeados en memoria.
## Explicación de codigo

*Mapa de memoria y UART*

    #define REG_UART_CLK  (*(volatile uint32_t *)0x02000004)
    #define REG_UART_DATA (*(volatile uint32_t *)0x02000008)
    #define REG_LEDS      (*(volatile uint32_t *)0x03000000)
    #define REG_SWITCHES  (*(volatile uint32_t *)0x03000004)

El procesador (PicoRV32) controla el hardware por memoria mapeada: escribir o leer en esas direcciones equivale a hablar con la UART, los LEDs y los switches. volatile obliga al compilador a hacer cada acceso de verdad (sin optimizarlo).

    static void putc_(char c)    { REG_UART_DATA = (uint8_t)c; }
    static int  getc_nb(void)    { return (int)REG_UART_DATA; }   /* -1 si no hay dato */
    static void puts_(const char *s) { while (*s) putc_(*s++); }

Enviar un carácter es escribir en REG_UART_DATA; recibir es leerlo (devuelve -1 si no llegó nada, por eso es “no bloqueante”). puts_ manda un string carácter por carácter.

    REG_UART_CLK = CLK_FREQ / BAUD_RATE;   // 50 MHz / 115200

En main se configura el divisor del reloj para que la UART trabaje a 115200 baudios.

*Lectura de comandos (shell)*

    static void readline(void) {
        ...
        if (c == '\r' || c == '\n') { puts_("\r\n"); line[i] = 0; return; }
        if (c == 8 || c == 127) { if (i) { i--; puts_("\b \b"); } }
        else if (c >= 32 && c < 127 && i < sizeof(line) - 1) { line[i++] = (char)c; putc_((char)c); }
    }

Lee lo que escribes en la terminal: guarda cada carácter imprimible en line (y lo muestra como eco), maneja la tecla de borrar (\b \b borra el carácter en pantalla) y termina al presionar Enter.

    static void tok(void) {
        ...
        if (ac < 4) av[ac++] = p;
        while (*p && *p != ' ') p++;
        if (*p) *p++ = 0;
    }

Divide la línea en palabras (como argc/argv): reemplaza los espacios por \0 y guarda en av[] el inicio de cada palabra, con ac como cantidad.

    for (;;) {
        puts_("> ");
        readline();
        tok();
        if (!ac) continue;
        if      (eq(av[0], "help"))  c_help();
        else if (eq(av[0], "led"))   c_led();
        ...
    }

Bucle principal: muestra el prompt, lee la línea, la separa en palabras y compara la primera con cada comando (con eq, una comparación de strings propia) para llamar a su función.

*Conversión de números*

    static int num(const char *s, int *ok) {
        ...
        if (s[0] == '0' && (s[1] | 32) == 'x') { base = 16; s += 2; }
        ...
        v = v * base + d;
    }

Convierte texto a entero, aceptando signo, decimal y hexadecimal (0x...). Si encuentra un carácter inválido pone *ok = 0. Cada dígito se acumula con v = v*base + d.

    static void put_dec(int v) {
        unsigned u = (unsigned)v, d = 1000000000u, q;
        ...
        for (; d; d /= 10) {
            q = u / d;  u %= d;
            if (q || started || d == 1) { putc_('0' + q); started = 1; }
        }
    }

Imprime un entero en decimal sin usar printf ni buffer: divide entre potencias de 10 (de mil millones hacia abajo) e imprime cada dígito, saltando los ceros a la izquierda con started.

*Comandos de LES's y switches*

    if      (eq(av[2], "on"))  REG_LEDS |=  (1u << n);
    else if (eq(av[2], "off")) REG_LEDS &= ~(1u << n);

led <n> <on|off>: usa máscaras de bits para encender (OR) o apagar (AND con negado) solo el LED n, sin tocar los demás.

    REG_LEDS = v & 15;

leds <valor>: escribe el valor directo, quedándose con los 4 bits bajos (hay 4 LEDs disponibles).

    put_bin(REG_SWITCHES, 4);

sw: lee los switches y los imprime en binario (4 bits).

    prev = REG_LEDS;
    m = 1u << n;
    while (k--) {
        REG_LEDS = prev | m;  delay(200000);
        REG_LEDS = prev & ~m; delay(200000);
    }
    REG_LEDS = prev;

blink <n> <veces>: guarda el estado anterior de los LEDs, alterna el LED n con retardos por software (delay cuenta en un ciclo) y al final restaura el estado original.

*Calculadora*

    op = av[2][0];
    if      (op == '+') r = a + b;
    else if (op == '-') r = a - b;
    else if (op == '*') r = a * b;
    else if (op == '/') { if (!b) { puts_("division por cero\r\n"); return; } r = a / b; }

calc <a> <op> <b>: convierte los dos números, elige la operación según el carácter, valida la división entre cero e imprime a op b = r.

*Comando rick (animación ASCII)*

    static char px(int x, int y, int f) {
        uint32_t h = ((uint32_t)(x * 7919) ^ (uint32_t)(y * 104729) ^ (uint32_t)(f * 1299709)) * 2654435761u;
        int a = (int)(h >> 29);   /* ruido 0..7 */
        ...
        if (9 * hx * hx + 25 * dy * dy < 900) { ... }   /* cabeza (elipse) */
        ...
        return "$3529#8B"[a];                            /* fondo */
    }

Calcula qué carácter va en cada posición (x, y) del cuadro f. Un hash da un número pseudoaleatorio (ruido) para el fondo. La cabeza se dibuja con la ecuación de una elipse; dentro de ella se ponen pelo, cejas, ojos (parpadean cuando f & 15 == 15), nariz y boca (se abre y cierra con f & 4). El balanceo viene de s, que desplaza la cabeza según el cuadro.

    puts_("\x1b[2J\x1b[?25l");   /* limpia pantalla y oculta cursor */
    do {
        puts_("\x1b[H");          /* cursor al inicio */
        for (y...) for (x...) putc_(px(x, y, f));
        puts_(ly[(f >> 3) & 3]);  /* letra de la canción */
        k = f & 7; if (k > 3) k = 7 - k;
        REG_LEDS = 1u << k;       /* barrido de LEDs */
        f++;
    } while (getc_nb() < 0);

Usa secuencias de escape ANSI para redibujar siempre en el mismo lugar de la terminal. En cada vuelta dibuja el cuadro de 48×20, muestra una línea de la letra, hace el barrido de LEDs (0,1,2,3,3,2,1,0) y sigue hasta que se presione cualquier tecla; al salir restaura los LEDs, limpia la pantalla y muestra el link.

## Esquemas y Diagramas

### 1. Simulación del shell en terminal (testbench `tb_shell.v`)

![Salida de la simulación en terminal](https://github.com/user-attachments/assets/4016439d-d7e9-4507-be00-7f8212026f64)

Salida de la consola al simular el PicoSoC con el testbench `tb_shell.v`. El testbench envía comandos por la línea `rx` y muestra lo que el shell responde por `tx`:

- `sw` → el shell imprime `switches = 0b0101`, que coincide con `sw[3:0] = 5` de la simulación.
- `led 1 on` → responde `ok`, y el testbench comprueba `led = 0010 (esperado 0010)`.
- `leds 0xAA` → responde `ok`. Como solo se conservan los 4 bits bajos (`0xAA & 15 = 0xA`), el testbench verifica `led = 1010 (esperado 1010)`.
- `calc 6 * 7` → responde `6 * 7 = 42`.
- `help` → lista todos los comandos disponibles.
- Al final el testbench imprime `[TB] fin` y llama a `$finish` (≈ 42.97 ms simulados).

Con esto se comprueba que el shell recibe, interpreta y responde correctamente cada comando.

### 2. Formas de onda completas (GTKWave)

![Formas de onda de toda la simulación](https://github.com/user-attachments/assets/86fbdd62-1a59-44e8-96d6-c139d422459f)

Vista general de los 0 a ~42 ms de simulación en GTKWave. Señales principales:

- `clk`: reloj del sistema.
- `rx`: línea de entrada de la UART. Cada ráfaga es un comando enviado por el testbench; en orden: `sw`, `led 1 on`, `leds 0xAA`, `calc 6 * 7` y `help`.
- `tx`: línea de salida de la UART. Tras cada ráfaga de `rx` aparece la respuesta del shell (eco, resultado y prompt). La actividad más larga, cerca de 31–40 ms, corresponde a la lista de `help`.
- `sw[3:0]`: se mantiene en `5` (`0101`) durante toda la simulación.
- `led[3:0]` y `gpio[31:0]`: pasan de `0` a `2` (`0000_0002`) cuando se ejecuta `led 1 on`, y luego a `A` (`0000_000A`) con `leds 0xAA`. Entre comandos no cambian.
- `b[7:0]` e `i`: byte e índice de bit que maneja el testbench mientras envía y recibe por UART (`i = 8` indica el fin del byte, `20` es el espacio).

### 3. Detalle del comando `led 1 on` (zoom 12–13 ms)

![Zoom a la transmisión UART del comando led 1 on](https://github.com/user-attachments/assets/a7618367-74be-4596-a01d-2f82b96d1fe8)

Acercamiento a la ejecución de `led 1 on`. Cada ráfaga de `rx` y `tx` es una trama UART a 115200 baudios (inicio, 8 bits de datos y parada), y `b[7:0]` muestra el byte en ASCII:

| Bytes | ASCII | Significado |
|---|---|---|
| `6C 65 64` | `l e d` | comando `led` |
| `20 31 20` | ` 1 ` | espacio, LED número 1, espacio |
| `6F 6E` | `o n` | argumento `on` |
| `0D 0A` | `\r\n` | Enter: fin de la línea |
| `6F 6B 0D 0A` | `o k \r \n` | respuesta `ok` del shell |
| `3E 20` | `> ` | nuevo prompt |

Después del Enter (`0D 0A`), `led[3:0]` y `gpio` cambian a `2`, es decir, el LED 1 se enciende. Solo entonces el shell transmite `ok` y el prompt.

## Video



## Conclusiones
- El shell funcionó correctamente: recibió, separó e interpretó cada comando, y respondió por la UART a 115200 baudios.
- El acceso a LEDs y switches mediante memoria mapeada permitió controlar el hardware directamente desde C, usando máscaras de bits para no afectar los demás LEDs.
- La calculadora y las funciones de conversión (num, put_dec) trabajaron bien sin printf, lo cual ahorró memoria en un sistema con poca RAM.
- El comando rick mostró que el procesador puede generar animación en tiempo real, usando secuencias ANSI y calculando cada cuadro al vuelo.
En general, el laboratorio integró hardware y software en un sistema embebido funcional al 100%.
