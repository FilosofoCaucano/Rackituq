#lang racket

(require "estado.rkt" "ejecutor.rkt" "palabra.rkt")
(provide (all-defined-out))

;; ----- REPL (Read-Eval-Print Loop) -----

;; Argumento de un comando especial: "5" -> 5, "\"hola mundo\"" -> "hola mundo"
(define (leer-argumento token)
  (cond
    [(string->number token) => values]
    [(regexp-match? #px"^\".*\"$" token) (substring token 1 (sub1 (string-length token)))]
    [else token]))

(define comandos-especiales
  '("actualizar.variable" "si" "mientras" "importar.modulo" "exportar.modulo"
    "leer.input" "mostrar.salida" "mem.limpiar"))

;; Los comandos especiales y las funciones van al ejecutor; todo lo demás
;; es una oración aglutinante (`x.sum.ar 2 3`, `5.mas:3.muestra`)
(define (comando-especial? comando)
  (or (string-prefix? comando "definir.")
      (member comando comandos-especiales)
      (hash-has-key? funciones comando)))

;; Ejecutar una línea del REPL y devolver su resultado
(define (ejecutar-linea entrada)
  (let ([tokens (tokenizar entrada)])
    (cond
      [(empty? tokens) (void)]
      ;; `explicar <línea>` muestra la palabra paso a paso
      [(string=? (first tokens) "explicar")
       (explicar (string-join (rest tokens) " "))]
      [(comando-especial? (first tokens))
       (let ([args (map leer-argumento (rest tokens))])
         (if (empty? args)
             (ejecutar-comando (first tokens) #f)
             (apply ejecutar-comando (first tokens) args)))]
      [else (hablar entrada)])))

;; Función REPL básico para pruebas
(define (repl)
  (display "Racketiitut> ")
  (flush-output)
  (let ([entrada (read-line)])
    (unless (or (eof-object? entrada) (equal? entrada "salir"))
      ;; Un error no debe cerrar el REPL
      (with-handlers ([exn:fail? (lambda (e) (displayln (exn-message e)))])
        (let* ([antes (file-position (current-output-port))]
               [resultado (ejecutar-linea entrada)]
               ;; Si la línea ya imprimió algo (`.muestra`), no se repite el resultado
               [imprimio? (> (file-position (current-output-port)) antes)])
          (unless (or (void? resultado) imprimio?)
            (displayln resultado))))
      (repl))))
