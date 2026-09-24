# Especificación de Rackituq

Versión 1, 23 de septiembre de 2026.

Este documento define el lenguaje Rackituq: su léxico, su gramática, su
semántica, sus tipos y sus errores. Está escrito siguiendo la estructura de
las normas de lenguajes de programación (alcance, conformidad, elementos
léxicos, gramática, semántica, biblioteca, diagnósticos), y la gramática usa
la notación **EBNF de ISO/IEC 14977**.

Todo lo que dice acá está comprobado corriendo el código: las pruebas de
[pruebas.rkt](pruebas.rkt) son el conjunto de pruebas de conformidad.

---

## 1. Alcance

Rackituq es un lenguaje **aglutinante**: el programa se escribe pegando
morfemas a una raíz, como en kalaallisut (groenlandés). Una palabra sola puede
ser un programa completo.

```
1,2,3,4,5,6.solo:par.cada:por:10.suma
```

## 2. Conformidad

Una implementación es **conforme** si:

1. Acepta todo programa que siga la gramática de la sección 4.
2. Lo evalúa según la semántica de la sección 5.
3. Usa los tipos y la aritmética de la sección 6.
4. Informa los errores de la sección 7 con la forma allí definida.
5. Pasa las pruebas de `pruebas.rkt`.

Un programa es **conforme** si sigue la gramática y no depende de nada
marcado en la sección 8 como *definido por la implementación*.

## 3. Elementos léxicos

### 3.1 Caracteres

El texto del programa es Unicode. Los nombres aceptan acentos y eñes:
`año.mas:1` es válido.

### 3.2 Caracteres con significado propio

| Carácter | Papel |
|---|---|
| `.` | separa morfemas; entre dos dígitos es el punto decimal |
| `:` | separa un morfema de sus complementos |
| `,` | separa los elementos de una lista |
| `"` | abre y cierra un texto |
| `( )` | encierran una sub-palabra |
| espacio | separa las palabras de una oración |
| `?` `-guni` `-gaangat` | modos, al final de la palabra |
| `$` | encabeza los huecos de un sufijo: `$0`, `$1` |
| `;;` | al principio de una línea, comentario |

### 3.3 Palabras reservadas

No pueden ser el nombre de una variable, porque el lenguaje las usa para sí
mismo y la variable quedaría inalcanzable:

| Reservada | Para qué |
|---|---|
| `sí`, `no` | los dos valores booleanos |
| `sino` | separa las ramas de un condicional |
| `esto` | el valor que llega a una cadena entre paréntesis |
| `otro` | el valor que la acompaña (segundo operando de `junta:`, mensaje de error en `intenta:`) |
| `$0`, `$1`, `$2`, … | el valor y los complementos de un sufijo |

Usarlas como nombre es un error (§7). El lenguaje sí las ata por dentro.

Los nombres de morfema **no** son reservados: se puede tener una variable
llamada `mas`. En posición de raíz gana la variable; en posición de morfema
gana el diccionario.

## 4. Gramática (EBNF, ISO/IEC 14977)

