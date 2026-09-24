#lang racket

(require "errores.rkt" "estado.rkt" "vocabulario.rkt" "modulos.rkt" "ejecutor.rkt" "palabra.rkt")
(provide (all-defined-out))

;; ----- REPL (Read-Eval-Print Loop) -----

;; Argumento de un comando especial: "5" -> 5, "\"hola\"" -> "hola", "1,2" -> (1 2).
;; Un nombre suelto queda como texto, porque suele ser el nombre de una variable
(define (leer-argumento token)
  (cond
    [(string->number token) => values]
    [(texto-literal? token) (substring token 1 (sub1 (string-length token)))]
    [(lista-literal? token) (resolver token)]
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
      ;; `correr <archivo>` ejecuta un programa guardado
      [(and (string=? (first tokens) "correr") (= (length tokens) 2))
       (correr-archivo (leer-argumento (second tokens)))]
      ;; El cuerpo de un sufijo es todo el resto de la línea, con sus espacios
      [(and (string=? (first tokens) "definir.sufijo") (>= (length tokens) 3))
       (ejecutar-comando "definir.sufijo" (second tokens) (string-join (drop tokens 2) " "))]
      [(comando-especial? (first tokens))
       (let ([args (map leer-argumento (rest tokens))])
         (if (empty? args)
             (ejecutar-comando (first tokens) #f)
             (apply ejecutar-comando (first tokens) args)))]
      [else (hablar entrada)])))

;; ----- PROGRAMAS EN ARCHIVO -----

;; Correr un archivo .rkq: una línea por instrucción. Las líneas vacías y las
;; que empiezan con ;; son comentarios
(define (correr-archivo ruta)
  (for ([linea (file->lines ruta)]
        [numero (in-naturals 1)])
    (let ([limpia (string-trim linea)])
      (unless (or (string=? limpia "") (string-prefix? limpia ";;"))
        (with-handlers ([exn:fail?
                         (lambda (e)
                           (error-en-linea (exn-message e) numero limpia))])
          (ejecutar-linea limpia)))))
  (format "Programa ~a terminado" ruta))

;; Un módulo en formato Rackituq se corre línea por línea
(instalar-ejecutor-de-lineas! ejecutar-linea)

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
            (displayln (texto-rackituq resultado)))))
      (repl))))
