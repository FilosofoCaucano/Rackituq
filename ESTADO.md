# Rackituq hoy: qué puede y qué no puede

Estado al 23 de septiembre de 2026. Todo lo que dice este documento está
probado corriendo el código, no leyéndolo. Las pruebas (`raco test pruebas.rkt`)
son 45 y pasan.

La definición formal del lenguaje (gramática en EBNF, palabras reservadas,
aritmética y catálogo de errores) está en [ESPECIFICACION.md](ESPECIFICACION.md);
este documento es el resumen práctico.

Rackituq es un lenguaje aglutinante: un programa puede ser **una sola palabra**,
armada pegándole sufijos a una raíz, como en kalaallisut (groenlandés).

---

## Lo que sí puede

### Encadenar morfemas
El corazón del lenguaje. Cada morfema transforma lo que venía antes.

```
1,2,3,4,5,6.solo:par.cada:por:10.suma       → 120
"hola mundo".parte.cada:mayusculas.une:"-"  → "HOLA-MUNDO"
```

Hay 81 morfemas (124 nombres contando los alias): aritmética, matemática,
listas, texto, diccionarios, predicados, orden superior, entrada, salida y
tipos. Cada uno tiene su nombre clásico con punto
(`sum.ar`) y alias sin punto (`sumar`, `mas`), que son el mismo morfema.

### Valores
Números enteros, decimales y fracciones exactas (`39/5`, y `.decimal` lo
vuelve `7.8`), textos, listas de números, de textos o mezcladas, y `sí`/`no`,
que ahora también se pueden escribir, no solo salir de un predicado.

### Variables y tipos
```
definir.variable notas 7,8,10
definir.variable.tipo edad 16 numero
5.en:total                                   (también guarda desde una palabra)
```
Una variable con tipo declarado rechaza valores de otro tipo al actualizarla.
Los nombres aceptan acentos y eñes: `año.mas:1` funciona.

### Decidir y repetir
```
edad.mayor:17-guni "adulto".muestra sino "menor".muestra
i.menor:5-gaangat i.mas:1.en:i
7.impar?                                     → sí
```
`-guni` es el condicional y `-gaangat` el habitual, los dos tomados del
kalaallisut. `?` es el modo pregunta.

Las condiciones se combinan con `y`, `o` y `no`:

```
edad.mayor:17.y:(edad.menor:65)?             → sí
edad.mayor:99.no?                            → sí
```

### Sub-palabras entre paréntesis
```
5.por:(4.menos:1)                            → 15
notas.suma.entre:(notas.cuenta)              → el promedio
10.menos:(2.por:(1.mas:2))                   → 4   (se pueden anidar)
```

### Inventar sufijos propios, incluso recursivos
```
definir.sufijo aumentar-en mas:$1
1,2,3.cada:aumentar-en:10                    → (11 12 13)

definir.sufijo fact $0.menor:2-guni 1 sino $0.por:($0.menos:1.fact)
5.fact                                       → 120
```
`$1`, `$2` son los complementos del sufijo; `$0` es el valor que recibe, y
usarlo convierte el cuerpo en una oración completa, que puede llamarse a sí
misma. Con esto la recursión se escribe **sin salir de Rackituq**.

### Variables locales
Cada llamada a un sufijo abre su propio ámbito, así que lo que guarda con
`en:` no pisa lo de las otras llamadas. Esta recursión guarda **antes** de
llamarse a sí misma y da bien:

```
definir.sufijo fact $0.menor:2-guni 1 sino $0.en:n ($0.menos:1.fact).por:n
5.fact                                       → 120
```
Para escribir una variable de afuera desde adentro está `global:`.

### Cadenas como operación
El complemento de `cada:`, `solo:` y `junta:` puede ser una cadena entre
paréntesis; adentro, `esto` es el valor que llega y `otro` el que lo acompaña:

```
1,2,3.cada:(mas:1.por:2)                     → (4 6 8)
1,2,3,4,5,6.solo:(mayor:2.y:(esto.menor:6))  → (3 4 5)
```

### Texto por posición
```
"hola".letra:0                               → "h"
"hola mundo".trozo:0:4                       → "hola"
"hola".invierte                              → "aloh"
"hola".parte:""                              → ("h" "o" "l" "a")
```
`cuenta`, `primero`, `ultimo`, `indice`, `invierte`, `concatenar` y `contiene`
sirven igual para textos y para listas.

### Atajar errores
```
5.intenta:(mas:1)                            → 6
"hola".intenta:(mas:1)                       → no
"hola".intenta:(mas:1):(concatenar:" (falló)")  → "hola (falló)"
0.falla:"división entre cero"                → corta con ese error
```

### Diccionarios
```
"ana",30,"luis",25.diccionario.en:edades
edades.valor-de:"ana"                        → 30
edades.pon:"eva":41.claves                   → ("ana" "eva" "luis")
edades.muestra                               → {ana: 30, luis: 25}
```
Agregar o quitar arma un diccionario nuevo. `cuenta`, `contiene` y `vacia`
también sirven con diccionarios, y `es:diccionario?` los reconoce.

### Pedir datos por teclado
```
"¿Cómo te llamás? ".lee.en:nombre
"¿Cuántos años tenés? ".lee.numero.en:edad
```
La raíz es la pregunta que aparece en pantalla y `lee` devuelve lo tecleado;
`numero` lo convierte en número.

