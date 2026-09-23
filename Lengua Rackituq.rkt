#lang racket

;; Punto de entrada de Rackituq. El lenguaje vive en nucleo/.
(require "nucleo/ejecutor.rkt" "nucleo/palabra.rkt" "nucleo/repl.rkt")

;; Ejemplo de uso: descomentar para probar el REPL
;; (repl)

;; Hola mundo: la raíz es el texto y `.mostrar` es el morfema que lo saca por pantalla
(void (hablar "\"Hola Mundo\".mostrar"))

;; Estilo clásico: comando + argumentos
(void (ejecutar-comando "definir.variable" "lista1" '(10 20 30 40 50)))
(displayln (format "Sublista de lista1 (1-3): ~a"
                  (ejecutar-comando "lista1.sub.lista" 1 3)))

;; Estilo aglutinante: todo el programa es una palabra
(void (hablar "lista1.solo:mayor:15.cada:entre:10.en:decenas"))
(void (hablar "decenas.suma.muestra"))
(void (hablar "decenas.cuenta.mayor:3-guni \"hay mas de tres\".muestra"))

;; Sufijos nuevos, definidos en Rackituq mismo
(void (ejecutar-comando "definir.sufijo" "cuadrado" "a-la:2"))
(void (hablar "decenas.cada:cuadrado.suma.muestra"))

;; Sufijos con complementos propios: los huecos son $1, $2
(void (ejecutar-comando "definir.sufijo" "aumentar-en" "mas:$1"))
(void (hablar "decenas.cada:aumentar-en:100.muestra"))

;; Texto y condicional con sus dos ramas
(void (hablar "\"a\",\"b\",\"c\".cada:mayusculas.une:\"-\".muestra"))
(void (hablar "decenas.cuenta.mayor:10-guni \"muchas\".muestra sino \"pocas\".muestra"))

;; Ver una palabra por dentro, morfema por morfema
(explicar "1,2,3,4,5,6.solo:par.cada:por:10.suma")