```ebnf
(* --- Programa --- *)
programa        = { línea } ;
línea           = comentario | oración | comando ;
comentario      = ";;" , { carácter } ;

(* --- Oración --- *)
oración         = grupo , { espacio , grupo } ;
grupo           = palabra , { espacio , argumento } ;
argumento       = número | texto | lista | identificador ;

(* --- Palabra --- *)
palabra         = cuerpo , [ modo ] ;
modo            = "?" | "-guni" | "-gaangat" ;
cuerpo          = raíz , { "." , morfema }
                | "." , morfema , { "." , morfema } ;
raíz            = valor | identificador | sub-palabra ;

(* --- Morfema --- *)
morfema         = nombre-morfema , { ":" , complemento } ;
nombre-morfema  = identificador , { "." , identificador } ;
complemento     = valor | identificador | nombre-morfema
                | sub-palabra | hueco ;
sub-palabra     = "(" , ( palabra | cadena ) , ")" ;
cadena          = morfema , { "." , morfema } ;
hueco           = "$" , entero ;

(* --- Valores --- *)
valor           = número | texto | lista | booleano ;
número          = [ "-" ] , entero , [ "." , entero ] ;
entero          = dígito , { dígito } ;
texto           = '"' , { carácter - '"' } , '"' ;
lista           = elemento-lista , "," , elemento-lista ,
                  { "," , elemento-lista } ;
elemento-lista  = número | texto ;
booleano        = "sí" | "no" ;

(* --- Nombres --- *)
identificador   = carácter-nombre , { carácter-nombre } ;
carácter-nombre = ? cualquier carácter que no sea
                    "." ":" "," '"' "(" ")" ni espacio ? ;

(* --- Comandos especiales --- *)
comando         = nombre-comando , { espacio , argumento } ;
nombre-comando  = "definir.variable" | "definir.variable.tipo"
                | "definir.sufijo" | "definir.funcion"
                | "definir.funcion.recursiva" | "actualizar.variable"
                | "si" | "mientras" | "importar.modulo"
                | "exportar.modulo" | "mostrar.salida" | "leer.input"
                | "mem.limpiar" | "explicar" | "correr" ;

espacio         = " " , { " " } ;
dígito          = "0" | "1" | "2" | "3" | "4"
                | "5" | "6" | "7" | "8" | "9" ;
```

Un `identificador` no puede ser una palabra reservada (§3.3).

### 4.1 Regla de la coincidencia más larga

La gramática no alcanza para decidir dónde termina un nombre de morfema,
porque hay nombres con punto adentro (`sub.lista`, `sum.ar`). La regla léxica
que lo resuelve, equivalente al *maximal munch* de otros lenguajes, es:

1. El cuerpo se parte por los puntos, sin mirar dentro de comillas ni de
   paréntesis, y sin partir el punto decimal de un número.
2. De izquierda a derecha, se unen las piezas consecutivas que juntas formen
   **el nombre más largo que exista en el diccionario**; solo la última pieza
   del grupo puede llevar complementos.
3. Si ninguna unión da un nombre conocido, la pieza queda sola.

Así `lista1.sub.lista` se lee `lista1` + `sub.lista`, y nunca `lista1` +
`sub` + `lista`. Como la búsqueda es exacta y prefiere lo más largo, **ningún
morfema puede tapar a otro**: el orden en que se definieron no influye.

## 5. Semántica

### 5.1 La palabra es una tubería

La raíz da el valor inicial y cada morfema transforma el resultado del
anterior, de izquierda a derecha. `5.mas:3.por:2` es `(5 + 3) × 2 = 16`.

### 5.2 De dónde sale el valor inicial

En orden:

1. Si la palabra se evalúa con una entrada dada (el cuerpo de un sufijo, una
   cadena aplicada a un valor), esa entrada es el valor inicial.
2. Si la raíz es un literal o una variable existente, su valor.
3. Si no, el primero de los argumentos que siguen a la palabra, y los demás
   pasan a ser complementos del primer morfema: `x.sum.ar 2 3` = `2.sum.ar:3`.
4. Si el cuerpo empieza con punto (`.mem.limpiar`), no hay valor inicial.
5. Si nada de lo anterior aplica, es un error (§7).

### 5.3 Modos

El modo va pegado al final de la palabra y decide qué pasa con la oración:

| Modo | Origen | Efecto |
|---|---|---|
| *(ninguno)* | — | la palabra vale por su resultado |
| `?` | pregunta | el resultado se lee como `sí` o `no` |
| `-guni` | kalaallisut *-guni*, "si…" | el resto de la oración se evalúa solo si el resultado es cierto; `sino` marca la otra rama |
| `-gaangat` | kalaallisut *-gaangat*, "cada vez que…" | el resto se repite mientras el resultado sea cierto |