### Bibliotecas propias
Los sufijos se guardan con su cuerpo, así que `exportar.modulo todo mi.rkq`
escribe una biblioteca **que es un programa Rackituq normal**, legible y
editable, y `importar.modulo` la vuelve a cargar (dos veces seguidas tampoco
choca).

### Programas guardados
Un archivo `.rkq` es una línea por instrucción, con comentarios `;;`.

```
racket "Lengua Rackituq.rkt" ejemplos/factorial.rkq
```
Y dentro del REPL: `correr ejemplos/hola.rkq`.

### Ver el lenguaje por dentro
```
Racketiitut> explicar 1,2,3.cada:por:10.suma
   raíz 1,2,3  →  (1 2 3)
   cada:por:10  →  (10 20 30)
   suma  →  60
```
En una oración con `-guni`, `explicar` también dice qué rama tomó.

### El estilo clásico sigue vivo
`ejecutar-comando "x.sum.ar" 2 3`, `si`, `mientras`, `definir.funcion`,
`importar.modulo` / `exportar.modulo` (para variables), `mem.cache`,
`leer.input` y las lambdas de Racket.

### Palabras reservadas
`sí`, `no`, `sino`, `esto`, `otro` y `$0`, `$1`… no pueden nombrar variables:
intentarlo avisa en vez de dejar una variable que nunca se va a poder leer.

### Errores en español
Todos tienen la misma forma, `Error: ` y la causa en minúscula, y están
catalogados en [ESPECIFICACION.md](ESPECIFICACION.md):
`no conozco la palabra banana`, `el sufijo aumentar-en necesita 1 complemento(s)`,
`el morfema entre no pudo con ese valor (/: division by zero)`. Un bucle que no
avanza se corta solo y explica por qué, en vez de colgarse.

---

## Lo que todavía no puede

### 1. Las sub-palabras no aceptan espacios
`5.por:(2 .mas:1)` falla, porque la oración se parte por espacios antes de
mirar los paréntesis.

### 2. Algunas cosas todavía se escriben en Racket
- `definir.funcion.recursiva` pide el cuerpo como expresión de Racket (aunque
  ya no hace falta: la recursión se escribe con `definir.sufijo` y `$0`).
- `lambda.simple`, `lambda.multi` y `mem.cache` necesitan procedimientos de
  Racket, así que desde el REPL son casi inusables.
- Los módulos guardan variables y sufijos, pero no las funciones hechas en
  Racket, que no tienen forma de texto.

### 3. Nada se modifica en su lugar
No hay forma de cambiar el elemento 2 de una lista: siempre se arma una nueva.
Con los diccionarios pasa lo mismo, aunque ahí casi no molesta.

### 4. No se pueden definir tipos propios
Hay números, textos, listas, diccionarios y sí/no, pero no se puede inventar
un tipo nuevo con sus propios morfemas.

### 5. Los tipos son mínimos
Seis tipos (`numero`, `texto`, `lista`, `diccionario`, `booleano`, `funcion`),
y solo se revisan en variables declaradas con `definir.variable.tipo`. Los
morfemas y los sufijos no declaran qué reciben ni qué devuelven: un error de
tipo aparece recién al correr.

### 6. Rendimiento de la recursión
`fib 22` tarda unos 0,4 segundos. Viene bajando (33 s → 0,8 s → 0,4 s), pero
sigue siendo un lenguaje para aprender y para programas chicos, no para
cálculo pesado. Cada llamada abre un ámbito y arma su oración, y no hay
optimización de llamada final, así que una recursión muy profunda puede
agotar la memoria.

### 7. Dos estilos conviviendo
El estilo clásico (`x.sum.ar 2 3`) y el aglutinante usan el mismo motor, pero
la regla que los distingue en el REPL tiene bordes raros: si existe una
variable llamada `x`, `x.sum.ar 2 3` usa su valor en vez de tomar el 2 como
entrada.

---

## Cómo está hecho

```
Lengua Rackituq.rkt     punto de entrada: demo o corre un .rkq
pruebas.rkt             45 pruebas (incluidas las de conformidad)
ejemplos/               programas .rkq
nucleo/
  vocabulario.rkt       el diccionario de morfemas (aquí se agregan nuevos)
  palabra.rkt           el segmentador y el evaluador de oraciones
  ejecutor.rkt          comandos especiales, funciones y sufijos
  variables.rkt         variables y tipos
  modulos.rkt           importar / exportar
  condiciones.rkt       comparaciones de si / mientras
  io.rkt                entrada y salida
  estado.rkt            las tablas globales
  repl.rkt              REPL, explicar y correr archivos
  errores.rkt           el catálogo de errores
```

La idea central: el punto **siempre** separa morfemas, y cada pieza se busca
en un diccionario (una tabla hash), prefiriendo la coincidencia exacta más
larga. Por eso `sub` + `lista` se lee como `sub.lista`, y agregar un morfema
nuevo es agregar una línea, no una rama más en un `cond`.

---

## Lo que seguiría

En el orden en que más destraban el lenguaje:

1. **Sub-palabras con espacios**, hoy imposibles.
2. **Poder cambiar un elemento** de una lista o un diccionario en su lugar.
3. **Tipos en los morfemas**, para avisar antes de correr y no al fallar.
4. **Una sola forma de escribir**: hoy conviven el estilo clásico y el
   aglutinante, con una regla de desempate que tiene bordes raros.
5. **Más velocidad**: la recursión ya bajó a 0,4 s en `fib 22`, pero cada
   llamada todavía abre un ámbito y arma su oración.
