# Rackituq

Un lenguaje de programación **aglutinante** hecho en Racket.

El nombre junta *Racket* con *-tuq*, por el kalaallisut (groenlandés), uno de
los idiomas más aglutinantes del mundo. En kalaallisut una sola palabra larga
puede decir lo que en español es una oración entera, porque se le van pegando
sufijos a una raíz y cada uno cambia el significado de todo lo anterior.
Rackituq hace lo mismo con los programas: **un programa puede ser una sola
palabra**.

```
"Hola Mundo".mostrar                         → Hola Mundo
1,2,3,4,5,6.solo:par.cada:por:10.suma        → 120
edad.mayor:17-guni "adulto".muestra          → adulto (si edad > 17)
```

## Cómo correrlo

```
racket "Lengua Rackituq.rkt"                    # la demo
racket "Lengua Rackituq.rkt" ejemplos/hola.rkq  # un programa guardado
raco test pruebas.rkt                           # las pruebas
```

Para el REPL, descomenta `(repl)` en `Lengua Rackituq.rkt`. Se sale con `salir`.
Dentro del REPL, `correr ejemplos/hola.rkq` ejecuta un programa.

## Programas en archivo

Un `.rkq` es una línea por instrucción; las líneas vacías y las que empiezan
con `;;` son comentarios. Hay ejemplos en [ejemplos/](ejemplos/).

## Anatomía de una palabra

```
  raíz   .  morfema  .  morfema:complemento  ...  [modo]
  lista1 .  solo     :  mayor:15  .  cada:entre:10  .  suma  ?
```

- **Raíz**: un valor (`5`, `3.5`, `1,2,3`, `"a","b"`, `"hola"`, `sí`, `no`) o una
  variable (`lista1`).
- **Morfemas**: se aplican de izquierda a derecha, cada uno sobre el resultado
  del anterior, como un pipe de Unix. El punto siempre separa morfemas.
- **Complementos**: van pegados con `:` (`mas:3`, `sublista:1:3`). Un complemento
  puede ser otra palabra entre paréntesis: `suma.entre:(notas.cuenta)`.
- **Modo**: va al final de la palabra y dice qué hacer con ella.

| Modo | Significado | Ejemplo |
|---|---|---|
| *(ninguno)* | afirmación: devuelve el valor | `5.mas:3` → 8 |
| `?` | pregunta: responde sí/no | `7.impar?` → sí |
| `-guni` | condicional (kalaallisut *-guni*, "si…") | `x.mayor:0-guni "positivo".muestra sino "negativo".muestra` |
| `-gaangat` | habitual (kalaallisut *-gaangat*, "cada vez que…") | `i.menor:5-gaangat i.mas:1.en:i` |

La palabra `sino` parte el condicional en sus dos ramas:

```
edad.mayor:17-guni "adulto".muestra sino "menor".muestra
```

### Cadenas como operación

El complemento de `cada:`, `solo:` y `junta:` puede ser una cadena entre
paréntesis. Adentro, `esto` es el valor que llega y `otro` el que lo acompaña:

```
1,2,3.cada:(mas:1.por:2)                        → (4 6 8)
1,2,3,4,5,6.solo:(mayor:2.y:(esto.menor:6))     → (3 4 5)
1,2,3.junta:(mas:otro)                          → 6
```

### Ver una palabra por dentro

`explicar` muestra qué hace cada morfema con el valor:

```
Racketiitut> explicar 1,2,3,4,5,6.solo:par.cada:por:10.suma
   raíz 1,2,3,4,5,6  →  (1 2 3 4 5 6)
   solo:par  →  (2 4 6)
   cada:por:10  →  (20 40 60)
   suma  →  120
```

### Argumentos después de la palabra

Si la raíz no tiene valor, la entrada sale de los argumentos que van después
de la palabra. `x.sum.ar 2 3` es lo mismo que `2.sum.ar:3`. Si la raíz sí es
una variable, ella es la entrada y los argumentos pasan a ser complementos:
`lista1.sub.lista 1 3`.

### Nombres con punto

Los nombres clásicos como `sum.ar` o `sub.lista` tienen un punto adentro. El
segmentador parte todo por los puntos y después une las piezas que juntas
forman un morfema conocido, prefiriendo siempre **la coincidencia exacta más
larga**: `sub` + `lista` se lee como `sub.lista`. Cada nombre clásico tiene
también un alias sin punto (`sumar`, `sublista`), que es el que conviene usar
dentro de complementos: `cada:sumar:1`.

## Morfemas

