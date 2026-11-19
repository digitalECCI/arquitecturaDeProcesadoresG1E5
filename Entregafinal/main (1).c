/*
 *  PicoSoC Shell - DE10-Lite (MAX10, 50 MHz)  -- version compacta
 *  Comandos: help led leds sw blink calc rick
 */
#pragma GCC optimize ("Os")
#include <stdint.h>

/* ---------------- Mapa de memoria ---------------- */
#define REG_UART_CLK  (*(volatile uint32_t *)0x02000004)
#define REG_UART_DATA (*(volatile uint32_t *)0x02000008)
#define REG_LEDS      (*(volatile uint32_t *)0x03000000)
#define REG_SWITCHES  (*(volatile uint32_t *)0x03000004)

#define CLK_FREQ   50000000
#define BAUD_RATE  115200

static const char url[] = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";

/* Buffers estaticos (la RAM es chica: no usar la pila para esto) */
static char  line[24];
static char *av[4];
static int   ac;

/* ---------------- UART ---------------- */
static void putc_(char c)      { REG_UART_DATA = (uint8_t)c; }
static int  getc_nb(void)      { return (int)REG_UART_DATA; }   /* -1 si no hay dato */
static void puts_(const char *s) { while (*s) putc_(*s++); }

static void put_bin(uint32_t v, int bits) {
    while (bits--) putc_(((v >> bits) & 1) ? '1' : '0');
}

/* decimal sin buffer en la pila */
static void put_dec(int v) {
    unsigned u = (unsigned)v, d = 1000000000u, q;
    int started = 0;
    if (v < 0) { putc_('-'); u = 0u - u; }
    for (; d; d /= 10) {
        q = u / d;
        u %= d;
        if (q || started || d == 1) { putc_('0' + q); started = 1; }
    }
}

/* ---------------- Utilidades ---------------- */
static int eq(const char *a, const char *b) {
    while (*a && *a == *b) { a++; b++; }
    return *a == *b;
}

/* decimal (con signo) o hexadecimal 0x... */
static int num(const char *s, int *ok) {
    int neg = 0, v = 0, base = 10, d, c;
    if (*s == '-') { neg = 1; s++; }
    if (s[0] == '0' && (s[1] | 32) == 'x') { base = 16; s += 2; }
    *ok = (*s != 0);
    for (; *s; s++) {
        c = *s | 32;
        if      (*s <= '9') d = *s - '0';
        else if (c >= 'a')  d = c - 'a' + 10;
        else                d = -1;
        if (d < 0 || d >= base) { *ok = 0; return 0; }
        v = v * base + d;
    }
    return neg ? -v : v;
}

static void tok(void) {
    char *p = line;
    ac = 0;
    while (*p) {
        while (*p == ' ') p++;
        if (!*p) break;
        if (ac < 4) av[ac++] = p;
        while (*p && *p != ' ') p++;
        if (*p) *p++ = 0;
    }
}

static void delay(uint32_t n) {
    volatile uint32_t i;
    for (i = 0; i < n; i++);
}

/* ---------------- Comandos ---------------- */
static void c_help(void) {
    puts_("help\r\n"
          "led <n> <on|off>\r\n"
          "leds <valor>\r\n"
          "sw\r\n"
          "blink <n> <veces>\r\n"
          "calc <a> <op> <b>\r\n"
          "rick\r\n");
}

/* led <n> <on|off> */
static void c_led(void) {
    int ok, n;
    if (ac < 3) { puts_("uso: led <0-3> <on|off>\r\n"); return; }
    n = num(av[1], &ok);
    if (!ok || n < 0 || n > 3) { puts_("LED invalido (0-3)\r\n"); return; }
    if      (eq(av[2], "on"))  REG_LEDS |=  (1u << n);
    else if (eq(av[2], "off")) REG_LEDS &= ~(1u << n);
    else { puts_("usa on/off\r\n"); return; }
    puts_("ok\r\n");
}

/* leds <valor>: leds 0xAA, leds 5 (se usan los 4 bits bajos) */
static void c_leds(void) {
    int ok, v;
    if (ac < 2) { puts_("uso: leds <valor>\r\n"); return; }
    v = num(av[1], &ok);
    if (!ok || v < 0 || v > 255) { puts_("valor invalido (0-255)\r\n"); return; }
    REG_LEDS = v & 15;
    puts_("ok\r\n");
}

/* sw */
static void c_sw(void) {
    puts_("switches = 0b");
    put_bin(REG_SWITCHES, 4);
    puts_("\r\n");
}

/* blink <n> <veces> */
static void c_blink(void) {
    int ok1, ok2, n, k;
    uint32_t prev, m;
    if (ac < 3) { puts_("uso: blink <n> <veces>\r\n"); return; }
    n = num(av[1], &ok1);
    k = num(av[2], &ok2);
    if (!ok1 || n < 0 || n > 3)  { puts_("LED invalido (0-3)\r\n"); return; }
    if (!ok2 || k < 1 || k > 20) { puts_("veces invalido (1-20)\r\n"); return; }
    prev = REG_LEDS;
    m = 1u << n;
    while (k--) {
        REG_LEDS = prev | m;  delay(200000);
        REG_LEDS = prev & ~m; delay(200000);
    }
    REG_LEDS = prev;
    puts_("ok\r\n");
}

