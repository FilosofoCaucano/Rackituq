# Rackituq hoy: qué puede y qué no puede

Estado al 23 de septiembre de 2026. Todo lo que dice este documento está
probado corriendo el código, no leyéndolo. Las pruebas (`raco test pruebas.rkt`)
son 34 y pasan.

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

Hay unos 70 morfemas: aritmética, matemática, listas, texto, predicados,
orden superior, tipos y salida. Cada uno tiene su nombre clásico con punto
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

### Errores en español
`No conozco la palabra banana`, `sub.lista no acepta 1 complemento(s)`,
`el sufijo aumentar-en necesita 1 complemento(s)`. Un bucle que no avanza se
corta solo y explica por qué, en vez de colgarse.

---

## Lo que todavía no puede

### 1. Las sub-palabras no aceptan espacios
`5.por:(2 .mas:1)` falla, porque la oración se parte por espacios antes de
mirar los paréntesis.

### 2. Varias cosas todavía se escriben en Racket, no en Rackituq
- `definir.funcion.recursiva` pide el cuerpo como expresión de Racket (aunque
  ya no hace falta: la recursión se escribe con `definir.sufijo` y `$0`).
- `lambda.simple`, `lambda.multi` y `mem.cache` necesitan procedimientos de
  Racket, así que desde el REPL son casi inusables.
- `exportar.modulo` guarda variables, pero no funciones ni sufijos.

### 3. Los textos no se indexan
`"hola".ind.ice:0` falla; `ind.ice` es solo para listas. Tampoco hay forma de
cambiar un elemento de una lista en su lugar.

### 4. No hay diccionarios ni estructuras propias
Solo números, textos, listas y sí/no. No se pueden definir tipos nuevos.

### 5. No hay manejo de errores dentro del lenguaje
Un error corta la oración. No existe algo como "intentá esto y si falla hacé
aquello".

### 6. La entrada de usuario es solo clásica
`leer.input` funciona como comando, pero no hay un morfema que lea del
teclado dentro de una palabra.

### 7. Los tipos son mínimos
Cinco tipos (`numero`, `texto`, `lista`, `booleano`, `funcion`), y solo se
revisan en variables declaradas con `definir.variable.tipo`. Los morfemas y
los sufijos no declaran qué reciben ni qué devuelven: un error de tipo
aparece recién al correr.

### 8. Rendimiento de la recursión
Cada llamada recursiva reemplaza `$0` por el valor y vuelve a analizar el
texto. Hoy `fib 22` tarda unos 0,8 segundos (antes de optimizar tardaba 33).
Sirve para aprender y para programas chicos, no para cálculo pesado. Tampoco
hay optimización de llamada final, así que una recursión muy profunda puede
agotar la memoria.

### 9. Dos estilos conviviendo
El estilo clásico (`x.sum.ar 2 3`) y el aglutinante usan el mismo motor, pero
la regla que los distingue en el REPL tiene bordes raros: si existe una
variable llamada `x`, `x.sum.ar 2 3` usa su valor en vez de tomar el 2 como
entrada.

---

## Cómo está hecho

```
Lengua Rackituq.rkt     punto de entrada: demo o corre un .rkq
pruebas.rkt             34 pruebas
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
```

La idea central: el punto **siempre** separa morfemas, y cada pieza se busca
en un diccionario (una tabla hash), prefiriendo la coincidencia exacta más
larga. Por eso `sub` + `lista` se lee como `sub.lista`, y agregar un morfema
nuevo es agregar una línea, no una rama más en un `cond`.

---

## Lo que seguiría

En el orden en que más destraban el lenguaje:

1. **Morfemas de texto por posición** (`letra:0`, `trozo:1:3`), que hoy no existen.
2. **Guardar sufijos y funciones** en los módulos, para poder armar una
   biblioteca escrita en Rackituq.
3. **Manejo de errores** dentro del lenguaje.
4. **Corto circuito en `y` / `o`**: hoy los dos lados se evalúan siempre.
5. **Acelerar la recursión**, guardando el análisis de cada palabra en vez de
   rehacerlo en cada llamada.