Una palabra con modo cierra su grupo: lo que sigue es otra palabra, no un
argumento suyo.

### 5.4 Oraciones

Una oración es una secuencia de palabras separadas por espacios. Se evalúan en
orden y el valor de la oración es el de la última palabra evaluada. Un token
sin punto, o un número o texto, es argumento de la palabra anterior.

### 5.5 Ámbitos

- Arriba, las variables son globales.
- Cada llamada a un sufijo abre un ámbito propio.
- Un nombre se busca de adentro hacia afuera.
- `en:` guarda **en el ámbito actual**; `global:` guarda en el global.
- Dentro de una cadena entre paréntesis están atados `esto` y `otro`.
- Dentro del cuerpo de un sufijo están atados `$0` (el valor que llega) y
  `$1`, `$2`, … (sus complementos).

### 5.6 Sufijos definidos en el lenguaje

`definir.sufijo <nombre> <cuerpo>`. El cuerpo es:

- una **cadena** de morfemas, si arranca con un morfema conocido (`mas:$1`);
  se aplica al valor que recibe el sufijo;
- una **oración completa**, si arranca con cualquier otra cosa (una raíz, una
  variable o `$0`); puede llevar modos y llamarse a sí misma, que es como se
  escribe la recursión.

### 5.7 Orden de evaluación

Los complementos se evalúan antes de aplicar el morfema, de izquierda a
derecha. Las dos excepciones son `y` y `o`, que son de corto circuito, y
`intenta:`, que evalúa su respaldo solo si el primer intento falla.

## 6. Tipos y aritmética

Siguiendo el espíritu de ISO/IEC 11404 (tipos independientes del lenguaje) e
ISO/IEC 10967 (aritmética), esto es lo que hay:

| Tipo | Qué es | Cómo se escribe |
|---|---|---|
| `numero` | entero, racional exacto o decimal | `5`, `-3`, `3.5`, `1/3` |
| `texto` | cadena de caracteres | `"hola"` |
| `lista` | secuencia ordenada | `1,2,3`, `"a","b"` |
| `diccionario` | pares clave/valor | `"ana",30.diccionario` |
| `booleano` | verdad o falsedad | `sí`, `no` |
| `funcion` | un sufijo o función | `definir.sufijo` |

### 6.1 Números exactos e inexactos

Rackituq hereda de Racket dos clases de número:

- **Exactos**: enteros sin límite de tamaño y racionales. `2.a-la:100` da el
  número entero completo, y `1.entre:3` da `1/3`, no `0.333…`.
- **Inexactos**: los de punto flotante de doble precisión (IEEE 754). Se
  escriben con punto decimal: `3.5`.

Reglas:

1. Una operación entre exactos da exacto: `7.entre:2` → `7/2`.
2. Si un operando es inexacto, el resultado es inexacto:
   `1.entre:3.mas:1.0` → `1.3333333333333333`.
3. `.decimal` pasa de exacto a inexacto: `1.entre:3.decimal` → `0.3333333333333333`.
4. `.redondea` redondea **al par más cercano** cuando la parte decimal es
   exactamente 0,5: `2.5.redondea` → `2`, `3.5.redondea` → `4`.
5. `igual` y `distinto` comparan **el valor** entre números, no la forma:
   `5.igual:5.0?` → `sí`.
6. Los decimales arrastran el error propio de IEEE 754:
   `0.1.mas:0.2` → `0.30000000000000004`.
7. Dividir entre cero es un error (§7), no infinito.

### 6.2 Tipos declarados

`definir.variable.tipo <nombre> <valor> <tipo>` declara el tipo de una
variable. A partir de ahí, actualizarla con un valor de otro tipo es un
error. Las variables sin declarar aceptan cualquier tipo.

`es:<tipo>` pregunta por el tipo: usa el declarado si lo hay, y si no, el del
valor.

