#lang racket

(provide (all-defined-out))

;; ----- ENTRADA/SALIDA -----

;; Función para leer entrada del usuario
(define (leer-input mensaje)
  (display mensaje)
  (flush-output)
  (read))

;; Función para mostrar salida formateada
(define (mostrar-salida formato . args)
  (apply printf (cons formato args))
  (newline))
