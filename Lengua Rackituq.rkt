#lang racket

;; Punto de entrada de Rackituq. El lenguaje vive en nucleo/.
;;
;;   racket "Lengua Rackituq.rkt"                  -> la demo
;;   racket "Lengua Rackituq.rkt" ejemplos/hola.rkq -> corre un programa
;;
(require "nucleo/ejecutor.rkt" "nucleo/palabra.rkt" "nucleo/repl.rkt")

(define (demo)
  ;; Hola mundo: la raíz es el texto y `.mostrar` es el morfema que lo saca por pantalla
  (hablar "\"Hola Mundo\".mostrar")

  ;; Estilo clásico: comando + argumentos
  (ejecutar-comando "definir.variable" "lista1" '(10 20 30 40 50))
  (displayln (format "Sublista de lista1 (1-3): ~a"
                     (ejecutar-comando "lista1.sub.lista" 1 3)))

  ;; Estilo aglutinante: todo el programa es una palabra
  (hablar "lista1.solo:mayor:15.cada:entre:10.en:decenas")
  (hablar "decenas.suma.muestra")
  (hablar "decenas.cuenta.mayor:3-guni \"hay mas de tres\".muestra sino \"hay pocas\".muestra")

  ;; Sufijos propios, con complementos ($1) y con recursión ($0)
  (ejecutar-comando "definir.sufijo" "aumentar-en" "mas:$1")
  (hablar "decenas.cada:aumentar-en:100.muestra")
  (ejecutar-comando "definir.sufijo" "fact" "$0.menor:2-guni 1 sino $0.por:($0.menos:1.fact)")
  (hablar "5.fact.muestra")

  ;; Sub-palabras entre paréntesis
  (hablar "decenas.suma.entre:(decenas.cuenta).decimal.muestra")

  ;; Ver una palabra por dentro, morfema por morfema
  (explicar "1,2,3,4,5,6.solo:par.cada:por:10.suma"))

;; Con un argumento corre ese programa; sin argumentos, la demo
(let ([argumentos (current-command-line-arguments)])
  (if (zero? (vector-length argumentos))
      (demo)
      (void (correr-archivo (vector-ref argumentos 0)))))

;; Para el REPL interactivo: descomentar
;; (repl)
