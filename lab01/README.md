        
# Lab01 - Sumador/Restador de 4 bits

## Integrantes
* [Pedro Felipe Jimenez Celis](https://github.compedrofejimenezce-ship-it) 
* [Laura Alejandra Fuentes Ubaque](https://github.com/lauAlejandrxf) 
* [Sebastian Buitrago Oliveros](https://github.com/SebastianBuitrago16) 

## Descripcion de Codigo

Sumador 1b
    module sumador1b(
        input A,
        input B,
        input Ci,
        output S,
        output Co
    );
Define un sumador completo de 1 bit con tres entradas (A, B y Ci, el acarreo de entrada) y dos salidas (S, la suma, y Co, el acarreo de salida).

    wire ab_xor;   // A xor B
    wire and1;     // A & B
    wire and2;     // A & Ci
    wire and3;     // B & Ci
    wire or1;      // and1 | and2
Son cables intermedios que almacenan resultados parciales, necesarios porque las compuertas primitivas de Verilog no permiten anidar operaciones directamente.

    xor(ab_xor, A, B);
    xor(S, ab_xor, Ci);

Calcula S = A ⊕ B ⊕ Ci en dos pasos: primero A xor B, y luego ese resultado en xor con Ci. Esta es la ecuación booleana clásica de la suma en un full adder.

    and(and1, A, B);
    and(and2, A, Ci);
    and(and3, B, Ci);
    or(or1, and1, and2);
    or(Co, or1, and3);
Calcula Co = (A·B) + (A·Ci) + (B·Ci), es decir, el acarreo se genera si al menos dos de las tres entradas están en 1. Se obtiene con tres AND (uno por cada par de entradas) y dos OR en cadena para sumarlos.

    endmodule
Termina la definición del módulo.

Sumador 4bits

    sumador1b bit0(
        .A(A[0]),
        .B(B[0]),
        .Ci(Ci),
        .S(S[0]),
        .Co(c1)
    );
Es la primera instancia del sumador de 1 bit. Se conecta a los bits menos significativos (A[0], B[0]) y al acarreo de entrada externo Ci. Su salida de acarreo Co se asigna a la señal interna c1, que servirá de entrada para la siguiente instancia.

    sumador1b bit1(
        .A(A[1]),
        .B(B[1]),
        .Ci(c1),
        .S(S[1]),
        .Co(c2)
    );
Segunda instancia. Recibe como acarreo de entrada (Ci) el acarreo c1 generado por la instancia bit0. Genera el acarreo c2 para la siguiente etapa.

    sumador1b bit2(
        .A(A[2]),
        .B(B[2]),
        .Ci(c2),
        .S(S[2]),
        .Co(c3)
    );
Tercera instancia. Toma el acarreo c2 de la instancia anterior (bit1) y produce el acarreo c3 hacia la última etapa.

    sumador1b bit3(
        .A(A[3]),
        .B(B[3]),
        .Ci(c3),
        .S(S[3]),
        .Co(Co)
    );
Cuarta y última instancia. Recibe el acarreo c3 de bit2, y su salida de acarreo se conecta directamente a Co, el acarreo final del módulo sumador4b.

Están encadenadas entre sí porque el acarreo de salida de una instancia se conecta como acarreo de entrada de la siguiente, formando así el sumador completo de 4 bits.

Sumador Restador 4bits

    module sumadorRestador4b(
        input  [3:0] A,
        input  [3:0] B,
        input        Sel,
        output [3:0] S,
        output       Co,
        output       Neg
    );
Define el módulo con dos operandos de 4 bits (A, B), una señal de selección (Sel: 0 = suma, 1 = resta), la magnitud del resultado (S), el acarreo crudo (Co) y la bandera de signo (Neg).

    wire [3:0] B_xor;
    wire [3:0] S_raw;
    wire [3:0] S_inv;
B_xor: B (posiblemente invertido) que entra al sumador. S_raw: resultado crudo del sumador (puede estar en complemento a 2 si es negativo). S_inv: versión invertida de S_raw, usada para recuperar la magnitud.

    xor(B_xor[0], B[0], Sel);
    xor(B_xor[1], B[1], Sel);
    xor(B_xor[2], B[2], Sel);
    xor(B_xor[3], B[3], Sel);
Invierte cada bit de B solo si Sel=1. Es el primer paso para convertir la resta en una suma por complemento a 2.

    sumador4b uut(
        .A(A),
        .B(B_xor),
        .Ci(Sel),
        .S(S_raw),
        .Co(Co)
    );
Suma A + B_xor, usando Sel como acarreo de entrada. Si Sel=1, esto completa el complemento a 2 de B (invertir + sumar 1), realizando así A - B. El resultado (crudo) queda en S_raw, y su acarreo en Co.

    wire not_co;
    not(not_co, Co);
    and(Neg, Sel, not_co);
Neg=1 únicamente si se está restando (Sel=1) y el acarreo de salida fue 0 (Co=0), lo cual indica que el resultado es negativo (en complemento a 2).

    xor(S_inv[0], S_raw[0], Neg);
    xor(S_inv[1], S_raw[1], Neg);
    xor(S_inv[2], S_raw[2], Neg);
    xor(S_inv[3], S_raw[3], Neg);
Invierte cada bit de S_raw solo si Neg=1. Primer paso para "deshacer" el complemento a 2 y obtener la magnitud real.

    sumador4b mag(
        .A(S_inv),
        .B(4'b0000),
        .Ci(Neg),
        .S(S),
        .Co()
    );
Suma S_inv + 0000, usando Neg como acarreo de entrada. Si Neg=1, esto suma 1 y completa el complemento a 2, dando la magnitud positiva del resultado negativo. El acarreo de esta instancia no se usa.

Top Level

    module top_sumadorRestador4b(
        input  [8:0] SW,
        output [4:0] LED
    );
Es el módulo de más alto nivel ("top"), pensado para mapear directamente a los switches (SW) y LEDs físicos de una placa FPGA. Agrupa las entradas en un solo bus de 9 bits y las salidas en un bus de 5 bits.

    sumadorRestador4b uut(
        .A(SW[3:0]),
        .B(SW[7:4]),
        .Sel(SW[8]),
        .S(LED[3:0]),
        .Co(),       
        .Neg(LED[4])
    );
Conecta SW[3:0] a A, SW[7:4] a B y SW[8] a Sel. La salida S se conecta a LED[3:0] (magnitud) y Neg a LED[4] (signo). El puerto Co queda sin conectar, ya que en este nivel no interesa el acarreo crudo del sumador interno, sino solo si el resultado final es negativo.
# Integrantes
* [<!-- Remplace aqui nombre 1. -->](<!-- Remplace aqui link de usario 1 de github -->) 
* [<!-- Remplace aqui nombre 2. -->](<!-- Remplace aqui link de usario 2 de github -->) 
* [<!-- Remplace aqui nombre 3. -->](<!-- Remplace aqui link de usario 3 de github -->) 
# Informe

Indice:

1. [Documentación](#documentación-de-los-circuitos-implementados-implementado)
2. [Simulaciones](#simulaciones)
3. [Evidencias de implementación](#evidencias-de-implementación)
4. [Preguntas](#preguntas)
5. [Conclusiones](#conclusiones)
6. [Referencias](#referencias)

## Documentación del diseño implementado

### 1. Sumador/Restador

#### 1.1 Descripción

#### 1.2 Diagramas


## Simulaciones 

### 1. Simulación del sumador/restador

#### 1.1 Descripción

#### 1.2 Diagrama


## Evidencias de implementación


## Conclusiones


## Referencias