## 7. Catálogo de errores

Todos los errores tienen la forma `Error: ` seguida de la causa, en minúscula
y en español. Se arman en [nucleo/errores.rkt](nucleo/errores.rkt), que es la
fuente de esta tabla.

| Mensaje | Cuándo |
|---|---|
| `Error: la variable X ya está definida` | `definir.variable` sobre un nombre que ya existe en ese ámbito |
| `Error: no conozco la variable X` | se actualiza una variable que no existe |
| `Error: no conozco la palabra X` | la raíz o un complemento no es un valor, ni una variable |
| `Error: no conozco el sufijo X` | el morfema no está en el diccionario ni es un sufijo del usuario |
| `Error: la palabra reservada "X" no puede ser el nombre de una variable` | §3.3 |
| `Error: la variable X es de tipo T, no acepta V` | choca con el tipo declarado |
| `Error: el valor V no es de tipo T` | `definir.variable.tipo` con un valor que no corresponde |
| `Error: el valor V no es un número` | `.numero` sobre un texto que no lo es |
| `Error: X no acepta N complemento(s); recibió …` | a un morfema le sobran o le faltan complementos |
| `Error: el sufijo X necesita N complemento(s); recibió M` | a un sufijo propio le faltan complementos |
| `Error: X no tiene sufijos que usen los argumentos …` | hay argumentos pero la palabra no tiene morfemas |
| `Error: el morfema X no pudo con ese valor (…)` | el morfema falló; entre paréntesis va el detalle |
| `Error: -gaangat dio demasiadas vueltas` | el bucle pasó el límite (§8) |
| `Error: mientras dio demasiadas vueltas; ¿el cuerpo guarda el nuevo valor en X?` | el bucle clásico no avanza |
| `Error: un diccionario necesita pares de clave y valor` | lista de largo impar en `.diccionario` |
| `Error: el diccionario no tiene "C"` | `valor-de:` con una clave que no está |
| `Error: no se pudo encontrar el módulo R` | `importar.modulo` con una ruta que no existe |
| `Error: X no es una función válida` | se llamó como función algo que no lo es |
| `Error: no conozco X` | un nombre desconocido dentro de una función escrita en Racket |
| `Error: <mensaje>` | lo levanta el propio programa con `falla:"<mensaje>"` |

Al correr un archivo, el error se acompaña de la línea:

```
Error: no conozco la palabra banana
   en la línea 7: banana.suma
```

`intenta:` atrapa cualquiera de estos errores.

## 8. Definido por la implementación

Lo que puede cambiar entre implementaciones sin dejar de ser conforme:

| Punto | En esta implementación |
|---|---|
| Vueltas máximas de `-gaangat` y `mientras` | 100 000 |
| Tamaño de la caché de análisis | 20 000 palabras y 20 000 oraciones |
| Profundidad de recursión | la que aguante la memoria; no hay optimización de llamada final |
| Precisión de los inexactos | IEEE 754 doble |
| Tamaño de los exactos | sin límite |
| Orden de las claves de un diccionario | alfabético por su forma escrita |
| Detalle entre paréntesis de `el morfema X no pudo…` | el mensaje de Racket |

## 9. Lo que la especificación todavía no cubre

Dicho con todas las letras, para que se sepa qué falta:

1. Las sub-palabras no pueden llevar espacios adentro.
2. Nada se modifica en su lugar: listas y diccionarios siempre se arman de nuevo.
3. No se pueden definir tipos propios.
4. Los morfemas no declaran qué tipo reciben ni cuál devuelven, así que un
   error de tipo aparece recién al correr.
5. Conviven dos estilos (el clásico `x.sum.ar 2 3` y el aglutinante) y la
   regla que los distingue en el REPL tiene bordes raros.

El estado completo, con ejemplos, está en [ESTADO.md](ESTADO.md).
