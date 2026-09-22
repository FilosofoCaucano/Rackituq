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
racket "Lengua Rackituq.rkt"     # la demo
raco test pruebas.rkt            # las pruebas
```

Para el REPL, descomenta `(repl)` en `Lengua Rackituq.rkt`. Se sale con `salir`.

## Anatomía de una palabra

```
  raíz   .  morfema  .  morfema:complemento  ...  [modo]
  lista1 .  solo     :  mayor:15  .  cada:entre:10  .  suma  ?
```

- **Raíz**: un valor (`5`, `3.5`, `1,2,3`, `"hola"`) o una variable (`lista1`).
- **Morfemas**: se aplican de izquierda a derecha, cada uno sobre el resultado
  del anterior, como un pipe de Unix. El punto siempre separa morfemas.
- **Complementos**: van pegados con `:` (`mas:3`, `sublista:1:3`).
- **Modo**: va al final de la palabra y dice qué hacer con ella.

| Modo | Significado | Ejemplo |
|---|---|---|
| *(ninguno)* | afirmación: devuelve el valor | `5.mas:3` → 8 |
| `?` | pregunta: responde sí/no | `7.impar?` → sí |
| `-guni` | condicional (kalaallisut *-guni*, "si…") | `x.mayor:0-guni "positivo".muestra` |
| `-gaangat` | habitual (kalaallisut *-gaangat*, "cada vez que…") | `i.menor:5-gaangat i.mas:1.en:i` |

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
| Aritmética | `sum.ar`/`sumar`/`mas`, `rest.ar`/`restar`/`menos`, `mult.iplicar`/`multiplicar`/`por`, `div.idir`/`dividir`/`entre`, `pot.enciar`/`potenciar`/`a-la`, `mod.ul`/`modulo`/`mod`, `dobla`, `neg` |
| Matemática | `raiz`, `sin.us`/`seno`, `cos.inus`/`coseno`, `tan.gente`/`tangente`, `log.aritmo`/`logaritmo`, `exp.onencial`/`exponencial`, `abs.oluto`/`absoluto`/`abs`, `rand.aleatorio`/`aleatorio`, `min.imo`/`minimo`, `max.imo`/`maximo` |
| Listas | `lista`, `sub.lista`/`sublista`/`desde`, `conc.atenar`/`concatenar`, `ind.ice`/`indice`, `long.itud`/`longitud`/`cuenta`, `prim.ero`/`primero`, `ult.imo`/`ultimo`, `suma`, `producto`, `invierte`, `ordena`, `con` |
| Orden superior | `map`/`cada`, `filter`/`filtra`/`solo`, `reduce`/`junta` — su complemento es otra operación, y se pueden anidar: `cada:cada:por:2` |
| Predicados | `par`, `impar`, `positivo`, `negativo`, `cero`, `vacia`, `mayor`, `menor`, `igual`, `distinto` |
| Tipos y variables | `es:numero` (usa el tipo declarado si lo hay), `en:nombre`/`guarda:nombre` (guarda el valor y lo deja seguir) |
| Otros | `muestra`/`mostrar`, `lazy`/`diferir`, `force`/`forzar`, `lambda.simple`, `lambda.multi`, `lambda.aplicar`/`aplicar`, `mem.cache`, `mem.limpiar` |

## Sufijos propios

Una cadena de morfemas se puede guardar como un sufijo nuevo:

```
definir.sufijo cuadrado a-la:2
1,2,3.cada:cuadrado          → (1 4 9)
```

Las funciones definidas con `definir.funcion` y `definir.funcion.recursiva`
también se pegan como sufijos: `5.fact.mas:1`.

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
| `mientras` | `mientras i 5 < x.sum.ar 1` (el resultado se guarda en `i`) |
| `mostrar.salida` | `mostrar.salida "Hola Mundo"` o `mostrar.salida "Hola ~a" nombre` |
| `importar.modulo`, `exportar.modulo` | guardan y cargan variables en un archivo |
| `mem.limpiar` | vacía la caché de `mem.cache` |

## Estructura

```
Lengua Rackituq.rkt     punto de entrada y demo
pruebas.rkt             pruebas (raco test pruebas.rkt)
nucleo/
  vocabulario.rkt       el diccionario de morfemas: aquí se agregan morfemas nuevos
  palabra.rkt           el segmentador: parte palabras y oraciones y las evalúa
  ejecutor.rkt          comandos especiales y definición de funciones/sufijos
  variables.rkt         variables y tipos
  modulos.rkt           importar/exportar
  condiciones.rkt       comparaciones de si/mientras
  io.rkt                entrada y salida
  estado.rkt            las tablas globales
  repl.rkt              el REPL
```

### Agregar un morfema

Una línea en `nucleo/vocabulario.rkt`:

```racket
(definir-morfema '("triplica" "triple") 'valor (lambda (v) (* v 3)))
```

`'valor` recibe los complementos ya resueltos; `'crudo` los recibe como
texto, para morfemas cuyo complemento es un nombre (como `en:` o `cada:`).