/* calc <a> <op> <b> */
static void c_calc(void) {
    int ok1, ok2, a, b, r;
    char op;
    if (ac < 4) { puts_("uso: calc <a> <op> <b>\r\n"); return; }
    a = num(av[1], &ok1);
    b = num(av[3], &ok2);
    if (!ok1 || !ok2) { puts_("numeros invalidos\r\n"); return; }
    op = av[2][0];
    if      (op == '+') r = a + b;
    else if (op == '-') r = a - b;
    else if (op == '*') r = a * b;
    else if (op == '/') {
        if (!b) { puts_("division por cero\r\n"); return; }
        r = a / b;
    }
    else { puts_("operador invalido\r\n"); return; }
    put_dec(a); putc_(' '); putc_(op); putc_(' ');
    put_dec(b); puts_(" = "); put_dec(r); puts_("\r\n");
}

/* ---------------------------------------------------------------
 *  Comando propio: rick
 *  Retrato ASCII animado (48x20) calculado en tiempo real:
 *  fondo de ruido ($3529#8B), cabeza oscura con pelo, ojos que
 *  parpadean, boca que se abre y cierra, cuerpo y camisa.
 *  La cabeza se balancea. LEDs en barrido "auto fantastico".
 *  Cualquier tecla sale y muestra el link.
 * --------------------------------------------------------------- */
#define RK_W 48
#define RK_H 20

static char px(int x, int y, int f) {
    uint32_t h = ((uint32_t)(x * 7919) ^ (uint32_t)(y * 104729)
                  ^ (uint32_t)(f * 1299709)) * 2654435761u;
    int a  = (int)(h >> 29);                 /* ruido 0..7            */
    int s  = (f >> 1) & 7;
    int hx, dy = y - 8, ax;
    if (s > 4) s = 8 - s;                    /* balanceo 0..4         */
    hx = x - 22 - s;
    ax = hx < 0 ? -hx : hx;

    if (9 * hx * hx + 25 * dy * dy < 900) {              /* cabeza    */
        if (dy < -1) return " .:."[a & 3];               /* pelo      */
        if (ax >= 3 && ax <= 5) {
            if (dy == -1) return '=';                    /* cejas     */
            if (dy == 0)  return ((f & 15) == 15) ? '-'  /* ojos      */
                                 : (ax == 4 ? 'O' : '.');
        }
        if (dy == 2 && ax <= 1) return '7';              /* nariz     */
        if (dy == 4 && ax <= 3) return (f & 4) ? 'O' : '-'; /* boca   */
        return "1[(7=)1("[a];                            /* cara      */
    }
    if (y >= 14 && ax <= 5 + (y - 14) * 3)               /* cuerpo    */
        return (ax <= 1) ? "[]"[a & 1] : " .:."[a & 3];
    return "$3529#8B"[a];                                /* fondo     */
}

static void c_rick(void) {
    static const char *const ly[4] = {
        "Never gonna give you up",
        "Never gonna let you down",
        "Never gonna run around",
        "and desert you"
    };
    int f = 0, x, y, k;
    uint32_t prev = REG_LEDS;

    while (getc_nb() >= 0);                  /* vacia la entrada      */
    puts_("\x1b[2J\x1b[?25l");               /* limpia, oculta cursor */
    do {
        puts_("\x1b[H");                     /* cursor al inicio      */
        for (y = 0; y < RK_H; y++) {
            for (x = 0; x < RK_W; x++) putc_(px(x, y, f));
            puts_("\r\n");
        }
        puts_(ly[(f >> 3) & 3]);
        puts_("\x1b[K\r\n[tecla = salir] ");
        puts_(url);
        puts_("\x1b[K");

        k = f & 7;                           /* LEDs 0,1,2,3,3,2,1,0 */
        if (k > 3) k = 7 - k;
        REG_LEDS = 1u << k;
        f++;
    } while (getc_nb() < 0);

    REG_LEDS = prev;
    puts_("\x1b[2J\x1b[H\x1b[?25h");
    puts_("Te hicimos rickroll :)\r\n");
    puts_(url);
    puts_("\r\n");
}

/* ---------------- Shell ---------------- */
static void readline(void) {
    unsigned i = 0;
    int c;
    for (;;) {
        c = getc_nb();
        if (c < 0) continue;
        if (c == '\r' || c == '\n') { puts_("\r\n"); line[i] = 0; return; }
        if (c == 8 || c == 127) {
            if (i) { i--; puts_("\b \b"); }
        } else if (c >= 32 && c < 127 && i < sizeof(line) - 1) {
            line[i++] = (char)c;
            putc_((char)c);
        }
    }
}

int main(void) {
    REG_UART_CLK = CLK_FREQ / BAUD_RATE;
    REG_LEDS = 0;

    puts_("\r\n== picoSoC Shell ==\r\nescribe help\r\n");

    for (;;) {
        puts_("> ");
        readline();
        tok();
        if (!ac) continue;

        if      (eq(av[0], "help"))  c_help();
        else if (eq(av[0], "led"))   c_led();
        else if (eq(av[0], "leds"))  c_leds();
        else if (eq(av[0], "sw"))    c_sw();
        else if (eq(av[0], "blink")) c_blink();
        else if (eq(av[0], "calc"))  c_calc();
        else if (eq(av[0], "rick"))  c_rick();
        else puts_("comando desconocido (help)\r\n");
    }
}