| Grupo | Morfemas (nombre clásico / alias) |
|---|---|
| Aritmética | `sum.ar`/`sumar`/`mas`, `rest.ar`/`restar`/`menos`, `mult.iplicar`/`multiplicar`/`por`, `div.idir`/`dividir`/`entre`, `pot.enciar`/`potenciar`/`a-la`, `mod.ul`/`modulo`/`mod`, `dobla`, `neg`, `promedio`, `decimal`, `redondea` |
| Matemática | `raiz`, `sin.us`/`seno`, `cos.inus`/`coseno`, `tan.gente`/`tangente`, `log.aritmo`/`logaritmo`, `exp.onencial`/`exponencial`, `abs.oluto`/`absoluto`/`abs`, `rand.aleatorio`/`aleatorio`, `min.imo`/`minimo`, `max.imo`/`maximo` |
| Listas | `lista`, `sub.lista`/`sublista`/`desde`, `ind.ice`/`indice`, `prim.ero`/`primero`, `ult.imo`/`ultimo`, `suma`, `producto`, `invierte`, `ordena`, `con` |
| Texto | `texto`, `mayusculas`, `minusculas`, `recorta`, `parte:" "`, `une:"-"`, `reemplaza:viejo:nuevo` |
| Texto y listas | `conc.atenar`/`concatenar`/`pega`, `long.itud`/`longitud`/`cuenta`, `contiene` |
| Orden superior | `map`/`cada`, `filter`/`filtra`/`solo`, `reduce`/`junta` — su complemento es otra operación, y se pueden anidar: `cada:cada:por:2` |
| Predicados | `par`, `impar`, `positivo`, `negativo`, `cero`, `vacia`, `mayor`, `menor`, `igual`, `distinto` |
| Condiciones | `y`, `o`, `no`/`niega` — el complemento suele ser una sub-palabra: `edad.mayor:17.y:(edad.menor:65)` |
| Tipos y variables | `es:numero` (usa el tipo declarado si lo hay), `en:nombre`/`guarda:nombre` (guarda el valor y lo deja seguir), `global:nombre` |
| Otros | `muestra`/`mostrar`, `lazy`/`diferir`, `force`/`forzar`, `lambda.simple`, `lambda.multi`, `lambda.aplicar`/`aplicar`, `mem.cache`, `mem.limpiar` |

## Sufijos propios

Una cadena de morfemas se puede guardar como un sufijo nuevo:

```
definir.sufijo cuadrado a-la:2
1,2,3.cada:cuadrado          → (1 4 9)
```

El sufijo puede tener sus propios complementos. Se escriben `$1`, `$2`:

```
definir.sufijo aumentar-en mas:$1
5.aumentar-en:3              → 8
1,2,3.cada:aumentar-en:10    → (11 12 13)
```

El cuerpo es una **cadena** cuando arranca con un morfema (`mas:$1`), y una
**oración completa** cuando arranca con cualquier otra cosa: una raíz, una
variable o `$0`, que es el valor que recibe el sufijo. Una oración puede
llevar modos y **llamarse a sí misma**, así que la recursión se escribe sin
salir de Rackituq:

```
definir.sufijo fact $0.menor:2-guni 1 sino $0.por:($0.menos:1.fact)
5.fact                       → 120
1,2,3,4,5.cada:fact          → (1 2 6 24 120)

definir.sufijo cuenta-atras $0.cero-guni "despegue".muestra sino $0.muestra.menos:1.cuenta-atras
3.cuenta-atras               → 3, 2, 1, despegue
```

Las funciones definidas con `definir.funcion` y `definir.funcion.recursiva`
también se pegan como sufijos: `5.fact.mas:1`.

### Variables locales

Cada llamada a un sufijo abre su propio ámbito: lo que guarde con `en:` es
local a esa llamada y no pisa lo de las otras. Por eso esta recursión, que
guarda **antes** de llamarse a sí misma, da bien:

```
definir.sufijo fact $0.menor:2-guni 1 sino $0.en:n ($0.menos:1.fact).por:n
5.fact                       → 120
```

Un nombre se busca de adentro hacia afuera, así que desde un sufijo se leen
las variables de arriba. Para **escribir** una de afuera está `global:`:

```
definir.variable total 0
definir.sufijo acumular $0.mas:total.global:total
5.acumular                   → 5
7.acumular                   → 12
```

## Comandos especiales

Estos no son palabras sino comandos con argumentos separados por espacios:

| Comando | Ejemplo |
|---|---|
| `definir.variable` | `definir.variable nombre "Ana"` |
| `definir.variable.tipo` | `definir.variable.tipo edad 16 numero` |
| `definir.sufijo` | `definir.sufijo triple por:3` |
| `definir.funcion`, `definir.funcion.recursiva` | desde Racket, con el cuerpo como s-expresión |
| `actualizar.variable` | `actualizar.variable edad 17` (respeta el tipo declarado) |
| `si` | `si edad 17 > x.sum.ar 1` |
| `mientras` | `mientras i 5 < x.sum.ar.en:i 1` (el cuerpo guarda el nuevo valor con `.en:`) |
| `explicar` | `explicar 5.mas:3.por:2` |
| `mostrar.salida` | `mostrar.salida "Hola Mundo"` o `mostrar.salida "Hola ~a" nombre` |
| `importar.modulo`, `exportar.modulo` | guardan y cargan variables en un archivo |
| `mem.limpiar` | vacía la caché de `mem.cache` |

## Estado del lenguaje

[ESTADO.md](ESTADO.md) resume qué puede y qué no puede Rackituq hoy.

## Estructura

```
Lengua Rackituq.rkt     punto de entrada: la demo, o corre un .rkq
pruebas.rkt             pruebas (raco test pruebas.rkt)
ESTADO.md               qué puede y qué no puede el lenguaje hoy
ejemplos/               programas .rkq
nucleo/
  vocabulario.rkt       el diccionario de morfemas: aquí se agregan morfemas nuevos
  palabra.rkt           el segmentador: parte palabras y oraciones y las evalúa
  ejecutor.rkt          comandos especiales y definición de funciones/sufijos
  variables.rkt         variables y tipos
  modulos.rkt           importar/exportar
  condiciones.rkt       comparaciones de si/mientras
  io.rkt                entrada y salida
  estado.rkt            las tablas globales
  repl.rkt              el REPL, explicar y correr archivos
```

### Agregar un morfema

Una línea en `nucleo/vocabulario.rkt`:

```racket
(definir-morfema '("triplica" "triple") 'valor (lambda (v) (* v 3)))
```

`'valor` recibe los complementos ya resueltos; `'crudo` los recibe como
texto, para morfemas cuyo complemento es un nombre (como `en:` o `cada:`).
